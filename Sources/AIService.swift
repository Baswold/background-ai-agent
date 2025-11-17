import Foundation
import AppKit

class AIService {
    static let shared = AIService()

    private let apiKey: String
    private let session: URLSession
    private let maxRetries = 3

    private init() {
        self.apiKey = Settings.shared.claudeAPIKey

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)

        Logger.shared.info("AI Service initialized", category: .ai)
    }

    // MARK: - Real AI Analysis with Caching & Rate Limiting

    func analyzeCode(_ code: String, language: String = "swift") async throws -> CodeAnalysis {
        Logger.shared.debug("Analyzing \(language) code (\(code.count) chars)", category: .ai)

        // Check cache first
        if let cached = await CacheManager.shared.getCachedCodeAnalysis(code: code, language: language) {
            Logger.shared.info("Using cached code analysis", category: .performance)
            return cached
        }

        let prompt = """
        Analyze this \(language) code and identify:
        1. Bugs or potential issues
        2. Performance problems
        3. Security vulnerabilities
        4. Code quality improvements
        5. Best practice violations

        Code:
        ```\(language)
        \(code)
        ```

        Respond in JSON format:
        {
            "issues": [{"type": "bug|performance|security|quality", "line": 0, "description": "", "severity": "high|medium|low", "fix": ""}],
            "summary": "Brief summary"
        }
        """

        let analysis = try await Logger.shared.measurePerformanceAsync("Code Analysis", category: .performance) {
            let response = try await callClaudeWithRetry(prompt: prompt)
            return try parseCodeAnalysis(response)
        }

        // Cache the result
        await CacheManager.shared.cacheCodeAnalysis(code: code, language: language, analysis: analysis)

        Logger.shared.info("Code analysis complete: found \(analysis.issues.count) issues", category: .ai)
        return analysis
    }

    func analyzeScreenshot(_ image: NSImage, context: String) async throws -> ScreenshotAnalysis {
        // Convert image to base64
        guard let imageData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw AIError.imageProcessingFailed
        }

        let base64Image = pngData.base64EncodedString()

        let prompt = """
        Analyze this screenshot in the context of: \(context)

        Identify:
        1. What the user is working on
        2. Any visible issues or errors
        3. Suggestions for improvement
        4. Whether this looks like a form that could be auto-filled
        5. If there's code visible, analyze it for issues

        Provide a JSON response:
        {
            "context": "what the user is doing",
            "issues": ["issue1", "issue2"],
            "suggestions": ["suggestion1"],
            "isForm": false,
            "formFields": [],
            "hasCode": false,
            "codeIssues": []
        }
        """

        let response = try await callClaudeWithVision(prompt: prompt, imageBase64: base64Image)
        return try parseScreenshotAnalysis(response)
    }

    func suggestCodeFix(issue: String, code: String, language: String) async throws -> String {
        let prompt = """
        Fix this \(language) code issue:
        Issue: \(issue)

        Original code:
        ```\(language)
        \(code)
        ```

        Provide ONLY the fixed code, no explanations.
        """

        return try await callClaude(prompt: prompt)
    }

    func analyzePullRequest(prContent: String, diff: String) async throws -> PRAnalysis {
        let prompt = """
        Analyze this GitHub Pull Request:

        PR Description:
        \(prContent)

        Diff:
        ```
        \(diff)
        ```

        Provide analysis in JSON:
        {
            "issues": [{"file": "", "line": 0, "issue": "", "severity": "high|medium|low"}],
            "suggestions": [""],
            "security_concerns": [""],
            "performance_notes": [""],
            "overall_quality": "good|fair|poor",
            "recommendation": "approve|request_changes|comment"
        }
        """

        let response = try await callClaude(prompt: prompt)
        return try parsePRAnalysis(response)
    }

    func generateFormData(fields: [String]) async throws -> [String: String] {
        let prompt = """
        Generate realistic test data for these form fields:
        \(fields.joined(separator: "\n"))

        Return JSON: {"field_name": "value"}
        """

        let response = try await callClaude(prompt: prompt)
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return json
    }

    // MARK: - Claude API Integration with Retry Logic

    private func callClaudeWithRetry(prompt: String, maxTokens: Int = 2048, attemptNumber: Int = 0) async throws -> String {
        do {
            return try await callClaude(prompt: prompt, maxTokens: maxTokens)
        } catch {
            Logger.shared.warning("Claude API call failed (attempt \(attemptNumber + 1)/\(maxRetries)): \(error)", category: .ai)

            // Check if we should retry
            guard attemptNumber < maxRetries - 1 else {
                Logger.shared.error("Max retries exceeded for Claude API", category: .errorHandling)
                throw error
            }

            // Calculate backoff delay
            let baseDelay: TimeInterval = 2.0
            let delay = min(baseDelay * pow(2.0, Double(attemptNumber)), 60.0)
            let jitter = Double.random(in: 0...0.3) * delay

            Logger.shared.info("Retrying in \(String(format: "%.1f", delay + jitter))s...", category: .ai)

            try await Task.sleep(nanoseconds: UInt64((delay + jitter) * 1_000_000_000))

            return try await callClaudeWithRetry(prompt: prompt, maxTokens: maxTokens, attemptNumber: attemptNumber + 1)
        }
    }

    private func callClaude(prompt: String, maxTokens: Int = 2048) async throws -> String {
        guard !apiKey.isEmpty else {
            Logger.shared.error("Claude API key not configured", category: .ai)
            throw AppError.apiKeyMissing(service: "Claude")
        }

        // Apply rate limiting
        try await RateLimiter.shared.waitForAvailability(for: "claude")

        guard let url = URL(string: AppConfig.claudeAPIURL) else {
            throw AppError.invalidURL(url: AppConfig.claudeAPIURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": AppConfig.claudeModel,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw AppError.serializationError(type: "API Request", underlying: error)
        }

        Logger.shared.verbose("Calling Claude API (model: \(AppConfig.claudeModel), tokens: \(maxTokens))", category: .ai)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkUnavailable
        }

        // Handle rate limiting
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }

            Logger.shared.warning("Claude API rate limit hit", category: .ai)
            throw AppError.apiRateLimitExceeded(service: "Claude", retryAfter: retryAfter)
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            Logger.shared.error("Claude API error \(httpResponse.statusCode): \(errorMessage)", category: .ai)

            if httpResponse.statusCode >= 500 {
                throw AppError.httpError(statusCode: httpResponse.statusCode, message: "Server error")
            } else {
                throw AppError.invalidAPIResponse(service: "Claude", details: errorMessage)
            }
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            Logger.shared.error("Failed to parse Claude API response", category: .ai)
            throw AppError.invalidAPIResponse(service: "Claude", details: "Invalid response format")
        }

        Logger.shared.verbose("Claude API call successful (\(text.count) chars)", category: .ai)
        return text
    }

    private func callClaudeWithVision(prompt: String, imageBase64: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }

        let url = URL(string: AppConfig.claudeAPIURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": AppConfig.claudeModel,
            "max_tokens": 2048,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/png",
                                "data": imageBase64
                            ]
                        ],
                        [
                            "type": "text",
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.networkError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw AIError.invalidResponse
        }

        return text
    }

    // MARK: - Response Parsing

    private func parseCodeAnalysis(_ response: String) throws -> CodeAnalysis {
        // Extract JSON from response (Claude might wrap it in markdown)
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONDecoder().decode(CodeAnalysis.self, from: data) else {
            // Fallback parsing
            return CodeAnalysis(issues: [], summary: response)
        }

        return json
    }

    private func parseScreenshotAnalysis(_ response: String) throws -> ScreenshotAnalysis {
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONDecoder().decode(ScreenshotAnalysis.self, from: data) else {
            return ScreenshotAnalysis(
                context: response,
                issues: [],
                suggestions: [],
                isForm: false,
                formFields: [],
                hasCode: false,
                codeIssues: []
            )
        }

        return json
    }

    private func parsePRAnalysis(_ response: String) throws -> PRAnalysis {
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONDecoder().decode(PRAnalysis.self, from: data) else {
            return PRAnalysis(
                issues: [],
                suggestions: [],
                securityConcerns: [],
                performanceNotes: [],
                overallQuality: "unknown",
                recommendation: "comment"
            )
        }

        return json
    }

    private func extractJSON(from text: String) -> String {
        // Try to extract JSON from markdown code blocks
        if let range = text.range(of: "```json\n") {
            let start = range.upperBound
            if let endRange = text.range(of: "\n```", range: start..<text.endIndex) {
                return String(text[start..<endRange.lowerBound])
            }
        }

        // Try to find raw JSON
        if let startBrace = text.firstIndex(of: "{"),
           let endBrace = text.lastIndex(of: "}") {
            return String(text[startBrace...endBrace])
        }

        return text
    }
}

// MARK: - Data Models

struct CodeAnalysis: Codable {
    struct Issue: Codable {
        let type: String
        let line: Int
        let description: String
        let severity: String
        let fix: String
    }

    let issues: [Issue]
    let summary: String
}

struct ScreenshotAnalysis: Codable {
    let context: String
    let issues: [String]
    let suggestions: [String]
    let isForm: Bool
    let formFields: [String]
    let hasCode: Bool
    let codeIssues: [String]
}

struct PRAnalysis: Codable {
    struct Issue: Codable {
        let file: String
        let line: Int
        let issue: String
        let severity: String
    }

    let issues: [Issue]
    let suggestions: [String]
    let securityConcerns: [String]
    let performanceNotes: [String]
    let overallQuality: String
    let recommendation: String
}

enum AIError: Error {
    case missingAPIKey
    case networkError
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case imageProcessingFailed
}
