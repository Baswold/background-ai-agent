import Foundation

class GitHubService {
    static let shared = GitHubService()

    private let session: URLSession
    private var token: String {
        return Settings.shared.githubToken
    }

    private init() {
        self.session = URLSession.shared
    }

    // MARK: - Real GitHub API Calls

    func getAuthenticatedUser() async throws -> GitHubUser {
        let url = URL(string: "\(AppConfig.githubAPIURL)/user")!
        let data = try await makeRequest(url: url)

        return try JSONDecoder().decode(GitHubUser.self, from: data)
    }

    func getRepositories() async throws -> [GitHubRepo] {
        let url = URL(string: "\(AppConfig.githubAPIURL)/user/repos?sort=updated&per_page=30")!
        let data = try await makeRequest(url: url)

        return try JSONDecoder().decode([GitHubRepo].self, from: data)
    }

    func getPullRequests(owner: String, repo: String) async throws -> [GitHubPR] {
        let url = URL(string: "\(AppConfig.githubAPIURL)/repos/\(owner)/\(repo)/pulls?state=open")!
        let data = try await makeRequest(url: url)

        return try JSONDecoder().decode([GitHubPR].self, from: data)
    }

    func getPullRequestDiff(owner: String, repo: String, number: Int) async throws -> String {
        let url = URL(string: "\(AppConfig.githubAPIURL)/repos/\(owner)/\(repo)/pulls/\(number)")!

        var request = URLRequest(url: url)
        request.addValue("application/vnd.github.v3.diff", forHTTPHeaderField: "Accept")
        request.addValue("token \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await session.data(for: request)
        return String(data: data, encoding: .utf8) ?? ""
    }

    func getPullRequestFiles(owner: String, repo: String, number: Int) async throws -> [GitHubFile] {
        let url = URL(string: "\(AppConfig.githubAPIURL)/repos/\(owner)/\(repo)/pulls/\(number)/files")!
        let data = try await makeRequest(url: url)

        return try JSONDecoder().decode([GitHubFile].self, from: data)
    }

    func createReviewComment(owner: String, repo: String, number: Int, comment: ReviewComment) async throws {
        let url = URL(string: "\(AppConfig.githubAPIURL)/repos/\(owner)/\(repo)/pulls/\(number)/reviews")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("token \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "body": comment.body,
            "event": comment.event,
            "comments": comment.comments?.map { [
                "path": $0.path,
                "position": $0.position,
                "body": $0.body
            ] } ?? []
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GitHubError.apiError
        }

        print("✅ Posted review comment to PR #\(number)")
    }

    func createIssueComment(owner: String, repo: String, number: Int, body: String) async throws {
        let url = URL(string: "\(AppConfig.githubAPIURL)/repos/\(owner)/\(repo)/issues/\(number)/comments")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("token \(token)", forHTTPHeaderField: "Authorization")

        let requestBody: [String: Any] = ["body": body]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw GitHubError.apiError
        }

        print("✅ Posted comment to issue/PR #\(number)")
    }

    func listNotifications() async throws -> [GitHubNotification] {
        let url = URL(string: "\(AppConfig.githubAPIURL)/notifications?per_page=30")!
        let data = try await makeRequest(url: url)

        return try JSONDecoder().decode([GitHubNotification].self, from: data)
    }

    func searchCode(query: String) async throws -> [CodeSearchResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\(AppConfig.githubAPIURL)/search/code?q=\(encodedQuery)")!
        let data = try await makeRequest(url: url)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            return []
        }

        return try JSONDecoder().decode([CodeSearchResult].self, from: JSONSerialization.data(withJSONObject: items))
    }

    // MARK: - Helper Methods

    private func makeRequest(url: URL) async throws -> Data {
        guard !token.isEmpty else {
            throw GitHubError.missingToken
        }

        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("token \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GitHubError.apiError
        }

        return data
    }
}

// MARK: - Enhanced GitHub Monitor

extension GitHubMonitor {
    func startRealMonitoring(onActivity: @escaping (Activity) -> Void) {
        activityCallback = onActivity

        guard !Settings.shared.githubToken.isEmpty else {
            print("⚠️ GitHub token not configured")
            return
        }

        print("🐙 Real GitHub monitor starting...")

        // Monitor every 5 minutes
        timer = Timer.scheduledTimer(withTimeInterval: AppConfig.githubCheckInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.checkRealPRs()
            }
        }

        // Do initial check
        Task {
            await checkRealPRs()
        }
    }

    private func checkRealPRs() async {
        do {
            let repos = try await GitHubService.shared.getRepositories()

            for repo in repos.prefix(5) { // Check top 5 active repos
                guard let owner = repo.owner.login else { continue }

                let prs = try await GitHubService.shared.getPullRequests(owner: owner, repo: repo.name)

                for pr in prs {
                    await analyzePR(pr, owner: owner, repo: repo.name)
                }
            }

        } catch {
            print("❌ GitHub monitoring error: \(error)")
        }
    }

    private func analyzePR(_ pr: GitHubPR, owner: String, repo: String) async {
        let prId = "\(owner)/\(repo)#\(pr.number)"

        guard !checkedPRs.contains(prId) else { return }
        checkedPRs.insert(prId)

        do {
            // Get diff
            let diff = try await GitHubService.shared.getPullRequestDiff(owner: owner, repo: repo, number: pr.number)

            // Analyze with AI
            let analysis = try await AIService.shared.analyzePullRequest(
                prContent: pr.body ?? "",
                diff: diff
            )

            // Report findings
            let activity = Activity(
                title: "PR #\(pr.number) Analyzed: \(repo)",
                description: "Found \(analysis.issues.count) issues. Quality: \(analysis.overallQuality)",
                type: .githubPR
            )

            await MainActor.run {
                self.activityCallback?(activity)
            }

            // Auto-comment if serious issues found
            let highSeverityIssues = analysis.issues.filter { $0.severity == "high" }
            if !highSeverityIssues.isEmpty && Settings.shared.enableGitHub {
                try await postAnalysisComment(
                    owner: owner,
                    repo: repo,
                    number: pr.number,
                    analysis: analysis
                )
            }

            print("✅ Analyzed PR #\(pr.number) in \(repo)")

        } catch {
            print("❌ PR analysis error: \(error)")
        }
    }

    private func postAnalysisComment(owner: String, repo: String, number: Int, analysis: PRAnalysis) async throws {
        var comment = "## 🧠 AI Analysis\n\n"

        if !analysis.issues.isEmpty {
            comment += "### Issues Found\n\n"
            for issue in analysis.issues.prefix(5) {
                comment += "- **\(issue.severity.uppercased())**: \(issue.file):\(issue.line) - \(issue.issue)\n"
            }
            comment += "\n"
        }

        if !analysis.securityConcerns.isEmpty {
            comment += "### 🔒 Security Concerns\n\n"
            for concern in analysis.securityConcerns {
                comment += "- \(concern)\n"
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

        comment += "\n**Overall Quality**: \(analysis.overallQuality)  \n"
        comment += "**Recommendation**: \(analysis.recommendation)\n\n"
        comment += "*Analyzed by Background AI Agent*"

        try await GitHubService.shared.createIssueComment(
            owner: owner,
            repo: repo,
            number: number,
            body: comment
        )
    }
}

// MARK: - Data Models

struct GitHubUser: Codable {
    let login: String
    let name: String?
    let email: String?
}

struct GitHubRepo: Codable {
    let name: String
    let fullName: String?
    let owner: GitHubOwner
    let htmlUrl: String?

    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case owner
        case htmlUrl = "html_url"
    }
}

struct GitHubOwner: Codable {
    let login: String?
}

struct GitHubPR: Codable {
    let number: Int
    let title: String
    let body: String?
    let state: String
    let user: GitHubOwner
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case number, title, body, state, user
        case htmlUrl = "html_url"
    }
}

struct GitHubFile: Codable {
    let filename: String
    let status: String
    let additions: Int
    let deletions: Int
    let patch: String?
}

struct GitHubNotification: Codable {
    let id: String
    let subject: NotificationSubject
    let repository: GitHubRepo
}

struct NotificationSubject: Codable {
    let title: String
    let type: String
}

struct CodeSearchResult: Codable {
    let name: String
    let path: String
    let repository: GitHubRepo
}

struct ReviewComment {
    let body: String
    let event: String // "COMMENT", "APPROVE", "REQUEST_CHANGES"
    let comments: [LineComment]?
}

struct LineComment {
    let path: String
    let position: Int
    let body: String
}

enum GitHubError: Error {
    case missingToken
    case networkError
    case apiError
    case invalidResponse
}
