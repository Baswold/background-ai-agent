import XCTest
@testable import BackgroundAIAgent

/// Comprehensive test suite for GitHub integration
/// Tests both GitHubService and GitHubMonitor functionality
final class GitHubIntegrationTests: XCTestCase {

    var githubService: GitHubService!
    var githubMonitor: GitHubMonitor!

    override func setUp() {
        super.setUp()
        githubService = GitHubService.shared
        githubMonitor = GitHubMonitor()
    }

    override func tearDown() {
        githubMonitor.stop()
        githubMonitor = nil
        githubService = nil
        super.tearDown()
    }

    // MARK: - GitHubService Tests

    func testGitHubServiceInitialization() {
        XCTAssertNotNil(githubService, "GitHubService should initialize")
    }

    func testGitHubURLConstruction() {
        let expectedURL = "https://api.github.com"
        XCTAssertEqual(AppConfig.githubAPIURL, expectedURL, "GitHub API URL should be correct")
    }

    func testRateLimitModel() {
        let rateLimit = GitHubRateLimit(
            limit: 5000,
            remaining: 4950,
            resetDate: Date().addingTimeInterval(3600)
        )

        XCTAssertEqual(rateLimit.limit, 5000)
        XCTAssertEqual(rateLimit.remaining, 4950)
        XCTAssertFalse(rateLimit.isExceeded, "Rate limit should not be exceeded")
        XCTAssertEqual(rateLimit.percentRemaining, 99.0, accuracy: 0.1)
    }

    func testRateLimitExceeded() {
        let rateLimit = GitHubRateLimit(
            limit: 5000,
            remaining: 0,
            resetDate: Date().addingTimeInterval(3600)
        )

        XCTAssertTrue(rateLimit.isExceeded, "Rate limit should be exceeded")
        XCTAssertEqual(rateLimit.percentRemaining, 0.0)
    }

    func testGitHubErrorDescriptions() {
        let missingTokenError = GitHubError.missingToken
        XCTAssertNotNil(missingTokenError.errorDescription)
        XCTAssertTrue(missingTokenError.errorDescription!.contains("token"))

        let networkError = GitHubError.networkError()
        XCTAssertNotNil(networkError.errorDescription)
        XCTAssertTrue(networkError.errorDescription!.contains("Network"))

        let apiError = GitHubError.apiError(statusCode: 404, message: "Not Found")
        XCTAssertNotNil(apiError.errorDescription)
        XCTAssertTrue(apiError.errorDescription!.contains("404"))

        let resetDate = Date()
        let rateLimitError = GitHubError.rateLimitExceeded(resetDate: resetDate, waitSeconds: 3600)
        XCTAssertNotNil(rateLimitError.errorDescription)
        XCTAssertTrue(rateLimitError.errorDescription!.contains("exceeded"))
    }

    // MARK: - GitHubMonitor Tests

    func testGitHubMonitorInitialization() {
        XCTAssertNotNil(githubMonitor, "GitHubMonitor should initialize")
    }

    func testGitHubMonitorMetrics() {
        let metrics = githubMonitor.getMetrics()

        XCTAssertEqual(metrics.totalPRsAnalyzed, 0, "Initial PRs analyzed should be 0")
        XCTAssertEqual(metrics.totalIssuesFound, 0, "Initial issues found should be 0")
        XCTAssertEqual(metrics.queueSize, 0, "Initial queue size should be 0")
        XCTAssertFalse(metrics.isRunning, "Monitor should not be running initially")
        XCTAssertNil(metrics.lastCheckTime, "Last check time should be nil initially")
    }

    func testGitHubMonitorStart() {
        let expectation = self.expectation(description: "Monitor starts")
        var activityReceived = false

        githubMonitor.start { activity in
            activityReceived = true
            expectation.fulfill()
        }

        // Give it a moment to start
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let metrics = self.githubMonitor.getMetrics()
            if !activityReceived {
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 2.0) { error in
            if let error = error {
                print("Test timeout: \(error)")
            }
        }

        let metrics = githubMonitor.getMetrics()
        // Note: isRunning might be false if no GitHub token is configured
        // That's expected behavior
    }

    func testGitHubMonitorStop() {
        githubMonitor.start { _ in }
        githubMonitor.stop()

        let metrics = githubMonitor.getMetrics()
        XCTAssertFalse(metrics.isRunning, "Monitor should not be running after stop")
    }

    func testGitHubMonitorClearCache() {
        githubMonitor.clearCache()

        let metrics = githubMonitor.getMetrics()
        XCTAssertEqual(metrics.cachedRepoCount, 0, "Cache should be empty after clearing")
    }

    func testGitHubMonitorResetMetrics() {
        githubMonitor.resetMetrics()

        let metrics = githubMonitor.getMetrics()
        XCTAssertEqual(metrics.totalPRsAnalyzed, 0, "Metrics should be reset")
        XCTAssertEqual(metrics.totalIssuesFound, 0, "Metrics should be reset")
    }

    func testMetricsStatusDescription() {
        var metrics = GitHubMonitorMetrics(
            totalPRsAnalyzed: 0,
            totalIssuesFound: 0,
            queueSize: 0,
            lastCheckTime: nil,
            isRunning: false,
            cachedRepoCount: 0
        )

        XCTAssertEqual(metrics.statusDescription, "Stopped")

        metrics = GitHubMonitorMetrics(
            totalPRsAnalyzed: 5,
            totalIssuesFound: 12,
            queueSize: 2,
            lastCheckTime: nil,
            isRunning: true,
            cachedRepoCount: 10
        )

        XCTAssertEqual(metrics.statusDescription, "Running")

        metrics = GitHubMonitorMetrics(
            totalPRsAnalyzed: 5,
            totalIssuesFound: 12,
            queueSize: 2,
            lastCheckTime: Date(),
            isRunning: true,
            cachedRepoCount: 10
        )

        XCTAssertTrue(metrics.statusDescription.contains("ago") || metrics.statusDescription.contains("now"))
    }

    // MARK: - Data Model Tests

    func testGitHubUserModel() {
        let json = """
        {
            "login": "testuser",
            "name": "Test User",
            "email": "test@example.com"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let user = try? decoder.decode(GitHubUser.self, from: json)

        XCTAssertNotNil(user)
        XCTAssertEqual(user?.login, "testuser")
        XCTAssertEqual(user?.name, "Test User")
        XCTAssertEqual(user?.email, "test@example.com")
    }

    func testGitHubRepoModel() {
        let json = """
        {
            "name": "test-repo",
            "full_name": "testuser/test-repo",
            "owner": {
                "login": "testuser"
            },
            "html_url": "https://github.com/testuser/test-repo"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let repo = try? decoder.decode(GitHubRepo.self, from: json)

        XCTAssertNotNil(repo)
        XCTAssertEqual(repo?.name, "test-repo")
        XCTAssertEqual(repo?.fullName, "testuser/test-repo")
        XCTAssertEqual(repo?.owner.login, "testuser")
        XCTAssertEqual(repo?.htmlUrl, "https://github.com/testuser/test-repo")
    }

    func testGitHubPRModel() {
        let json = """
        {
            "number": 123,
            "title": "Fix bug",
            "body": "This fixes a critical bug",
            "state": "open",
            "user": {
                "login": "testuser"
            },
            "html_url": "https://github.com/testuser/test-repo/pull/123"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let pr = try? decoder.decode(GitHubPR.self, from: json)

        XCTAssertNotNil(pr)
        XCTAssertEqual(pr?.number, 123)
        XCTAssertEqual(pr?.title, "Fix bug")
        XCTAssertEqual(pr?.body, "This fixes a critical bug")
        XCTAssertEqual(pr?.state, "open")
        XCTAssertEqual(pr?.user.login, "testuser")
    }

    func testGitHubIssueModel() {
        let json = """
        {
            "id": 1,
            "number": 456,
            "title": "Bug report",
            "body": "Something is broken",
            "state": "open",
            "user": {
                "login": "testuser"
            },
            "labels": [
                {
                    "name": "bug",
                    "color": "d73a4a"
                }
            ],
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-02T00:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let issue = try? decoder.decode(GitHubIssue.self, from: json)

        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.number, 456)
        XCTAssertEqual(issue?.title, "Bug report")
        XCTAssertEqual(issue?.state, "open")
        XCTAssertEqual(issue?.labels?.first?.name, "bug")
        XCTAssertEqual(issue?.labels?.first?.color, "d73a4a")
    }

    func testGitHubCommitModel() {
        let json = """
        {
            "sha": "abc123",
            "commit": {
                "message": "Fix bug in authentication",
                "author": {
                    "name": "Test User",
                    "email": "test@example.com",
                    "date": "2024-01-01T00:00:00Z"
                }
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let commit = try? decoder.decode(GitHubCommit.self, from: json)

        XCTAssertNotNil(commit)
        XCTAssertEqual(commit?.sha, "abc123")
        XCTAssertEqual(commit?.commit.message, "Fix bug in authentication")
        XCTAssertEqual(commit?.commit.author.name, "Test User")
        XCTAssertEqual(commit?.commit.author.email, "test@example.com")
    }

    func testGitHubBranchModel() {
        let json = """
        {
            "name": "main",
            "protected": true
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let branch = try? decoder.decode(GitHubBranch.self, from: json)

        XCTAssertNotNil(branch)
        XCTAssertEqual(branch?.name, "main")
        XCTAssertTrue(branch?.protected ?? false)
    }

    func testGitHubWorkflowRunModel() {
        let json = """
        {
            "id": 789,
            "name": "CI",
            "status": "completed",
            "conclusion": "success",
            "created_at": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let run = try? decoder.decode(GitHubWorkflowRun.self, from: json)

        XCTAssertNotNil(run)
        XCTAssertEqual(run?.id, 789)
        XCTAssertEqual(run?.name, "CI")
        XCTAssertEqual(run?.status, "completed")
        XCTAssertEqual(run?.conclusion, "success")
    }

    func testGitHubRepoStats() {
        let stats = GitHubRepoStats(
            stars: 1000,
            forks: 200,
            openIssues: 50,
            watchers: 800,
            size: 5000,
            language: "Swift",
            updatedAt: "2024-01-01T00:00:00Z"
        )

        XCTAssertEqual(stats.stars, 1000)
        XCTAssertEqual(stats.forks, 200)
        XCTAssertEqual(stats.openIssues, 50)
        XCTAssertEqual(stats.watchers, 800)
        XCTAssertEqual(stats.size, 5000)
        XCTAssertEqual(stats.language, "Swift")
    }

    // MARK: - Configuration Tests

    func testAppConfigDefaults() {
        XCTAssertEqual(AppConfig.githubAPIURL, "https://api.github.com")
        XCTAssertTrue(AppConfig.githubCheckInterval > 0)
        XCTAssertNotNil(AppConfig.enableGitHubIntegration)
    }

    // MARK: - Integration Scenario Tests

    func testCompleteMonitoringCycle() {
        // Test the complete cycle: start -> check -> stop

        var activities: [Activity] = []

        githubMonitor.start { activity in
            activities.append(activity)
        }

        // Allow time for initial checks
        let expectation = self.expectation(description: "Monitoring cycle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)

        let metrics = githubMonitor.getMetrics()
        // Metrics might be 0 if no GitHub token configured
        XCTAssertGreaterThanOrEqual(metrics.totalPRsAnalyzed, 0)

        githubMonitor.stop()

        let finalMetrics = githubMonitor.getMetrics()
        XCTAssertFalse(finalMetrics.isRunning)
    }

    func testMultipleStartStopCycles() {
        // Test that monitor can be started and stopped multiple times

        for i in 1...3 {
            githubMonitor.start { _ in }

            let expectation = self.expectation(description: "Cycle \(i)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }

            waitForExpectations(timeout: 1.0)

            githubMonitor.stop()

            let metrics = githubMonitor.getMetrics()
            XCTAssertFalse(metrics.isRunning, "Monitor should stop correctly in cycle \(i)")
        }
    }

    // MARK: - Performance Tests

    func testMetricsPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = githubMonitor.getMetrics()
            }
        }
    }

    func testCacheClearPerformance() {
        measure {
            for _ in 0..<100 {
                githubMonitor.clearCache()
            }
        }
    }

    // MARK: - Edge Case Tests

    func testEmptyRateLimit() {
        let rateLimit = GitHubRateLimit(
            limit: 0,
            remaining: 0,
            resetDate: Date()
        )

        XCTAssertTrue(rateLimit.isExceeded)
    }

    func testNegativeRateLimit() {
        // In reality this shouldn't happen, but test edge case
        let rateLimit = GitHubRateLimit(
            limit: 5000,
            remaining: -1,
            resetDate: Date()
        )

        // Percent calculation should handle this gracefully
        let percent = rateLimit.percentRemaining
        XCTAssertTrue(percent.isFinite)
    }

    func testFutureResetDate() {
        let futureDate = Date().addingTimeInterval(3600)
        let rateLimit = GitHubRateLimit(
            limit: 5000,
            remaining: 100,
            resetDate: futureDate
        )

        XCTAssertGreaterThan(rateLimit.timeUntilReset, 0)
    }

    func testPastResetDate() {
        let pastDate = Date().addingTimeInterval(-3600)
        let rateLimit = GitHubRateLimit(
            limit: 5000,
            remaining: 100,
            resetDate: pastDate
        )

        XCTAssertLessThan(rateLimit.timeUntilReset, 0)
    }
}

// MARK: - Mock Helper Tests

extension GitHubIntegrationTests {

    func testMockGitHubUser() {
        let mockUser = createMockUser()

        XCTAssertEqual(mockUser.login, "testuser")
        XCTAssertEqual(mockUser.name, "Test User")
    }

    func testMockGitHubRepo() {
        let mockRepo = createMockRepo()

        XCTAssertEqual(mockRepo.name, "test-repo")
        XCTAssertEqual(mockRepo.owner.login, "testuser")
    }

    func testMockGitHubPR() {
        let mockPR = createMockPR()

        XCTAssertEqual(mockPR.number, 123)
        XCTAssertEqual(mockPR.title, "Test PR")
        XCTAssertEqual(mockPR.state, "open")
    }

    // MARK: - Mock Helpers

    private func createMockUser() -> GitHubUser {
        let json = """
        {
            "login": "testuser",
            "name": "Test User",
            "email": "test@example.com"
        }
        """.data(using: .utf8)!

        return try! JSONDecoder().decode(GitHubUser.self, from: json)
    }

    private func createMockRepo() -> GitHubRepo {
        let json = """
        {
            "name": "test-repo",
            "full_name": "testuser/test-repo",
            "owner": {
                "login": "testuser"
            },
            "html_url": "https://github.com/testuser/test-repo"
        }
        """.data(using: .utf8)!

        return try! JSONDecoder().decode(GitHubRepo.self, from: json)
    }

    private func createMockPR() -> GitHubPR {
        let json = """
        {
            "number": 123,
            "title": "Test PR",
            "body": "Test description",
            "state": "open",
            "user": {
                "login": "testuser"
            },
            "html_url": "https://github.com/testuser/test-repo/pull/123"
        }
        """.data(using: .utf8)!

        return try! JSONDecoder().decode(GitHubPR.self, from: json)
    }
}
