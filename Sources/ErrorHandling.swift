import Foundation

// MARK: - Comprehensive Error System

/// Centralized error handling for the entire application
enum AppError: Error, CustomStringConvertible {
    // AI Service Errors
    case aiServiceError(AIServiceError)
    case apiKeyMissing(service: String)
    case apiRateLimitExceeded(service: String, retryAfter: TimeInterval?)
    case apiQuotaExceeded(service: String)
    case invalidAPIResponse(service: String, details: String)

    // File System Errors
    case fileNotFound(path: String)
    case fileReadError(path: String, underlying: Error)
    case fileWriteError(path: String, underlying: Error)
    case directoryCreationFailed(path: String, underlying: Error)
    case insufficientPermissions(path: String)

    // Network Errors
    case networkUnavailable
    case connectionTimeout(service: String)
    case invalidURL(url: String)
    case httpError(statusCode: Int, message: String)

    // Configuration Errors
    case invalidConfiguration(field: String, reason: String)
    case missingRequiredSetting(setting: String)
    case configurationValidationFailed(errors: [String])

    // Code Analysis Errors
    case codeAnalysisFailed(file: String, reason: String)
    case unsupportedLanguage(language: String)
    case parsingError(details: String)

    // Screenshot/Vision Errors
    case screenCapturePermissionDenied
    case screenCaptureFailed(reason: String)
    case imageProcessingFailed(details: String)
    case ocrFailed(underlying: Error)

    // GitHub Errors
    case githubAuthenticationFailed
    case githubResourceNotFound(resource: String)
    case githubAPIError(statusCode: Int, message: String)

    // Data Errors
    case serializationError(type: String, underlying: Error)
    case deserializationError(type: String, underlying: Error)
    case invalidData(context: String)

    // System Errors
    case insufficientResources(resource: String)
    case componentInitializationFailed(component: String, underlying: Error?)
    case unexpectedState(description: String)

    var description: String {
        switch self {
        case .aiServiceError(let error):
            return "AI Service Error: \(error)"
        case .apiKeyMissing(let service):
            return "API key missing for \(service). Please configure in settings."
        case .apiRateLimitExceeded(let service, let retryAfter):
            if let retry = retryAfter {
                return "Rate limit exceeded for \(service). Retry after \(Int(retry)) seconds."
            }
            return "Rate limit exceeded for \(service)."
        case .apiQuotaExceeded(let service):
            return "API quota exceeded for \(service). Please check your usage."
        case .invalidAPIResponse(let service, let details):
            return "Invalid API response from \(service): \(details)"

        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileReadError(let path, let error):
            return "Failed to read file '\(path)': \(error.localizedDescription)"
        case .fileWriteError(let path, let error):
            return "Failed to write file '\(path)': \(error.localizedDescription)"
        case .directoryCreationFailed(let path, let error):
            return "Failed to create directory '\(path)': \(error.localizedDescription)"
        case .insufficientPermissions(let path):
            return "Insufficient permissions for: \(path)"

        case .networkUnavailable:
            return "Network connection unavailable"
        case .connectionTimeout(let service):
            return "Connection timeout while accessing \(service)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"

        case .invalidConfiguration(let field, let reason):
            return "Invalid configuration for '\(field)': \(reason)"
        case .missingRequiredSetting(let setting):
            return "Required setting '\(setting)' is missing"
        case .configurationValidationFailed(let errors):
            return "Configuration validation failed: \(errors.joined(separator: ", "))"

        case .codeAnalysisFailed(let file, let reason):
            return "Code analysis failed for '\(file)': \(reason)"
        case .unsupportedLanguage(let language):
            return "Unsupported language: \(language)"
        case .parsingError(let details):
            return "Parsing error: \(details)"

        case .screenCapturePermissionDenied:
            return "Screen capture permission denied. Please enable in System Settings."
        case .screenCaptureFailed(let reason):
            return "Screen capture failed: \(reason)"
        case .imageProcessingFailed(let details):
            return "Image processing failed: \(details)"
        case .ocrFailed(let error):
            return "OCR failed: \(error.localizedDescription)"

        case .githubAuthenticationFailed:
            return "GitHub authentication failed. Please check your token."
        case .githubResourceNotFound(let resource):
            return "GitHub resource not found: \(resource)"
        case .githubAPIError(let code, let message):
            return "GitHub API error \(code): \(message)"

        case .serializationError(let type, let error):
            return "Failed to serialize \(type): \(error.localizedDescription)"
        case .deserializationError(let type, let error):
            return "Failed to deserialize \(type): \(error.localizedDescription)"
        case .invalidData(let context):
            return "Invalid data: \(context)"

        case .insufficientResources(let resource):
            return "Insufficient \(resource) available"
        case .componentInitializationFailed(let component, let error):
            if let error = error {
                return "Failed to initialize \(component): \(error.localizedDescription)"
            }
            return "Failed to initialize \(component)"
        case .unexpectedState(let description):
            return "Unexpected state: \(description)"
        }
    }

    /// Get recovery suggestions for the error
    var recoverySuggestion: String? {
        switch self {
        case .apiKeyMissing(let service):
            return "Configure your \(service) API key in the application settings."
        case .apiRateLimitExceeded:
            return "Wait a moment before making more requests, or upgrade your API plan."
        case .screenCapturePermissionDenied:
            return "Open System Settings > Privacy & Security > Screen Recording and enable access."
        case .networkUnavailable:
            return "Check your internet connection and try again."
        case .githubAuthenticationFailed:
            return "Verify your GitHub token has the required permissions."
        case .invalidConfiguration:
            return "Review and correct the configuration in settings."
        case .fileNotFound(let path):
            return "Ensure the file exists at: \(path)"
        case .insufficientPermissions:
            return "Grant the necessary permissions for the application."
        default:
            return nil
        }
    }

    /// Determine if the error is recoverable
    var isRecoverable: Bool {
        switch self {
        case .apiRateLimitExceeded, .connectionTimeout, .networkUnavailable:
            return true
        case .fileNotFound, .apiKeyMissing, .screenCapturePermissionDenied:
            return true
        default:
            return false
        }
    }

    /// Determine if the error should be retried automatically
    var shouldRetry: Bool {
        switch self {
        case .connectionTimeout, .networkUnavailable, .httpError(let code, _):
            return code >= 500 // Retry on server errors
        default:
            return false
        }
    }
}

// MARK: - AI Service Specific Errors

enum AIServiceError: Error, CustomStringConvertible {
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case quotaExceeded
    case modelUnavailable(model: String)
    case invalidPrompt(reason: String)
    case responseTooLarge
    case contextLengthExceeded(maxTokens: Int)

    var description: String {
        switch self {
        case .rateLimitExceeded(let retry):
            if let retry = retry {
                return "Rate limit exceeded. Retry after \(Int(retry))s"
            }
            return "Rate limit exceeded"
        case .quotaExceeded:
            return "API quota exceeded"
        case .modelUnavailable(let model):
            return "Model '\(model)' is unavailable"
        case .invalidPrompt(let reason):
            return "Invalid prompt: \(reason)"
        case .responseTooLarge:
            return "API response too large"
        case .contextLengthExceeded(let max):
            return "Context length exceeded (max: \(max) tokens)"
        }
    }
}

// MARK: - Error Recovery Manager

class ErrorRecoveryManager {
    static let shared = ErrorRecoveryManager()

    private var retryAttempts: [String: Int] = [:]
    private let maxRetries = 3
    private let queue = DispatchQueue(label: "com.backgroundai.error-recovery")

    /// Attempt to recover from an error
    func attemptRecovery(from error: AppError, context: String) async -> RecoveryResult {
        Logger.shared.error("Error occurred in \(context): \(error.description)", category: .errorHandling)

        guard error.isRecoverable else {
            return .failed(reason: "Error is not recoverable")
        }

        // Check retry count
        let retryCount = queue.sync {
            retryAttempts[context, default: 0]
        }

        guard retryCount < maxRetries else {
            queue.sync {
                retryAttempts.removeValue(forKey: context)
            }
            return .failed(reason: "Maximum retry attempts exceeded")
        }

        // Increment retry count
        queue.sync {
            retryAttempts[context, default: 0] += 1
        }

        // Calculate backoff delay
        let delay = calculateBackoffDelay(attemptNumber: retryCount)

        Logger.shared.info("Attempting recovery (attempt \(retryCount + 1)/\(maxRetries)) after \(delay)s", category: .errorHandling)

        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        // Reset retry count on success
        queue.sync {
            retryAttempts.removeValue(forKey: context)
        }

        return .recovered(attemptsTaken: retryCount + 1)
    }

    /// Calculate exponential backoff delay
    private func calculateBackoffDelay(attemptNumber: Int) -> TimeInterval {
        let baseDelay: TimeInterval = 2.0
        let maxDelay: TimeInterval = 60.0
        let delay = min(baseDelay * pow(2.0, Double(attemptNumber)), maxDelay)

        // Add jitter to prevent thundering herd
        let jitter = Double.random(in: 0...0.3) * delay
        return delay + jitter
    }

    /// Reset retry attempts for a context
    func resetRetries(for context: String) {
        queue.sync {
            retryAttempts.removeValue(forKey: context)
        }
    }
}

enum RecoveryResult {
    case recovered(attemptsTaken: Int)
    case failed(reason: String)

    var isSuccess: Bool {
        if case .recovered = self {
            return true
        }
        return false
    }
}

// MARK: - Error Reporter

class ErrorReporter {
    static let shared = ErrorReporter()

    private let errorLogPath: URL
    private let queue = DispatchQueue(label: "com.backgroundai.error-reporter")

    init() {
        errorLogPath = AppConfig.logsDir.appendingPathComponent("errors.log")
    }

    /// Report an error
    func report(_ error: AppError, context: String, additionalInfo: [String: Any]? = nil) {
        queue.async { [weak self] in
            self?.writeErrorLog(error: error, context: context, additionalInfo: additionalInfo)
        }

        // Log to console
        Logger.shared.error("[\(context)] \(error.description)", category: .errorHandling)

        // Show recovery suggestion if available
        if let suggestion = error.recoverySuggestion {
            Logger.shared.info("Recovery suggestion: \(suggestion)", category: .errorHandling)
        }
    }

    private func writeErrorLog(error: AppError, context: String, additionalInfo: [String: Any]?) {
        let timestamp = ISO8601DateFormatter().string(from: Date())

        var logEntry = """

        [\(timestamp)] ERROR in \(context)
        Description: \(error.description)
        """

        if let suggestion = error.recoverySuggestion {
            logEntry += "\nRecovery: \(suggestion)"
        }

        if let info = additionalInfo {
            logEntry += "\nAdditional Info: \(info)"
        }

        logEntry += "\nRecoverable: \(error.isRecoverable)"
        logEntry += "\nShould Retry: \(error.shouldRetry)"
        logEntry += "\n---"

        // Append to log file
        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: errorLogPath.path) {
                if let fileHandle = try? FileHandle(forWritingTo: errorLogPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: errorLogPath)
            }
        }
    }

    /// Get recent errors
    func getRecentErrors(limit: Int = 50) -> [String] {
        guard let content = try? String(contentsOf: errorLogPath, encoding: .utf8) else {
            return []
        }

        let errors = content.components(separatedBy: "---")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return Array(errors.suffix(limit))
    }
}
