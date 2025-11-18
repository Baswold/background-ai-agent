import Foundation
import CryptoKit

// MARK: - Advanced Security Scanner
// Comprehensive security vulnerability detection including OWASP Top 10

class AdvancedSecurityScanner {
    static let shared = AdvancedSecurityScanner()

    private let queue = DispatchQueue(label: "com.backgroundai.security", qos: .userInitiated)
    private var scanHistory: [SecurityScan] = []
    private var knownVulnerabilities: [KnownVulnerability] = []
    private var activityCallback: ((Activity) -> Void)?

    // Security patterns database
    private let sqlInjectionPatterns: [String]
    private let xssPatterns: [String]
    private let hardcodedSecretPatterns: [String]
    private let insecureDeserializationPatterns: [String]
    private let pathTraversalPatterns: [String]

    private init() {
        // SQL Injection patterns
        sqlInjectionPatterns = [
            "SELECT.*FROM.*WHERE.*=.*\\+",
            "execute\\(.*\\+.*\\)",
            "query\\(.*\\+.*\\)",
            "raw\\(.*\\+.*\\)",
            "\"\\'\\s*OR\\s*1\\s*=\\s*1"
        ]

        // XSS patterns
        xssPatterns = [
            "innerHTML\\s*=",
            "document\\.write\\(",
            "eval\\(",
            "dangerouslySetInnerHTML",
            "<script.*>.*</script>"
        ]

        // Hardcoded secrets
        hardcodedSecretPatterns = [
            "password\\s*=\\s*['\"][^'\"]+['\"]",
            "api[_-]?key\\s*=\\s*['\"][^'\"]+['\"]",
            "secret\\s*=\\s*['\"][^'\"]+['\"]",
            "token\\s*=\\s*['\"][^'\"]+['\"]",
            "AWS.*[A-Z0-9]{20}",
            "sk_live_[0-9a-zA-Z]{24}"
        ]

        // Insecure deserialization
        insecureDeserializationPatterns = [
            "pickle\\.loads?\\(",
            "yaml\\.load\\(",
            "NSKeyedUnarchiver\\.unarchiveObject",
            "ObjectInputStream\\.readObject"
        ]

        // Path traversal
        pathTraversalPatterns = [
            "\\.\\./",
            "file://",
            "\\\\\\.\\.\\\\",
            "os\\.path\\.join\\(.*,\\s*request\\."
        ]

        loadKnownVulnerabilities()
    }

    func start(onActivity: @escaping (Activity) -> Void) {
        activityCallback = onActivity
        print("🔒 Advanced Security Scanner initialized")
    }

    // MARK: - Comprehensive Security Scan

    func scanFile(path: String, content: String, language: String) async -> SecurityScanResult {
        var result = SecurityScanResult(filePath: path, language: language)

        print("🔍 Scanning \(path) for security vulnerabilities...")

        // OWASP Top 10 checks
        result.vulnerabilities.append(contentsOf: await detectInjectionFlaws(content, language))
        result.vulnerabilities.append(contentsOf: detectBrokenAuthentication(content, language))
        result.vulnerabilities.append(contentsOf: detectSensitiveDataExposure(content, language))
        result.vulnerabilities.append(contentsOf: detectXXE(content, language))
        result.vulnerabilities.append(contentsOf: detectBrokenAccessControl(content, language))
        result.vulnerabilities.append(contentsOf: detectSecurityMisconfiguration(content, language))
        result.vulnerabilities.append(contentsOf: detectXSS(content, language))
        result.vulnerabilities.append(contentsOf: detectInsecureDeserialization(content, language))
        result.vulnerabilities.append(contentsOf: detectComponentsWithKnownVulnerabilities(content, language))
        result.vulnerabilities.append(contentsOf: detectInsufficientLogging(content, language))

        // Additional security checks
        result.vulnerabilities.append(contentsOf: detectHardcodedSecrets(content, language))
        result.vulnerabilities.append(contentsOf: detectPathTraversal(content, language))
        result.vulnerabilities.append(contentsOf: detectCryptographicIssues(content, language))
        result.vulnerabilities.append(contentsOf: detectRaceConditions(content, language))
        result.vulnerabilities.append(contentsOf: detectMemorySafety(content, language))

        // Calculate security score
        result.securityScore = calculateSecurityScore(vulnerabilities: result.vulnerabilities)

        // Generate AI-powered insights
        if !result.vulnerabilities.isEmpty && !Settings.shared.claudeAPIKey.isEmpty {
            result.aiInsights = await generateAISecurityInsights(result)
        }

        // Save scan result
        scanHistory.append(SecurityScan(
            timestamp: Date(),
            filePath: path,
            result: result
        ))

        // Report critical vulnerabilities immediately
        reportCriticalVulnerabilities(result)

        return result
    }

    // MARK: - OWASP Top 10 Detection

    private func detectInjectionFlaws(_ content: String, _ language: String) async -> [SecurityVulnerability] {
        var vulnerabilities: [SecurityVulnerability] = []

        // SQL Injection
        for pattern in sqlInjectionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))

                if !matches.isEmpty {
                    vulnerabilities.append(SecurityVulnerability(
                        type: .sqlInjection,
                        severity: .critical,
                        title: "SQL Injection Vulnerability",
                        description: "Potential SQL injection detected. Use parameterized queries instead of string concatenation.",
                        location: findLineNumber(in: content, for: matches.first!),
                        cwe: "CWE-89",
                        owasp: "A1:2021 – Injection",
                        remediation: "Use prepared statements with parameterized queries. For example: db.query('SELECT * FROM users WHERE id = ?', [userId])"
                    ))
                }
            }
        }

        // NoSQL Injection
        if language == "javascript" || language == "typescript" {
            let noSqlPatterns = ["\\$where.*:", "\\$ne.*:", "\\{\\s*\\$gt\\s*:"]
            for pattern in noSqlPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) != nil {
                    vulnerabilities.append(SecurityVulnerability(
                        type: .nosqlInjection,
                        severity: .high,
                        title: "NoSQL Injection Vulnerability",
                        description: "Potential NoSQL injection detected with operator injection",
                        location: 0,
                        cwe: "CWE-943",
                        owasp: "A1:2021 – Injection",
                        remediation: "Validate and sanitize user input before using in MongoDB queries"
                    ))
                }
            }
        }

        // Command Injection
        let commandInjectionPatterns = ["exec\\(", "system\\(", "popen\\(", "shell_exec\\("]
        for pattern in commandInjectionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               !regex.matches(in: content, range: NSRange(content.startIndex..., in: content)).isEmpty {
                vulnerabilities.append(SecurityVulnerability(
                    type: .commandInjection,
                    severity: .critical,
                    title: "Command Injection Vulnerability",
                    description: "Executing shell commands with user input can lead to remote code execution",
                    location: 0,
                    cwe: "CWE-78",
                    owasp: "A1:2021 – Injection",
                    remediation: "Avoid executing shell commands. If necessary, use allowlists and proper input validation"
                ))
            }
        }

        return vulnerabilities
    }

    private func detectBrokenAuthentication(_ content: String, _ language: String) -> [SecurityVulnerability] {
        var vulnerabilities: [SecurityVulnerability] = []

        // Weak password requirements
        if content.contains("password") && !content.contains("length") && !content.contains("complexity") {
            vulnerabilities.append(SecurityVulnerability(
                type: .weakPassword,
                severity: .high,
                title: "Weak Password Policy",
                description: "Password validation appears insufficient. Enforce strong password requirements.",
                location: 0,
                cwe: "CWE-521",
                owasp: "A2:2021 – Broken Authentication",
                remediation: "Implement password complexity requirements (length, special chars, numbers)"
            ))
        }

        // Session fixation
        if (content.contains("session") || content.contains("sessionId")) && !content.contains("regenerate") {
            vulnerabilities.append(SecurityVulnerability(
                type: .sessionFixation,
                severity: .high,
                title: "Session Fixation Vulnerability",
                description: "Session ID should be regenerated after authentication",
                location: 0,
                cwe: "CWE-384",
                owasp: "A2:2021 – Broken Authentication",
                remediation: "Regenerate session ID after successful login"
            ))
        }

        // Missing rate limiting
        if (content.contains("login") || content.contains("authenticate")) && !content.contains("rateLimit") {
            vulnerabilities.append(SecurityVulnerability(
                type: .missingRateLimit,
                severity: .medium,
                title: "Missing Rate Limiting",
                description: "Authentication endpoints should have rate limiting to prevent brute force attacks",
                location: 0,
                cwe: "CWE-307",
                owasp: "A2:2021 – Broken Authentication",
                remediation: "Implement rate limiting on authentication endpoints"
            ))
        }

        return vulnerabilities
    }

    private func detectSensitiveDataExposure(_ content: String, _ language: String) -> [SecurityVulnerability] {
        var vulnerabilities: [SecurityVulnerability] = []

        // Hardcoded credentials
        for pattern in hardcodedSecretPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               !regex.matches(in: content, range: NSRange(content.startIndex..., in: content)).isEmpty {
                vulnerabilities.append(SecurityVulnerability(
                    type: .hardcodedCredentials,
                    severity: .critical,
                    title: "Hardcoded Credentials Detected",
                    description: "Credentials or API keys hardcoded in source code. Use environment variables or secure vaults.",
                    location: 0,
                    cwe: "CWE-798",
                    owasp: "A3:2021 – Sensitive Data Exposure",
                    remediation: "Move secrets to environment variables or use a secrets management service"
                ))
            }
        }

        // Logging sensitive data
        if content.contains("log") || content.contains("print") {
            let sensitiveTerms = ["password", "token", "secret", "credit_card", "ssn"]
            for term in sensitiveTerms {
                if content.lowercased().contains("log") && content.lowercased().contains(term) {
                    vulnerabilities.append(SecurityVulnerability(
                        type: .sensitiveDataInLogs,
                        severity: .high,
                        title: "Sensitive Data in Logs",
                        description: "Logging sensitive information like passwords or tokens",
                        location: 0,
                        cwe: "CWE-532",
                        owasp: "A3:2021 – Sensitive Data Exposure",
                        remediation: "Remove or redact sensitive data from logs"
                    ))
                    break
                }
            }
        }

        // Insecure transmission
        if content.contains("http://") && !content.contains("localhost") {
            vulnerabilities.append(SecurityVulnerability(
                type: .insecureTransport,
                severity: .high,
                title: "Insecure HTTP Communication",
                description: "Using HTTP instead of HTTPS for sensitive data transmission",
                location: 0,
                cwe: "CWE-319",
                owasp: "A3:2021 – Sensitive Data Exposure",
                remediation: "Use HTTPS for all network communications"
            ))
        }

        return vulnerabilities
    }

    private func detectXXE(_ content: String, _ language: String) -> [SecurityVulnerability] {
        var vulnerabilities: [SecurityVulnerability] = []

        // XML External Entity
        if content.contains("XML") || content.contains("xml") {
            let xxePatterns = [
                "XMLParser",
                "DocumentBuilderFactory",
                "SAXParser",
                "<!ENTITY"
            ]

            for pattern in xxePatterns {
                if content.contains(pattern) && !content.contains("setFeature") {
                    vulnerabilities.append(SecurityVulnerability(
                        type: .xxe,
                        severity: .high,
                        title: "XML External Entity (XXE) Vulnerability",
                        description: "XML parser may be vulnerable to XXE attacks. Disable external entity processing.",
                        location: 0,
                        cwe: "CWE-611",
                        owasp: "A4:2021 – XXE",
                        remediation: "Disable DTD processing and external entity resolution in XML parsers"
                    ))
                    break
                }
            }
        }

        return vulnerabilities
    }

    private func detectBrokenAccessControl(_ content: String, _ language: String) -> [SecurityVulnerability] {
        var vulnerabilities: [SecurityVulnerability] = []

        // Missing authorization checks
        if content.contains("func") || content.contains("def") {
            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                if (line.contains("delete") || line.contains("update") || line.contains("admin")) &&
                   index > 0 &&
                   !lines[max(0, index-3)...index].joined().contains("authorize") &&
                   !lines[max(0, index-3)...index].joined().contains("isAdmin") {
                    vulnerabilities.append(SecurityVulnerability(
                        type: .missingAccessControl,
                        severity: .critical,
                        title: "Missing Authorization Check",
                        description: "Sensitive operation lacks authorization check",
                        location: index + 1,
                        cwe: "CWE-862",
                        owasp: "A5:2021 – Broken Access Control",
                        remediation: "Add authorization checks before sensitive operations"
                    ))
                }
            }
        }

        // CORS misconfiguration
        if content.contains("Access-Control-Allow-Origin") && content.contains("*") {
            vulnerabilities.append(SecurityVulnerability(
                type: .corsMisconfiguration,
                severity: .medium,
                title: "Overly Permissive CORS Policy",
                description: "CORS allows all origins (*). This can expose sensitive data.",
                location: 0,
                cwe: "CWE-942",
                owasp: "A5:2021 – Broken Access Control",
                remediation: "Specify allowed origins explicitly instead of using wildcard"
            ))
        }

        return vulnerabilities
    }

    private func detectSecurityMisconfiguration(_ content: String, _ language: String) -> [SecurityVulnerability] {
        var vulnerabilities: [SecurityVulnerability] = []

        // Debug mode in production
        if content.contains("DEBUG") && content.contains("true") {
            vulnerabilities.append(SecurityVulnerability(
                type: .debugModeEnabled,
                severity: .medium,
                title: "Debug Mode Enabled",
                description: "Debug mode may expose sensitive information in production",
                location: 0,
                cwe: "CWE-489",
                owasp: "A6:2021 – Security Misconfiguration",
                remediation: "Disable debug mode in production environments"
            ))
        }

        // Default credentials
        if content.contains("admin") && content.contains("admin") ||
           content.contains("root") && content.contains("root") {
            vulnerabilities.append(SecurityVulnerability(
                type: .defaultCredentials,
                severity: .critical,
                title: "Default Credentials",
                description: "Using default or common credentials",
                location: 0,
                cwe: "CWE-798",
                owasp: "A6:2021 – Security Misconfiguration",
                remediation: "Change default credentials to strong, unique values"
            ))
        }

        return vulnerabilities
    }

    private func detectXSS(_ content: String, _ language: String) -> [SecurityVulnerability] {
        var vulnerabilities: [SecurityVulnerability] = []

        for pattern in xssPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               !regex.matches(in: content, range: NSRange(content.startIndex..., in: content)).isEmpty {
                vulnerabilities.append(SecurityVulnerability(
                    type: .xss,
                    severity: .high,
                    title: "Cross-Site Scripting (XSS) Vulnerability",
                    description: "Potential XSS vulnerability detected. Sanitize user input before rendering.",
                    location: 0,
                    cwe: "CWE-79",
                    owasp: "A7:2021 – XSS",
                    remediation: "Use proper encoding/escaping for user-controlled data in HTML context"
                ))
                break
            }
        }

        return vulnerabilities
    }

    private func detectInsecureDeserialization(_ content: String, _ language: String) -> [SecurityVulnerability] {
        var vulnerabilities: [SecurityVulnerability] = []

        for pattern in insecureDeserializationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               !regex.matches(in: content, range: NSRange(content.startIndex..., in: content)).isEmpty {
                vulnerabilities.append(SecurityVulnerability(
                    type: .insecureDeserialization,
                    severity: .critical,
                    title: "Insecure Deserialization",
                    description: "Deserializing untrusted data can lead to remote code execution",
                    location: 0,
                    cwe: "CWE-502",
                    owasp: "A8:2021 – Insecure Deserialization",
                    remediation: "Avoid deserializing untrusted data. Use safer formats like JSON."
                ))
                break
            }
        }

        return vulnerabilities
    }

    private func detectComponentsWithKnownVulnerabilities(_ content: String, _ language: String) -> [SecurityVulnerability] {
        var vulnerabilities: [SecurityVulnerability] = []

        // Check for outdated dependencies (simplified)
        let oldVersionPatterns = [
            "jquery.*1\\.",
            "react.*15\\.",
            "angular.*1\\.",
            "lodash.*3\\."
        ]

        for pattern in oldVersionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) != nil {
                vulnerabilities.append(SecurityVulnerability(
                    type: .vulnerableDependency,
                    severity: .high,
                    title: "Outdated Dependency",
                    description: "Using outdated library version with known vulnerabilities",
                    location: 0,
                    cwe: "CWE-1104",
                    owasp: "A9:2021 – Vulnerable Components",
                    remediation: "Update to the latest stable version"
                ))
            }
        }

        return vulnerabilities
    }

    private func detectInsufficientLogging(_ content: String, _ language: String) -> [SecurityVulnerability] {
        var vulnerabilities: [SecurityVulnerability] = []

        // Check authentication/authorization functions for logging
        let lines = content.components(separatedBy: .newlines)
        var hasAuthFunction = false
        var hasLogging = false

        for line in lines {
            if line.contains("authenticate") || line.contains("authorize") {
                hasAuthFunction = true
            }
            if line.contains("log") || line.contains("logger") {
                hasLogging = true
            }
        }

        if hasAuthFunction && !hasLogging {
            vulnerabilities.append(SecurityVulnerability(
                type: .insufficientLogging,
                severity: .medium,
                title: "Insufficient Logging",
                description: "Security-critical operations lack audit logging",
                location: 0,
                cwe: "CWE-778",
                owasp: "A10:2021 – Insufficient Logging",
                remediation: "Add logging for authentication, authorization, and security events"
            ))
        }

        return vulnerabilities
    }

    // MARK: - Additional Security Checks

    private func detectHardcodedSecrets(_ content: String, _ language: String) -> [SecurityVulnerability] {
        var vulnerabilities: [SecurityVulnerability] = []

        // API keys, tokens, passwords in code
        for pattern in hardcodedSecretPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
                if !matches.isEmpty {
                    vulnerabilities.append(SecurityVulnerability(
                        type: .hardcodedCredentials,
                        severity: .critical,
                        title: "Hardcoded Secret Detected",
                        description: "Secret credentials found in source code",
                        location: 0,
                        cwe: "CWE-798",
                        owasp: "A3:2021 – Sensitive Data Exposure",
                        remediation: "Use environment variables or secure secret management"
                    ))
                }
            }
        }

        return vulnerabilities
    }

    private func detectPathTraversal(_ content: String, _ language: String) -> [SecurityVulnerability] {
        var vulnerabilities: [SecurityVulnerability] = []

        for pattern in pathTraversalPatterns {
            if content.contains(pattern) {
                vulnerabilities.append(SecurityVulnerability(
                    type: .pathTraversal,
                    severity: .high,
                    title: "Path Traversal Vulnerability",
                    description: "Potential path traversal attack vector detected",
                    location: 0,
                    cwe: "CWE-22",
                    owasp: "A1:2021 – Injection",
                    remediation: "Validate and sanitize file paths, use allowlists"
                ))
                break
            }
        }

        return vulnerabilities
    }

    private func detectCryptographicIssues(_ content: String, _ language: String) -> [SecurityVulnerability] {
        var vulnerabilities: [SecurityVulnerability] = []

        // Weak algorithms
        let weakAlgorithms = ["MD5", "SHA1", "DES", "RC4"]
        for algo in weakAlgorithms {
            if content.contains(algo) {
                vulnerabilities.append(SecurityVulnerability(
                    type: .weakCryptography,
                    severity: .high,
                    title: "Weak Cryptographic Algorithm",
                    description: "\(algo) is cryptographically weak and should not be used",
                    location: 0,
                    cwe: "CWE-327",
                    owasp: "A3:2021 – Sensitive Data Exposure",
                    remediation: "Use strong algorithms like SHA-256, AES-256"
                ))
            }
        }

        // Insecure random
        if content.contains("rand()") || content.contains("random()") && !content.contains("crypto") {
            vulnerabilities.append(SecurityVulnerability(
                type: .weakRandom,
                severity: .medium,
                title: "Weak Random Number Generator",
                description: "Using non-cryptographic random number generator for security purposes",
                location: 0,
                cwe: "CWE-338",
                owasp: "A3:2021 – Sensitive Data Exposure",
                remediation: "Use cryptographically secure random number generator"
            ))
        }

        return vulnerabilities
    }

    private func detectRaceConditions(_ content: String, _ language: String) -> [SecurityVulnerability] {
        var vulnerabilities: [SecurityVulnerability] = []

        // TOCTOU (Time-of-check Time-of-use)
        if content.contains("fileExists") && content.contains("open") {
            vulnerabilities.append(SecurityVulnerability(
                type: .raceCondition,
                severity: .medium,
                title: "Potential Race Condition (TOCTOU)",
                description: "Time-of-check time-of-use vulnerability in file operations",
                location: 0,
                cwe: "CWE-367",
                owasp: "A6:2021 – Security Misconfiguration",
                remediation: "Use atomic operations or proper locking mechanisms"
            ))
        }

        return vulnerabilities
    }

    private func detectMemorySafety(_ content: String, _ language: String) -> [SecurityVulnerability] {
        var vulnerabilities: [SecurityVulnerability] = []

        // Buffer overflow (C/C++)
        if language == "c" || language == "cpp" {
            let unsafeFunctions = ["strcpy", "strcat", "sprintf", "gets"]
            for function in unsafeFunctions {
                if content.contains(function) {
                    vulnerabilities.append(SecurityVulnerability(
                        type: .bufferOverflow,
                        severity: .critical,
                        title: "Unsafe Memory Function",
                        description: "\(function) can cause buffer overflows",
                        location: 0,
                        cwe: "CWE-120",
                        owasp: "A6:2021 – Security Misconfiguration",
                        remediation: "Use safe alternatives like strncpy, strncat, snprintf"
                    ))
                }
            }
        }

        return vulnerabilities
    }

    // MARK: - AI-Powered Analysis

    private func generateAISecurityInsights(_ result: SecurityScanResult) async -> String {
        do {
            let summary = result.vulnerabilities.prefix(5).map { $0.title }.joined(separator: ", ")

            let insights = try await AIService.shared.callClaude(
                prompt: """
                Analyze these security vulnerabilities and provide concise remediation advice:

                Vulnerabilities found:
                \(summary)

                Provide 2-3 specific, actionable security recommendations (max 3 sentences total):
                """,
                maxTokens: 200
            )

            return insights
        } catch {
            return "Unable to generate AI insights"
        }
    }

    // MARK: - Scoring & Reporting

    private func calculateSecurityScore(vulnerabilities: [SecurityVulnerability]) -> Double {
        var score = 100.0

        for vuln in vulnerabilities {
            switch vuln.severity {
            case .critical: score -= 20.0
            case .high: score -= 10.0
            case .medium: score -= 5.0
            case .low: score -= 2.0
            }
        }

        return max(0, score)
    }

    private func reportCriticalVulnerabilities(_ result: SecurityScanResult) {
        let critical = result.vulnerabilities.filter { $0.severity == .critical }

        for vuln in critical {
            let activity = Activity(
                title: "🚨 Critical Security Issue",
                description: "\(vuln.title): \(vuln.description)",
                type: .vsCodeFix
            )

            DispatchQueue.main.async { [weak self] in
                self?.activityCallback?(activity)
            }
        }
    }

    // MARK: - Utilities

    private func findLineNumber(in content: String, for match: NSTextCheckingResult) -> Int {
        let lines = content.components(separatedBy: .newlines)
        var currentLength = 0

        for (index, line) in lines.enumerated() {
            currentLength += line.count + 1 // +1 for newline
            if currentLength > match.range.location {
                return index + 1
            }
        }

        return 0
    }

    private func loadKnownVulnerabilities() {
        // Load CVE database or known vulnerability patterns
        print("📚 Loading known vulnerability database...")
    }

    // MARK: - Public API

    func getScanHistory() -> [SecurityScan] {
        return scanHistory.sorted { $0.timestamp > $1.timestamp }
    }

    func generateSecurityReport() -> String {
        let recentScans = scanHistory.suffix(10)
        let totalVulns = recentScans.flatMap { $0.result.vulnerabilities }.count
        let critical = recentScans.flatMap { $0.result.vulnerabilities }.filter { $0.severity == .critical }.count

        return """
        # Security Scan Report

        **Total Files Scanned:** \(recentScans.count)
        **Total Vulnerabilities:** \(totalVulns)
        **Critical:** \(critical)

        ## Recent Scans
        \(recentScans.map { scan in
            "- \(scan.filePath): \(scan.result.vulnerabilities.count) issues (Score: \(Int(scan.result.securityScore)))"
        }.joined(separator: "\n"))

        ---
        *Generated by Advanced Security Scanner*
        """
    }
}

// MARK: - Data Models

struct SecurityScanResult {
    let filePath: String
    let language: String
    var vulnerabilities: [SecurityVulnerability] = []
    var securityScore: Double = 100.0
    var aiInsights: String?
    let timestamp = Date()
}

struct SecurityVulnerability {
    let id = UUID()
    let type: VulnerabilityType
    let severity: VulnerabilitySeverity
    let title: String
    let description: String
    let location: Int
    let cwe: String
    let owasp: String
    let remediation: String
}

enum VulnerabilityType {
    case sqlInjection
    case nosqlInjection
    case commandInjection
    case xss
    case xxe
    case csrf
    case insecureDeserialization
    case hardcodedCredentials
    case sensitiveDataInLogs
    case insecureTransport
    case weakCryptography
    case weakRandom
    case weakPassword
    case sessionFixation
    case missingAccessControl
    case corsMisconfiguration
    case debugModeEnabled
    case defaultCredentials
    case pathTraversal
    case bufferOverflow
    case raceCondition
    case insufficientLogging
    case missingRateLimit
    case vulnerableDependency
}

enum VulnerabilitySeverity {
    case critical
    case high
    case medium
    case low
}

struct SecurityScan {
    let timestamp: Date
    let filePath: String
    let result: SecurityScanResult
}

struct KnownVulnerability {
    let cve: String
    let description: String
    let severity: VulnerabilitySeverity
    let affectedVersions: [String]
}
