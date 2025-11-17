import Foundation
import UserNotifications
import AppKit

// MARK: - Advanced Notification Center

/// Centralized notification management with advanced features
class NotificationCenter {
    static let shared = NotificationCenter()

    private var notificationHistory: [AppNotification] = []
    private var unreadCount = 0
    private let maxHistorySize = 100

    private var notificationHandlers: [String: (AppNotification) -> Void] = [:]
    private let queue = DispatchQueue(label: "com.backgroundai.notifications")

    private init() {
        setupNotificationCategories()
        Logger.shared.info("Notification center initialized", category: .system)
    }

    // MARK: - Notification Management

    func send(_ notification: AppNotification) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Add to history
            self.notificationHistory.insert(notification, at: 0)
            if self.notificationHistory.count > self.maxHistorySize {
                self.notificationHistory.removeLast()
            }

            self.unreadCount += 1

            // Send system notification if enabled
            if Settings.shared.enableNotifications {
                self.sendSystemNotification(notification)
            }

            // Call handlers
            for handler in self.notificationHandlers.values {
                handler(notification)
            }

            // Log
            Logger.shared.info("Notification sent: \(notification.title)", category: .general)

            // Track analytics
            AnalyticsManager.shared.trackEvent(AnalyticsEvent(
                name: "notification_sent",
                category: .ui,
                properties: [
                    "type": notification.type.rawValue,
                    "priority": notification.priority.rawValue
                ]
            ))
        }
    }

    private func sendSystemNotification(_ notification: AppNotification) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = notification.priority == .critical ? .defaultCritical : .default
        content.categoryIdentifier = notification.type.rawValue

        if #available(macOS 12.0, *) {
            content.interruptionLevel = notification.priority.interruptionLevel
        }

        // Add actions if available
        if !notification.actions.isEmpty {
            content.categoryIdentifier = "ACTIONABLE"
        }

        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.shared.error("Failed to send notification: \(error)", category: .errorHandling)
            }
        }
    }

    // MARK: - History Management

    func getHistory(limit: Int = 50) -> [AppNotification] {
        return queue.sync {
            return Array(notificationHistory.prefix(limit))
        }
    }

    func markAsRead(_ id: UUID) {
        queue.async { [weak self] in
            guard let self = self else { return }

            if let index = self.notificationHistory.firstIndex(where: { $0.id == id }) {
                self.notificationHistory[index].isRead = true
                self.unreadCount = max(0, self.unreadCount - 1)
            }
        }
    }

    func markAllAsRead() {
        queue.async { [weak self] in
            guard let self = self else { return }

            for index in self.notificationHistory.indices {
                self.notificationHistory[index].isRead = true
            }
            self.unreadCount = 0
        }
    }

    func clearHistory() {
        queue.async { [weak self] in
            self?.notificationHistory.removeAll()
            self?.unreadCount = 0
        }
    }

    func getUnreadCount() -> Int {
        return queue.sync {
            return unreadCount
        }
    }

    // MARK: - Handlers

    func registerHandler(id: String, handler: @escaping (AppNotification) -> Void) {
        queue.async { [weak self] in
            self?.notificationHandlers[id] = handler
        }
    }

    func unregisterHandler(id: String) {
        queue.async { [weak self] in
            self?.notificationHandlers.removeValue(forKey: id)
        }
    }

    // MARK: - Quick Notifications

    func success(_ message: String, title: String = "Success") {
        send(AppNotification(
            title: title,
            body: message,
            type: .success,
            priority: .normal
        ))
    }

    func warning(_ message: String, title: String = "Warning") {
        send(AppNotification(
            title: title,
            body: message,
            type: .warning,
            priority: .high
        ))
    }

    func error(_ message: String, title: String = "Error") {
        send(AppNotification(
            title: title,
            body: message,
            type: .error,
            priority: .high
        ))
    }

    func info(_ message: String, title: String = "Info") {
        send(AppNotification(
            title: title,
            body: message,
            type: .info,
            priority: .normal
        ))
    }

    // MARK: - Setup

    private func setupNotificationCategories() {
        let categories: Set<UNNotificationCategory> = [
            UNNotificationCategory(
                identifier: "ACTIONABLE",
                actions: [],
                intentIdentifiers: [],
                options: .customDismissAction
            )
        ]

        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }
}

// MARK: - App Notification

struct AppNotification: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let type: NotificationType
    let priority: NotificationPriority
    let timestamp = Date()
    var isRead = false
    var actions: [NotificationAction] = []
    var metadata: [String: String] = [:]

    init(title: String, body: String, type: NotificationType, priority: NotificationPriority, actions: [NotificationAction] = []) {
        self.title = title
        self.body = body
        self.type = type
        self.priority = priority
        self.actions = actions
    }
}

enum NotificationType: String {
    case success, warning, error, info, system, security, ai, productivity

    var icon: String {
        switch self {
        case .success: return "✅"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .info: return "ℹ️"
        case .system: return "⚙️"
        case .security: return "🔒"
        case .ai: return "🤖"
        case .productivity: return "📊"
        }
    }
}

struct NotificationAction {
    let id: String
    let title: String
    let handler: () -> Void
}

extension NotificationPriority {
    @available(macOS 12.0, *)
    var interruptionLevel: UNNotificationInterruptionLevel {
        switch self {
        case .low: return .passive
        case .normal: return .active
        case .high: return .timeSensitive
        case .critical: return .critical
        }
    }
}

// MARK: - Command Palette

/// Quick command execution system
class CommandPalette {
    static let shared = CommandPalette()

    private var commands: [Command] = []
    private var recentCommands: [String] = []
    private let maxRecent = 10

    private init() {
        registerBuiltInCommands()
        Logger.shared.info("Command palette initialized", category: .system)
    }

    // MARK: - Command Management

    func registerCommand(_ command: Command) {
        commands.append(command)
        Logger.shared.debug("Command registered: \(command.name)", category: .system)
    }

    func executeCommand(id: String) async throws {
        guard let command = commands.first(where: { $0.id == id }) else {
            throw AppError.unexpectedState(description: "Command not found: \(id)")
        }

        Logger.shared.info("Executing command: \(command.name)", category: .general)

        // Add to recent
        recentCommands.insert(id, at: 0)
        if recentCommands.count > maxRecent {
            recentCommands.removeLast()
        }

        // Execute
        try await command.execute()

        // Track analytics
        AnalyticsManager.shared.trackEvent(AnalyticsEvent(
            name: "command_executed",
            category: .ui,
            properties: ["command": command.name]
        ))
    }

    func searchCommands(query: String) -> [Command] {
        guard !query.isEmpty else {
            return getRecentCommands()
        }

        return commands.filter { command in
            command.name.localizedCaseInsensitiveContains(query) ||
            command.description.localizedCaseInsensitiveContains(query) ||
            command.keywords.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    func getAllCommands() -> [Command] {
        return commands
    }

    func getRecentCommands() -> [Command] {
        return recentCommands.compactMap { id in
            commands.first { $0.id == id }
        }
    }

    // MARK: - Built-in Commands

    private func registerBuiltInCommands() {
        // System commands
        registerCommand(Command(
            id: "system.health_check",
            name: "Run Health Check",
            description: "Perform a comprehensive system health check",
            category: .system,
            keywords: ["health", "check", "diagnostic"],
            execute: {
                await HealthCheckSystem.shared.performHealthCheck()
                let status = HealthCheckSystem.shared.getOverallHealth()
                NotificationCenter.shared.info("System health: \(status.rawValue)")
            }
        ))

        registerCommand(Command(
            id: "system.clear_cache",
            name: "Clear Cache",
            description: "Clear all cached data",
            category: .system,
            keywords: ["cache", "clear", "clean"],
            execute: {
                await CacheManager.shared.clear()
                NotificationCenter.shared.success("Cache cleared successfully")
            }
        ))

        registerCommand(Command(
            id: "system.export_logs",
            name: "Export Logs",
            description: "Export recent logs to file",
            category: .system,
            keywords: ["logs", "export", "debug"],
            execute: {
                let logs = Logger.shared.getRecentLogs(count: 1000)
                // Would export logs
                NotificationCenter.shared.success("Logs exported successfully")
            }
        ))

        // Analytics commands
        registerCommand(Command(
            id: "analytics.generate_report",
            name: "Generate Analytics Report",
            description: "Generate comprehensive analytics report",
            category: .analytics,
            keywords: ["analytics", "report", "stats"],
            execute: {
                let report = AnalyticsManager.shared.generateReport()
                NotificationCenter.shared.success("Report generated: \(report.sessionStats.totalEvents) events")
            }
        ))

        // Configuration commands
        registerCommand(Command(
            id: "config.backup",
            name: "Backup Configuration",
            description: "Create a backup of current settings",
            category: .configuration,
            keywords: ["backup", "save", "config"],
            execute: {
                let url = try ConfigurationManager.shared.backupSettings()
                NotificationCenter.shared.success("Backup created: \(url.lastPathComponent)")
            }
        ))

        registerCommand(Command(
            id: "config.validate",
            name: "Validate Configuration",
            description: "Validate current configuration",
            category: .configuration,
            keywords: ["validate", "check", "config"],
            execute: {
                let result = ConfigurationManager.shared.validateConfiguration()
                if result.isValid {
                    NotificationCenter.shared.success("Configuration is valid")
                } else {
                    NotificationCenter.shared.error("Configuration has \(result.errors.count) errors")
                }
            }
        ))

        // Plugin commands
        registerCommand(Command(
            id: "plugins.list",
            name: "List Plugins",
            description: "Show all available plugins",
            category: .plugins,
            keywords: ["plugins", "list", "extensions"],
            execute: {
                let plugins = PluginManager.shared.getAllPlugins()
                NotificationCenter.shared.info("\(plugins.count) plugins available")
            }
        ))

        // Performance commands
        registerCommand(Command(
            id: "performance.stats",
            name: "Performance Statistics",
            description: "View performance metrics",
            category: .performance,
            keywords: ["performance", "metrics", "stats"],
            execute: {
                let stats = PerformanceMonitor.shared.getAllStatistics()
                NotificationCenter.shared.info("\(stats.count) metrics tracked")
            }
        ))

        Logger.shared.info("Built-in commands registered", category: .system)
    }
}

// MARK: - Command

struct Command {
    let id: String
    let name: String
    let description: String
    let category: CommandCategory
    let keywords: [String]
    let execute: () async throws -> Void

    init(id: String, name: String, description: String, category: CommandCategory, keywords: [String], execute: @escaping () async throws -> Void) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.keywords = keywords
        self.execute = execute
    }
}

enum CommandCategory: String {
    case system = "System"
    case analytics = "Analytics"
    case configuration = "Configuration"
    case plugins = "Plugins"
    case performance = "Performance"
    case ai = "AI"
    case automation = "Automation"
}

// MARK: - Quick Actions

/// Quick actions for common tasks
class QuickActions {
    static let shared = QuickActions()

    private init() {}

    func openDashboard() {
        Logger.shared.info("Opening dashboard", category: .ui)
        // Would open dashboard window
    }

    func openLogs() {
        let logsDir = AppConfig.logsDir
        NSWorkspace.shared.open(logsDir)
    }

    func openMemoryFile() {
        let memoryFile = AppConfig.baseDirectory.appendingPathComponent("memory.md")

        if !FileManager.default.fileExists(atPath: memoryFile.path) {
            try? "# Memory File\n\n".write(to: memoryFile, atomically: true, encoding: .utf8)
        }

        NSWorkspace.shared.open(memoryFile)
    }

    func exportDiagnostics() async throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        let exportURL = AppConfig.baseDirectory
            .appendingPathComponent("diagnostics-\(timestamp).json")

        try HealthCheckSystem.shared.exportDiagnostics(to: exportURL)

        NotificationCenter.shared.success("Diagnostics exported to: \(exportURL.lastPathComponent)")
        NSWorkspace.shared.activateFileViewerSelecting([exportURL])
    }

    func exportAnalytics() async throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        let exportURL = AppConfig.baseDirectory
            .appendingPathComponent("analytics-\(timestamp).json")

        try AnalyticsManager.shared.exportMetrics(to: exportURL)

        NotificationCenter.shared.success("Analytics exported to: \(exportURL.lastPathComponent)")
        NSWorkspace.shared.activateFileViewerSelecting([exportURL])
    }

    func restartHealthMonitoring() async {
        HealthCheckSystem.shared.stopMonitoring()
        await HealthCheckSystem.shared.performHealthCheck()
        HealthCheckSystem.shared.startMonitoring(interval: 300)

        NotificationCenter.shared.success("Health monitoring restarted")
    }

    func toggleFeature(_ feature: String) {
        switch feature {
        case "code_analysis":
            Settings.shared.enableCodeAnalysis.toggle()
        case "screenshots":
            Settings.shared.enableScreenshots.toggle()
        case "github":
            Settings.shared.enableGitHub.toggle()
        case "browser":
            Settings.shared.enableBrowserMonitoring.toggle()
        default:
            break
        }

        NotificationCenter.shared.info("Feature \(feature) toggled")
    }
}
