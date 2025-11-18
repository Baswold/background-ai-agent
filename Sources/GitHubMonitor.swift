import Foundation
import Cocoa

class GitHubMonitor {
    private var isRunning = false
    private var timer: Timer?
    fileprivate var activityCallback: ((Activity) -> Void)?
    fileprivate var checkedPRs: Set<String> = []

    // Rate limiting
    private var lastAPICall: Date?
    private let minAPICallInterval: TimeInterval = 2.0 // Minimum 2 seconds between calls
    private var apiCallCount = 0
    private var apiCallResetTime = Date()

    // Caching
    private var cachedRepos: [GitHubRepo] = []
    private var cacheExpiry: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes

    // Metrics
    private var totalPRsAnalyzed = 0
    private var totalIssuesFound = 0
    private var lastCheckTime: Date?

    // Queue management
    private var prQueue: [(owner: String, repo: String, pr: GitHubPR)] = []
    private let maxQueueSize = 20

    func start(onActivity: @escaping (Activity) -> Void) {
        guard !isRunning else { return }

        isRunning = true
        activityCallback = onActivity

        print("🐙 GitHub monitor starting with REAL API integration...")

        // Verify GitHub token is configured
        guard !Settings.shared.githubToken.isEmpty else {
            print("⚠️ GitHub token not configured - skipping real monitoring")
            let activity = Activity(
                title: "GitHub Monitor Configuration Required",
                description: "Please configure your GitHub token in settings to enable PR monitoring",
                type: .githubPR
            )
            activityCallback?(activity)
            return
        }

        // Check for GitHub activity every 5 minutes (respecting API rate limits)
        timer = Timer.scheduledTimer(withTimeInterval: AppConfig.githubCheckInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.checkRealPRs()
            }
        }

        print("✅ GitHub monitor started - checking every \(Int(AppConfig.githubCheckInterval/60)) minutes")

        // Do an initial check after 5 seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) { [weak self] in
            Task {
                await self?.checkRealPRs()
            }
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        print("🛑 GitHub monitor stopped")

        // Log final metrics
        print("📊 GitHub Monitor Stats:")
        print("  - PRs Analyzed: \(totalPRsAnalyzed)")
        print("  - Issues Found: \(totalIssuesFound)")
    }

    // MARK: - Real GitHub Monitoring

    private func checkRealPRs() async {
        guard isRunning else { return }

        lastCheckTime = Date()
        print("🔍 Checking GitHub for new PRs...")

        do {
            // Rate limit check
            if let lastCall = lastAPICall,
               Date().timeIntervalSince(lastCall) < minAPICallInterval {
                print("⏱️ Rate limiting - waiting...")
                try await Task.sleep(nanoseconds: UInt64(minAPICallInterval * 1_000_000_000))
            }

            // Check cache validity
            let repos: [GitHubRepo]
            if let expiry = cacheExpiry, Date() < expiry, !cachedRepos.isEmpty {
                print("📦 Using cached repository list (\(cachedRepos.count) repos)")
                repos = cachedRepos
            } else {
                print("🔄 Fetching fresh repository list...")
                lastAPICall = Date()
                repos = try await GitHubService.shared.getRepositories()
                cachedRepos = repos
                cacheExpiry = Date().addingTimeInterval(cacheValidityDuration)
                print("✅ Found \(repos.count) repositories")
            }

            // Check top repositories for PRs (limit to prevent rate limiting)
            let reposToCheck = Array(repos.prefix(10))

            for repo in reposToCheck {
                guard isRunning else { return }

                guard let owner = repo.owner.login else { continue }

                // Rate limit between repo checks
                try await Task.sleep(nanoseconds: UInt64(minAPICallInterval * 1_000_000_000))
                lastAPICall = Date()

                do {
                    let prs = try await GitHubService.shared.getPullRequests(owner: owner, repo: repo.name)

                    if !prs.isEmpty {
                        print("📋 Found \(prs.count) open PRs in \(repo.name)")
                    }

                    for pr in prs {
                        guard isRunning else { return }

                        // Check if we should analyze this PR
                        if shouldAnalyzePR(pr, in: repo) {
                            // Add to queue instead of analyzing immediately
                            addToQueue(owner: owner, repo: repo.name, pr: pr)
                        }
                    }
                } catch {
                    print("⚠️ Error checking PRs for \(repo.name): \(error.localizedDescription)")
                }
            }

            // Process the queue
            await processQueue()

            print("✅ GitHub check complete")

        } catch GitHubError.missingToken {
            print("❌ GitHub token is missing or invalid")
            let activity = Activity(
                title: "GitHub Authentication Error",
                description: "Please check your GitHub token in settings",
                type: .githubPR
            )
            await MainActor.run {
                self.activityCallback?(activity)
            }
        } catch {
            print("❌ GitHub monitoring error: \(error.localizedDescription)")
        }
    }

    private func shouldAnalyzePR(_ pr: GitHubPR, in repo: GitHubRepo) -> Bool {
        let prId = "\(repo.name)#\(pr.number)"

        // Skip if already checked
        if checkedPRs.contains(prId) {
            return false
        }

        // Filter based on PR age (skip very old PRs)
        // In a real implementation, would parse pr.created_at

        // Filter based on PR size (could check file count)
        // For now, we'll analyze all new PRs

        return true
    }

    private func addToQueue(owner: String, repo: String, pr: GitHubPR) {
        let prId = "\(repo)#\(pr.number)"

        guard !checkedPRs.contains(prId) else { return }
        guard prQueue.count < maxQueueSize else {
            print("⚠️ PR queue is full, skipping \(prId)")
            return
        }

        prQueue.append((owner: owner, repo: repo, pr: pr))
        print("📥 Added to queue: \(prId) - \(pr.title)")
    }

    private func processQueue() async {
        print("🔄 Processing PR queue (\(prQueue.count) items)...")

        while !prQueue.isEmpty && isRunning {
            let item = prQueue.removeFirst()

            // Rate limit between analyses
            try? await Task.sleep(nanoseconds: UInt64(minAPICallInterval * 1_000_000_000))

            await analyzePR(item.pr, owner: item.owner, repo: item.repo)
        }

        print("✅ Queue processing complete")
    }

    fileprivate func analyzePR(_ pr: GitHubPR, owner: String, repo: String) async {
        let prId = "\(owner)/\(repo)#\(pr.number)"

        guard !checkedPRs.contains(prId) else { return }
        checkedPRs.insert(prId)

        print("🔬 Analyzing PR #\(pr.number): \(pr.title)")

        do {
            // Get PR diff
            lastAPICall = Date()
            let diff = try await GitHubService.shared.getPullRequestDiff(owner: owner, repo: repo, number: pr.number)

            // Check diff size to avoid sending huge diffs to AI
            let diffLineCount = diff.components(separatedBy: "\n").count
            if diffLineCount > 500 {
                print("⚠️ PR diff is too large (\(diffLineCount) lines), analyzing first 500 lines only")
            }

            let truncatedDiff = diff.components(separatedBy: "\n").prefix(500).joined(separator: "\n")

            // Analyze with AI
            guard !Settings.shared.claudeAPIKey.isEmpty else {
                print("⚠️ Claude API key not configured - skipping AI analysis")
                return
            }

            let analysis = try await AIService.shared.analyzePullRequest(
                prContent: pr.body ?? pr.title,
                diff: truncatedDiff
            )

            totalPRsAnalyzed += 1
            totalIssuesFound += analysis.issues.count

            // Report findings
            let issueText = analysis.issues.count == 1 ? "issue" : "issues"
            let activity = Activity(
                title: "PR #\(pr.number) Analyzed: \(repo)",
                description: "Found \(analysis.issues.count) \(issueText). Quality: \(analysis.overallQuality). Recommendation: \(analysis.recommendation)",
                type: .githubPR
            )

            await MainActor.run {
                self.activityCallback?(activity)
            }

            // Log detailed findings
            if !analysis.issues.isEmpty {
                print("📊 Issues found in PR #\(pr.number):")
                for issue in analysis.issues.prefix(5) {
                    print("  - [\(issue.severity.uppercased())] \(issue.file):\(issue.line) - \(issue.issue)")
                }
            }

            if !analysis.securityConcerns.isEmpty {
                print("🔒 Security concerns:")
                for concern in analysis.securityConcerns {
                    print("  - \(concern)")
                }
            }

            // Auto-comment if serious issues found and enabled
            let highSeverityIssues = analysis.issues.filter { $0.severity == "high" }
            if !highSeverityIssues.isEmpty && Settings.shared.enableGitHub && AppConfig.enableGitHubIntegration {
                print("💬 Posting analysis comment to PR #\(pr.number)...")
                try await postAnalysisComment(
                    owner: owner,
                    repo: repo,
                    number: pr.number,
                    analysis: analysis
                )
            }

            print("✅ Analysis complete for PR #\(pr.number)")

        } catch GitHubError.missingToken {
            print("❌ GitHub token authentication failed")
        } catch AIError.missingAPIKey {
            print("❌ Claude API key not configured")
        } catch {
            print("❌ PR analysis error for #\(pr.number): \(error.localizedDescription)")
        }
    }

    private func postAnalysisComment(owner: String, repo: String, number: Int, analysis: PRAnalysis) async throws {
        var comment = "## 🧠 AI Code Review\n\n"
        comment += "> Automated analysis by Background AI Agent\n\n"

        if !analysis.issues.isEmpty {
            comment += "### ⚠️ Issues Found\n\n"
            for (index, issue) in analysis.issues.prefix(5).enumerated() {
                let emoji = issue.severity == "high" ? "🔴" : issue.severity == "medium" ? "🟡" : "🔵"
                comment += "\(index + 1). \(emoji) **\(issue.severity.uppercased())** - `\(issue.file):\(issue.line)`\n"
                comment += "   > \(issue.issue)\n\n"
            }

            if analysis.issues.count > 5 {
                comment += "_... and \(analysis.issues.count - 5) more issues_\n\n"
            }
        }

        if !analysis.securityConcerns.isEmpty {
            comment += "### 🔒 Security Concerns\n\n"
            for concern in analysis.securityConcerns {
                comment += "- ⚠️ \(concern)\n"
            }
            comment += "\n"
        }

        if !analysis.performanceNotes.isEmpty {
            comment += "### ⚡ Performance Notes\n\n"
            for note in analysis.performanceNotes {
                comment += "- \(note)\n"
            }
            comment += "\n"
        }

        if !analysis.suggestions.isEmpty {
            comment += "### 💡 Suggestions\n\n"
            for suggestion in analysis.suggestions.prefix(3) {
                comment += "- \(suggestion)\n"
            }
            comment += "\n"
        }

        comment += "---\n\n"
        comment += "**Overall Quality**: \(analysis.overallQuality.capitalized)  \n"
        comment += "**Recommendation**: \(analysis.recommendation.capitalized)\n\n"
        comment += "<sub>🤖 This review was generated automatically. [Learn more](https://github.com)</sub>"

        try await GitHubService.shared.createIssueComment(
            owner: owner,
            repo: repo,
            number: number,
            body: comment
        )

        print("✅ Posted analysis comment to PR #\(number)")

        let activity = Activity(
            title: "Comment Posted on PR #\(number)",
            description: "AI analysis comment added to \(repo) PR #\(number)",
            type: .githubPR
        )

        await MainActor.run {
            self.activityCallback?(activity)
        }
    }

    // MARK: - Manual PR Operations

    func scanPullRequest(url: String) async {
        print("🔍 Manually scanning PR: \(url)")

        // Parse URL to extract owner, repo, and PR number
        // Expected format: https://github.com/owner/repo/pull/number
        guard let components = URLComponents(string: url),
              let pathComponents = components.path.split(separator: "/") as [Substring]?,
              pathComponents.count >= 4,
              let owner = pathComponents.first,
              let repo = pathComponents.dropFirst().first,
              pathComponents[pathComponents.count - 2] == "pull",
              let prNumber = Int(pathComponents.last ?? "") else {
            print("❌ Invalid GitHub PR URL format")
            let activity = Activity(
                title: "Invalid PR URL",
                description: "Could not parse PR URL. Expected format: https://github.com/owner/repo/pull/number",
                type: .githubPR
            )
            await MainActor.run {
                self.activityCallback?(activity)
            }
            return
        }

        do {
            // Fetch PR details
            let prs = try await GitHubService.shared.getPullRequests(owner: String(owner), repo: String(repo))

            if let pr = prs.first(where: { $0.number == prNumber }) {
                await analyzePR(pr, owner: String(owner), repo: String(repo))
            } else {
                print("❌ PR #\(prNumber) not found")
                let activity = Activity(
                    title: "PR Not Found",
                    description: "Could not find PR #\(prNumber) in \(owner)/\(repo)",
                    type: .githubPR
                )
                await MainActor.run {
                    self.activityCallback?(activity)
                }
            }
        } catch {
            print("❌ Error scanning PR: \(error.localizedDescription)")
        }
    }

    // MARK: - Metrics and Status

    func getMetrics() -> GitHubMonitorMetrics {
        return GitHubMonitorMetrics(
            totalPRsAnalyzed: totalPRsAnalyzed,
            totalIssuesFound: totalIssuesFound,
            queueSize: prQueue.count,
            lastCheckTime: lastCheckTime,
            isRunning: isRunning,
            cachedRepoCount: cachedRepos.count
        )
    }

    func clearCache() {
        cachedRepos.removeAll()
        cacheExpiry = nil
        print("🗑️ GitHub cache cleared")
    }

    func resetMetrics() {
        totalPRsAnalyzed = 0
        totalIssuesFound = 0
        print("📊 GitHub metrics reset")
    }
}

// MARK: - Metrics Model

struct GitHubMonitorMetrics {
    let totalPRsAnalyzed: Int
    let totalIssuesFound: Int
    let queueSize: Int
    let lastCheckTime: Date?
    let isRunning: Bool
    let cachedRepoCount: Int

    var statusDescription: String {
        if !isRunning {
            return "Stopped"
        }

        if let lastCheck = lastCheckTime {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let timeString = formatter.localizedString(for: lastCheck, relativeTo: Date())
            return "Last check \(timeString)"
        }

        return "Running"
    }
}
