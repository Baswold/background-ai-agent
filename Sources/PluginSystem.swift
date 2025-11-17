import Foundation

// MARK: - Plugin System for Extensibility

/// Extensible plugin system for adding custom functionality
class PluginManager {
    static let shared = PluginManager()

    private var registeredPlugins: [String: Plugin] = [:]
    private var enabledPlugins: Set<String> = []
    private let queue = DispatchQueue(label: "com.backgroundai.plugins")

    private init() {
        Logger.shared.info("Plugin system initialized", category: .system)
        loadBuiltInPlugins()
    }

    // MARK: - Plugin Management

    func registerPlugin(_ plugin: Plugin) {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.registeredPlugins[plugin.identifier] = plugin

            Logger.shared.info("Plugin registered: \(plugin.name) v\(plugin.version)", category: .system)

            // Auto-enable if configured
            if plugin.autoEnable {
                self.enabledPlugins.insert(plugin.identifier)
            }
        }
    }

    func enablePlugin(_ identifier: String) -> Bool {
        return queue.sync {
            guard let plugin = registeredPlugins[identifier] else {
                Logger.shared.warning("Plugin not found: \(identifier)", category: .system)
                return false
            }

            do {
                try plugin.onEnable()
                enabledPlugins.insert(identifier)

                Logger.shared.info("Plugin enabled: \(plugin.name)", category: .system)

                return true
            } catch {
                Logger.shared.error("Failed to enable plugin \(plugin.name): \(error)", category: .errorHandling)
                return false
            }
        }
    }

    func disablePlugin(_ identifier: String) -> Bool {
        return queue.sync {
            guard let plugin = registeredPlugins[identifier] else {
                return false
            }

            do {
                try plugin.onDisable()
                enabledPlugins.remove(identifier)

                Logger.shared.info("Plugin disabled: \(plugin.name)", category: .system)

                return true
            } catch {
                Logger.shared.error("Failed to disable plugin \(plugin.name): \(error)", category: .errorHandling)
                return false
            }
        }
    }

    func getPlugin(_ identifier: String) -> Plugin? {
        return queue.sync {
            return registeredPlugins[identifier]
        }
    }

    func getAllPlugins() -> [Plugin] {
        return queue.sync {
            return Array(registeredPlugins.values)
        }
    }

    func getEnabledPlugins() -> [Plugin] {
        return queue.sync {
            return enabledPlugins.compactMap { registeredPlugins[$0] }
        }
    }

    // MARK: - Event Broadcasting

    func broadcastEvent(_ event: PluginEvent) {
        let enabled = getEnabledPlugins()

        for plugin in enabled {
            Task {
                await plugin.handleEvent(event)
            }
        }
    }

    // MARK: - Built-in Plugins

    private func loadBuiltInPlugins() {
        // Register built-in plugins
        registerPlugin(SmartNotificationsPlugin())
        registerPlugin(AutomationPlugin())
        registerPlugin(WorkflowOptimizerPlugin())
        registerPlugin(CodeSuggestionPlugin())
        registerPlugin(SecurityAuditPlugin())

        Logger.shared.info("Built-in plugins loaded", category: .system)
    }
}

// MARK: - Plugin Protocol

protocol Plugin: AnyObject {
    var identifier: String { get }
    var name: String { get }
    var version: String { get }
    var description: String { get }
    var author: String { get }
    var autoEnable: Bool { get }

    func onEnable() throws
    func onDisable() throws
    func handleEvent(_ event: PluginEvent) async
}

// MARK: - Plugin Events

enum PluginEvent {
    case codeAnalyzed(file: String, language: String, issues: [CodeAnalysis.Issue])
    case screenshotCaptured(appName: String)
    case errorDetected(error: AppError, context: String)
    case apiCallMade(service: String, success: Bool)
    case clipboardChanged(content: String, type: ClipboardType)
    case appSwitched(from: String?, to: String)
    case deepWorkDetected(duration: TimeInterval)
    case rateLimitWarning(service: String, percentageUsed: Double)
    case healthCheckFailed(component: String, issues: [String])
}

// MARK: - Base Plugin Class

class BasePlugin: Plugin {
    let identifier: String
    let name: String
    let version: String
    let description: String
    let author: String
    let autoEnable: Bool

    init(identifier: String, name: String, version: String, description: String, author: String, autoEnable: Bool = false) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.description = description
        self.author = author
        self.autoEnable = autoEnable
    }

    func onEnable() throws {
        Logger.shared.info("Plugin \(name) enabled", category: .system)
    }

    func onDisable() throws {
        Logger.shared.info("Plugin \(name) disabled", category: .system)
    }

    func handleEvent(_ event: PluginEvent) async {
        // Override in subclasses
    }
}

// MARK: - Built-in Plugins

// 1. Smart Notifications Plugin
class SmartNotificationsPlugin: BasePlugin {
    private var notificationQueue: [SmartNotification] = []
    private var suppressedApps: Set<String> = []

    init() {
        super.init(
            identifier: "com.backgroundai.smartnotifications",
            name: "Smart Notifications",
            version: "1.0.0",
            description: "Intelligent notification management with priority and context awareness",
            author: "Background AI Team",
            autoEnable: true
        )
    }

    override func handleEvent(_ event: PluginEvent) async {
        switch event {
        case .codeAnalyzed(let file, _, let issues):
            let criticalIssues = issues.filter { $0.severity == "high" || $0.severity == "critical" }
            if !criticalIssues.isEmpty {
                await sendSmartNotification(
                    title: "⚠️ Critical Issues Found",
                    body: "\(criticalIssues.count) critical issues in \(file)",
                    priority: .high,
                    category: .security
                )
            }

        case .deepWorkDetected(let duration):
            if duration > 30 * 60 { // 30 minutes
                await sendSmartNotification(
                    title: "🎯 Deep Work Session",
                    body: "You've been focused for \(Int(duration/60)) minutes. Great job!",
                    priority: .low,
                    category: .productivity
                )
            }

        case .rateLimitWarning(let service, let percentage):
            if percentage > 90 {
                await sendSmartNotification(
                    title: "⚠️ Rate Limit Warning",
                    body: "\(service) is at \(String(format: "%.0f", percentage))% of quota",
                    priority: .high,
                    category: .system
                )
            }

        case .healthCheckFailed(let component, let issues):
            await sendSmartNotification(
                title: "🔥 Health Check Failed",
                body: "\(component): \(issues.joined(separator: ", "))",
                priority: .critical,
                category: .system
            )

        default:
            break
        }
    }

    private func sendSmartNotification(title: String, body: String, priority: NotificationPriority, category: NotificationCategory) async {
        let notification = SmartNotification(
            title: title,
            body: body,
            priority: priority,
            category: category,
            timestamp: Date()
        )

        // Intelligent suppression
        if shouldSuppressNotification(notification) {
            Logger.shared.debug("Notification suppressed: \(title)", category: .general)
            return
        }

        notificationQueue.append(notification)

        // Send notification
        Logger.shared.info("Smart notification: \(title)", category: .general)

        // Track analytics
        AnalyticsManager.shared.trackEvent(AnalyticsEvent(
            name: "smart_notification",
            category: .ui,
            properties: [
                "priority": priority.rawValue,
                "category": category.rawValue
            ]
        ))
    }

    private func shouldSuppressNotification(_ notification: SmartNotification) -> Bool {
        // Suppress low priority notifications during deep work
        if notification.priority == .low {
            // Would check if user is in deep work session
            return false
        }

        // Suppress duplicate notifications within 5 minutes
        let recent = notificationQueue.suffix(10)
        let duplicates = recent.filter { $0.title == notification.title }
        if let last = duplicates.last {
            let timeSince = Date().timeIntervalSince(last.timestamp)
            if timeSince < 300 { // 5 minutes
                return true
            }
        }

        return false
    }
}

struct SmartNotification {
    let title: String
    let body: String
    let priority: NotificationPriority
    let category: NotificationCategory
    let timestamp: Date
}

enum NotificationPriority: String {
    case low, normal, high, critical
}

enum NotificationCategory: String {
    case system, security, productivity, ai, general
}

// 2. Automation Plugin
class AutomationPlugin: BasePlugin {
    private var automationRules: [AutomationRule] = []

    init() {
        super.init(
            identifier: "com.backgroundai.automation",
            name: "Automation Engine",
            version: "1.0.0",
            description: "Rule-based automation for common tasks",
            author: "Background AI Team",
            autoEnable: true
        )

        setupDefaultRules()
    }

    private func setupDefaultRules() {
        // Auto-fix simple code issues
        automationRules.append(AutomationRule(
            name: "Auto-fix simple issues",
            trigger: .codeIssueDetected(severity: ["low", "medium"]),
            action: .autoFixCode
        ))

        // Create backup before critical operations
        automationRules.append(AutomationRule(
            name: "Auto-backup on critical error",
            trigger: .errorOccurred(severity: "critical"),
            action: .createBackup
        ))

        // Optimize images
        automationRules.append(AutomationRule(
            name: "Optimize screenshots",
            trigger: .screenshotCaptured,
            action: .optimizeImage
        ))
    }

    override func handleEvent(_ event: PluginEvent) async {
        for rule in automationRules where rule.isEnabled {
            if rule.matches(event) {
                await executeRule(rule, for: event)
            }
        }
    }

    private func executeRule(_ rule: AutomationRule, for event: PluginEvent) async {
        Logger.shared.info("Executing automation rule: \(rule.name)", category: .general)

        switch rule.action {
        case .autoFixCode:
            // Would implement auto-fix logic
            Logger.shared.info("Auto-fixing code issues", category: .general)

        case .createBackup:
            do {
                _ = try ConfigurationManager.shared.backupSettings()
                Logger.shared.info("Automatic backup created", category: .configuration)
            } catch {
                Logger.shared.error("Auto-backup failed: \(error)", category: .errorHandling)
            }

        case .optimizeImage:
            Logger.shared.info("Optimizing image", category: .general)

        case .sendNotification(let title, let body):
            Logger.shared.info("Automation notification: \(title)", category: .general)

        case .runScript(let path):
            Logger.shared.info("Running script: \(path)", category: .general)
        }

        // Track automation
        AnalyticsManager.shared.trackEvent(AnalyticsEvent(
            name: "automation_executed",
            category: .ui,
            properties: ["rule": rule.name]
        ))
    }
}

struct AutomationRule {
    let name: String
    let trigger: AutomationTrigger
    let action: AutomationAction
    var isEnabled: Bool = true

    func matches(_ event: PluginEvent) -> Bool {
        switch (trigger, event) {
        case (.codeIssueDetected, .codeAnalyzed):
            return true
        case (.errorOccurred, .errorDetected):
            return true
        case (.screenshotCaptured, .screenshotCaptured):
            return true
        default:
            return false
        }
    }
}

enum AutomationTrigger {
    case codeIssueDetected(severity: [String])
    case errorOccurred(severity: String)
    case screenshotCaptured
    case appSwitched(to: String)
    case timeOfDay(hour: Int)
    case custom((PluginEvent) -> Bool)
}

enum AutomationAction {
    case autoFixCode
    case createBackup
    case optimizeImage
    case sendNotification(title: String, body: String)
    case runScript(path: String)
}

// 3. Workflow Optimizer Plugin
class WorkflowOptimizerPlugin: BasePlugin {
    private var workflowPatterns: [WorkflowPattern] = []

    init() {
        super.init(
            identifier: "com.backgroundai.workflow",
            name: "Workflow Optimizer",
            version: "1.0.0",
            description: "Learn and suggest workflow improvements",
            author: "Background AI Team",
            autoEnable: true
        )
    }

    override func handleEvent(_ event: PluginEvent) async {
        // Learn from user patterns
        switch event {
        case .appSwitched(let from, let to):
            await recordAppSwitch(from: from, to: to)
        case .codeAnalyzed(let file, let language, _):
            await recordCodePattern(file: file, language: language)
        default:
            break
        }
    }

    private func recordAppSwitch(from: String?, to: String) async {
        // Would analyze app switching patterns
        Logger.shared.verbose("Workflow pattern: \(from ?? "unknown") -> \(to)", category: .productivity)
    }

    private func recordCodePattern(file: String, language: String) async {
        // Would learn coding patterns
        Logger.shared.verbose("Code pattern: \(language) file edited", category: .productivity)
    }
}

// 4. Code Suggestion Plugin
class CodeSuggestionPlugin: BasePlugin {
    init() {
        super.init(
            identifier: "com.backgroundai.codesuggestion",
            name: "Code Suggestions",
            version: "1.0.0",
            description: "AI-powered code suggestions and improvements",
            author: "Background AI Team",
            autoEnable: false
        )
    }

    override func handleEvent(_ event: PluginEvent) async {
        if case .codeAnalyzed(let file, let language, let issues) = event {
            await suggestImprovements(file: file, language: language, issues: issues)
        }
    }

    private func suggestImprovements(file: String, language: String, issues: [CodeAnalysis.Issue]) async {
        // Would use AI to suggest code improvements
        Logger.shared.info("Generating code suggestions for \(file)", category: .ai)
    }
}

// 5. Security Audit Plugin
class SecurityAuditPlugin: BasePlugin {
    private var securityFindings: [SecurityFinding] = []

    init() {
        super.init(
            identifier: "com.backgroundai.security",
            name: "Security Auditor",
            version: "1.0.0",
            description: "Continuous security monitoring and auditing",
            author: "Background AI Team",
            autoEnable: true
        )
    }

    override func handleEvent(_ event: PluginEvent) async {
        switch event {
        case .codeAnalyzed(let file, _, let issues):
            let securityIssues = issues.filter { $0.type == "security" }
            for issue in securityIssues {
                await recordSecurityFinding(file: file, issue: issue)
            }

        case .clipboardChanged(let content, _):
            await scanForSecrets(content)

        default:
            break
        }
    }

    private func recordSecurityFinding(file: String, issue: CodeAnalysis.Issue) async {
        let finding = SecurityFinding(
            file: file,
            type: issue.type,
            description: issue.description,
            severity: issue.severity,
            timestamp: Date()
        )

        securityFindings.append(finding)

        Logger.shared.warning("Security finding: \(issue.description) in \(file)", category: .security)

        // Alert on critical security issues
        if issue.severity == "high" || issue.severity == "critical" {
            PluginManager.shared.broadcastEvent(.errorDetected(
                error: AppError.codeAnalysisFailed(file: file, reason: issue.description),
                context: "Security Audit"
            ))
        }
    }

    private func scanForSecrets(_ content: String) async {
        // Scan clipboard for potential secrets
        let patterns = [
            "api[_-]?key",
            "secret",
            "password",
            "token",
            "credential"
        ]

        for pattern in patterns {
            if content.lowercased().contains(pattern) {
                Logger.shared.warning("Potential secret detected in clipboard", category: .security)

                AnalyticsManager.shared.trackEvent(AnalyticsEvent(
                    name: "security_alert",
                    category: .error,
                    properties: ["type": "clipboard_secret"]
                ))

                break
            }
        }
    }

    func getSecurityReport() -> SecurityReport {
        let highSeverity = securityFindings.filter { $0.severity == "high" || $0.severity == "critical" }

        return SecurityReport(
            totalFindings: securityFindings.count,
            highSeverityCount: highSeverity.count,
            findings: securityFindings,
            generatedAt: Date()
        )
    }
}

struct SecurityFinding {
    let file: String
    let type: String
    let description: String
    let severity: String
    let timestamp: Date
}

struct SecurityReport {
    let totalFindings: Int
    let highSeverityCount: Int
    let findings: [SecurityFinding]
    let generatedAt: Date

    func formatted() -> String {
        var result = """
        Security Audit Report
        Generated: \(generatedAt.formatted(date: .long, time: .standard))

        Total Findings: \(totalFindings)
        High Severity: \(highSeverityCount)

        """

        if !findings.isEmpty {
            result += "\nFindings:\n"
            for finding in findings.prefix(10) {
                result += "\n[\(finding.severity.uppercased())] \(finding.file)"
                result += "\n  \(finding.description)\n"
            }
        }

        return result
    }
}

struct WorkflowPattern {
    let name: String
    let frequency: Int
    let lastSeen: Date
    let suggestion: String
}
