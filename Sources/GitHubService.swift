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

    func getIssues(owner: String, repo: String, state: String = "open") async throws -> [GitHubIssue] {
        let url = URL(string: "\(AppConfig.githubAPIURL)/repos/\(owner)/\(repo)/issues?state=\(state)")!
        let data = try await makeRequest(url: url)
        return try JSONDecoder().decode([GitHubIssue].self, from: data)
    }

    func createIssue(owner: String, repo: String, title: String, body: String?, labels: [String]? = nil) async throws -> GitHubIssue {
        let url = URL(string: "\(AppConfig.githubAPIURL)/repos/\(owner)/\(repo)/issues")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("token \(token)", forHTTPHeaderField: "Authorization")

        var requestBody: [String: Any] = ["title": title]
        if let body = body {
            requestBody["body"] = body
        }
        if let labels = labels {
            requestBody["labels"] = labels
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw GitHubError.apiError()
        }

        return try JSONDecoder().decode(GitHubIssue.self, from: data)
    }

    func getRepositoryStats(owner: String, repo: String) async throws -> GitHubRepoStats {
        let url = URL(string: "\(AppConfig.githubAPIURL)/repos/\(owner)/\(repo)")!
        let data = try await makeRequest(url: url)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GitHubError.invalidResponse
        }

        return GitHubRepoStats(
            stars: json["stargazers_count"] as? Int ?? 0,
            forks: json["forks_count"] as? Int ?? 0,
            openIssues: json["open_issues_count"] as? Int ?? 0,
            watchers: json["watchers_count"] as? Int ?? 0,
            size: json["size"] as? Int ?? 0,
            language: json["language"] as? String,
            updatedAt: json["updated_at"] as? String
        )
    }

    func getCommits(owner: String, repo: String, limit: Int = 30) async throws -> [GitHubCommit] {
        let url = URL(string: "\(AppConfig.githubAPIURL)/repos/\(owner)/\(repo)/commits?per_page=\(limit)")!
        let data = try await makeRequest(url: url)
        return try JSONDecoder().decode([GitHubCommit].self, from: data)
    }

    func getBranches(owner: String, repo: String) async throws -> [GitHubBranch] {
        let url = URL(string: "\(AppConfig.githubAPIURL)/repos/\(owner)/\(repo)/branches")!
        let data = try await makeRequest(url: url)
        return try JSONDecoder().decode([GitHubBranch].self, from: data)
    }

    func getWorkflowRuns(owner: String, repo: String) async throws -> [GitHubWorkflowRun] {
        let url = URL(string: "\(AppConfig.githubAPIURL)/repos/\(owner)/\(repo)/actions/runs?per_page=10")!
        let data = try await makeRequest(url: url)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let workflowRuns = json["workflow_runs"] as? [[String: Any]] else {
            return []
        }

        return try JSONDecoder().decode([GitHubWorkflowRun].self, from: JSONSerialization.data(withJSONObject: workflowRuns))
    }

    func approvePullRequest(owner: String, repo: String, number: Int, comment: String? = nil) async throws {
        let url = URL(string: "\(AppConfig.githubAPIURL)/repos/\(owner)/\(repo)/pulls/\(number)/reviews")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("token \(token)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = ["event": "APPROVE"]
        if let comment = comment {
            body["body"] = comment
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GitHubError.apiError()
        }

        print("✅ Approved PR #\(number)")
    }

    // MARK: - Helper Methods

    private func makeRequest(url: URL, retryCount: Int = 0) async throws -> Data {
        guard !token.isEmpty else {
            throw GitHubError.missingToken
        }

        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubError.networkError
            }

            // Handle rate limiting
            if httpResponse.statusCode == 403 {
                if let rateLimitRemaining = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
                   rateLimitRemaining == "0" {
                    if let resetTime = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset"),
                       let resetTimestamp = TimeInterval(resetTime) {
                        let resetDate = Date(timeIntervalSince1970: resetTimestamp)
                        let waitTime = resetDate.timeIntervalSinceNow
                        throw GitHubError.rateLimitExceeded(resetDate: resetDate, waitSeconds: Int(waitTime))
                    }
                }
            }

            // Handle other status codes
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"

                // Retry on 502, 503, 504 errors
                if (httpResponse.statusCode == 502 || httpResponse.statusCode == 503 || httpResponse.statusCode == 504) && retryCount < 3 {
                    let backoffDelay = pow(2.0, Double(retryCount)) // Exponential backoff: 1s, 2s, 4s
                    print("⏱️ Server error \(httpResponse.statusCode), retrying in \(Int(backoffDelay))s (attempt \(retryCount + 1)/3)...")
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                    return try await makeRequest(url: url, retryCount: retryCount + 1)
                }

                throw GitHubError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
            }

            return data

        } catch is CancellationError {
            throw GitHubError.requestCancelled
        } catch let error as GitHubError {
            throw error
        } catch {
            // Network errors - retry up to 3 times
            if retryCount < 3 {
                let backoffDelay = pow(2.0, Double(retryCount))
                print("⏱️ Network error, retrying in \(Int(backoffDelay))s (attempt \(retryCount + 1)/3)...")
                try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                return try await makeRequest(url: url, retryCount: retryCount + 1)
            }
            throw GitHubError.networkError(underlying: error)
        }
    }

    func getRateLimit() async throws -> GitHubRateLimit {
        let url = URL(string: "\(AppConfig.githubAPIURL)/rate_limit")!
        let data = try await makeRequest(url: url)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resources = json["resources"] as? [String: Any],
              let core = resources["core"] as? [String: Any],
              let limit = core["limit"] as? Int,
              let remaining = core["remaining"] as? Int,
              let reset = core["reset"] as? Int else {
            throw GitHubError.invalidResponse
        }

        return GitHubRateLimit(
            limit: limit,
            remaining: remaining,
            resetDate: Date(timeIntervalSince1970: TimeInterval(reset))
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

struct GitHubIssue: Codable {
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let state: String
    let user: GitHubOwner
    let labels: [GitHubLabel]?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, user, labels
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GitHubLabel: Codable {
    let name: String
    let color: String
}

struct GitHubRepoStats {
    let stars: Int
    let forks: Int
    let openIssues: Int
    let watchers: Int
    let size: Int
    let language: String?
    let updatedAt: String?
}

struct GitHubCommit: Codable {
    let sha: String
    let commit: CommitDetail

    struct CommitDetail: Codable {
        let message: String
        let author: CommitAuthor
    }

    struct CommitAuthor: Codable {
        let name: String
        let email: String
        let date: String
    }
}

struct GitHubBranch: Codable {
    let name: String
    let protected: Bool
}

struct GitHubWorkflowRun: Codable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion
        case createdAt = "created_at"
    }
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

struct GitHubRateLimit {
    let limit: Int
    let remaining: Int
    let resetDate: Date

    var isExceeded: Bool {
        return remaining == 0
    }

    var timeUntilReset: TimeInterval {
        return resetDate.timeIntervalSinceNow
    }

    var percentRemaining: Double {
        return Double(remaining) / Double(limit) * 100.0
    }
}

enum GitHubError: Error, LocalizedError {
    case missingToken
    case networkError(underlying: Error? = nil)
    case apiError(statusCode: Int? = nil, message: String? = nil)
    case invalidResponse
    case rateLimitExceeded(resetDate: Date, waitSeconds: Int)
    case requestCancelled

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "GitHub token is missing or not configured"
        case .networkError(let underlying):
            if let error = underlying {
                return "Network error: \(error.localizedDescription)"
            }
            return "Network error occurred while connecting to GitHub"
        case .apiError(let code, let message):
            if let code = code, let message = message {
                return "GitHub API error (\(code)): \(message)"
            } else if let code = code {
                return "GitHub API error (HTTP \(code))"
            }
            return "GitHub API error occurred"
        case .invalidResponse:
            return "Received invalid response from GitHub API"
        case .rateLimitExceeded(let resetDate, let waitSeconds):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "GitHub API rate limit exceeded. Resets at \(formatter.string(from: resetDate)) (in \(waitSeconds)s)"
        case .requestCancelled:
            return "Request was cancelled"
        }
    }
}
