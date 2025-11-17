import Foundation

// MARK: - Configuration Management & Validation

/// Validates and manages application configuration
class ConfigurationManager {
    static let shared = ConfigurationManager()

    private let backupDirectory: URL
    private let queue = DispatchQueue(label: "com.backgroundai.config")

    private init() {
        backupDirectory = AppConfig.baseDirectory.appendingPathComponent("backups")

        // Create backup directory
        try? FileManager.default.createDirectory(
            at: backupDirectory,
            withIntermediateDirectories: true
        )

        Logger.shared.info("Configuration manager initialized", category: .configuration)
    }

    // MARK: - Validation

    func validateConfiguration() -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Validate API Keys
        if Settings.shared.claudeAPIKey.isEmpty {
            warnings.append("Claude API key is not configured. AI features will be disabled.")
        } else if !isValidClaudeAPIKey(Settings.shared.claudeAPIKey) {
            errors.append("Claude API key format appears invalid.")
        }

        if Settings.shared.enableGitHub && Settings.shared.githubToken.isEmpty {
            warnings.append("GitHub integration is enabled but token is not configured.")
        } else if !Settings.shared.githubToken.isEmpty && !isValidGitHubToken(Settings.shared.githubToken) {
            errors.append("GitHub token format appears invalid.")
        }

        // Validate Directories
        for directory in Settings.shared.watchedDirectories {
            if !FileManager.default.fileExists(atPath: directory) {
                errors.append("Watched directory does not exist: \(directory)")
            } else if !isDirectoryAccessible(directory) {
                errors.append("Cannot access watched directory: \(directory)")
            }
        }

        // Validate System Directories
        let systemDirs = [
            AppConfig.baseDirectory,
            AppConfig.screenshotsDir,
            AppConfig.codeFixesDir,
            AppConfig.logsDir
        ]

        for dir in systemDirs {
            if !FileManager.default.fileExists(atPath: dir.path) {
                warnings.append("System directory missing: \(dir.lastPathComponent)")

                // Try to create
                do {
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    warnings.append("  → Auto-created missing directory")
                } catch {
                    errors.append("Failed to create system directory: \(dir.lastPathComponent)")
                }
            }
        }

        // Validate Settings
        if Settings.shared.enableCodeAnalysis && Settings.shared.watchedDirectories.isEmpty {
            warnings.append("Code analysis is enabled but no directories are being watched.")
        }

        if Settings.shared.enableScreenshots {
            // Note: We can't easily check screen recording permission here without triggering a request
            // This would be done in the health check system
        }

        // Check for conflicts
        if !Settings.shared.isEnabled {
            warnings.append("Agent is currently disabled.")
        }

        let isValid = errors.isEmpty

        let result = ValidationResult(
            isValid: isValid,
            errors: errors,
            warnings: warnings,
            validatedAt: Date()
        )

        if !isValid {
            Logger.shared.error("Configuration validation failed with \(errors.count) errors", category: .configuration)
        } else if !warnings.isEmpty {
            Logger.shared.warning("Configuration has \(warnings.count) warnings", category: .configuration)
        } else {
            Logger.shared.info("Configuration validated successfully", category: .configuration)
        }

        return result
    }

    // MARK: - Backup & Restore

    func backupSettings() throws -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        let backupURL = backupDirectory.appendingPathComponent("settings-backup-\(timestamp).json")

        let backup = SettingsBackup(
            createdAt: Date(),
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            settings: SettingsSnapshot(
                isEnabled: Settings.shared.isEnabled,
                enableNotifications: Settings.shared.enableNotifications,
                enableCodeAnalysis: Settings.shared.enableCodeAnalysis,
                enableBrowserMonitoring: Settings.shared.enableBrowserMonitoring,
                enableGitHub: Settings.shared.enableGitHub,
                enableScreenshots: Settings.shared.enableScreenshots,
                watchedDirectories: Settings.shared.watchedDirectories,
                launchAtLogin: Settings.shared.launchAtLogin,
                hasClaudeAPIKey: !Settings.shared.claudeAPIKey.isEmpty,
                hasGitHubToken: !Settings.shared.githubToken.isEmpty
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(backup)
        try data.write(to: backupURL)

        Logger.shared.info("Settings backed up to: \(backupURL.lastPathComponent)", category: .configuration)

        // Clean up old backups (keep last 10)
        try cleanupOldBackups(keepCount: 10)

        return backupURL
    }

    func restoreSettings(from fileURL: URL) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw AppError.fileNotFound(path: fileURL.path)
        }

        let data = try Data(contentsOf: fileURL)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backup = try decoder.decode(SettingsBackup.self, from: data)

        // Create a backup of current settings before restoring
        let currentBackup = try backupSettings()
        Logger.shared.info("Current settings backed up before restore", category: .configuration)

        // Restore settings
        Settings.shared.isEnabled = backup.settings.isEnabled
        Settings.shared.enableNotifications = backup.settings.enableNotifications
        Settings.shared.enableCodeAnalysis = backup.settings.enableCodeAnalysis
        Settings.shared.enableBrowserMonitoring = backup.settings.enableBrowserMonitoring
        Settings.shared.enableGitHub = backup.settings.enableGitHub
        Settings.shared.enableScreenshots = backup.settings.enableScreenshots
        Settings.shared.watchedDirectories = backup.settings.watchedDirectories
        Settings.shared.launchAtLogin = backup.settings.launchAtLogin

        Logger.shared.info("Settings restored from: \(fileURL.lastPathComponent)", category: .configuration)

        // Note: API keys are not restored from backup for security reasons
        if backup.settings.hasClaudeAPIKey || backup.settings.hasGitHubToken {
            Logger.shared.warning("API keys were not restored. Please reconfigure them manually.", category: .configuration)
        }
    }

    func listBackups() -> [BackupInfo] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]
        ) else {
            return []
        }

        let backups = files
            .filter { $0.lastPathComponent.starts(with: "settings-backup-") }
            .compactMap { fileURL -> BackupInfo? in
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                      let createdAt = attributes[.creationDate] as? Date,
                      let size = attributes[.size] as? UInt64 else {
                    return nil
                }

                return BackupInfo(
                    fileURL: fileURL,
                    createdAt: createdAt,
                    size: size
                )
            }
            .sorted { $0.createdAt > $1.createdAt }

        return backups
    }

    private func cleanupOldBackups(keepCount: Int) throws {
        let backups = listBackups()

        guard backups.count > keepCount else { return }

        let toDelete = backups.dropFirst(keepCount)

        for backup in toDelete {
            try FileManager.default.removeItem(at: backup.fileURL)
            Logger.shared.debug("Deleted old backup: \(backup.fileURL.lastPathComponent)", category: .configuration)
        }
    }

    func deleteBackup(_ fileURL: URL) throws {
        guard fileURL.path.starts(with: backupDirectory.path) else {
            throw AppError.insufficientPermissions(path: fileURL.path)
        }

        try FileManager.default.removeItem(at: fileURL)
        Logger.shared.info("Deleted backup: \(fileURL.lastPathComponent)", category: .configuration)
    }

    // MARK: - Reset Configuration

    func resetToDefaults() {
        Logger.shared.warning("Resetting configuration to defaults", category: .configuration)

        // Create backup before reset
        do {
            try backupSettings()
        } catch {
            Logger.shared.error("Failed to backup settings before reset: \(error)", category: .errorHandling)
        }

        // Reset to defaults
        Settings.shared.isEnabled = true
        Settings.shared.enableNotifications = true
        Settings.shared.enableCodeAnalysis = true
        Settings.shared.enableBrowserMonitoring = true
        Settings.shared.enableGitHub = true
        Settings.shared.enableScreenshots = true
        Settings.shared.watchedDirectories = []
        Settings.shared.launchAtLogin = false

        // Don't clear API keys - user needs to reconfigure them explicitly

        Logger.shared.info("Configuration reset to defaults", category: .configuration)
    }

    // MARK: - Export/Import

    func exportConfiguration(to fileURL: URL, includeAPIKeys: Bool = false) throws {
        var config: [String: Any] = [
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "Unknown",
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "settings": [
                "isEnabled": Settings.shared.isEnabled,
                "enableNotifications": Settings.shared.enableNotifications,
                "enableCodeAnalysis": Settings.shared.enableCodeAnalysis,
                "enableBrowserMonitoring": Settings.shared.enableBrowserMonitoring,
                "enableGitHub": Settings.shared.enableGitHub,
                "enableScreenshots": Settings.shared.enableScreenshots,
                "watchedDirectories": Settings.shared.watchedDirectories,
                "launchAtLogin": Settings.shared.launchAtLogin
            ]
        ]

        if includeAPIKeys {
            config["apiKeys"] = [
                "claudeAPIKey": Settings.shared.claudeAPIKey,
                "githubToken": Settings.shared.githubToken
            ]

            Logger.shared.warning("Exporting configuration with API keys", category: .security)
        }

        let data = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        try data.write(to: fileURL)

        Logger.shared.info("Configuration exported to: \(fileURL.path)", category: .configuration)
    }

    func importConfiguration(from fileURL: URL) throws {
        let data = try Data(contentsOf: fileURL)
        guard let config = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError.invalidData(context: "Configuration file format invalid")
        }

        // Backup current settings
        try backupSettings()

        // Import settings
        if let settings = config["settings"] as? [String: Any] {
            if let value = settings["isEnabled"] as? Bool {
                Settings.shared.isEnabled = value
            }
            if let value = settings["enableNotifications"] as? Bool {
                Settings.shared.enableNotifications = value
            }
            if let value = settings["enableCodeAnalysis"] as? Bool {
                Settings.shared.enableCodeAnalysis = value
            }
            if let value = settings["enableBrowserMonitoring"] as? Bool {
                Settings.shared.enableBrowserMonitoring = value
            }
            if let value = settings["enableGitHub"] as? Bool {
                Settings.shared.enableGitHub = value
            }
            if let value = settings["enableScreenshots"] as? Bool {
                Settings.shared.enableScreenshots = value
            }
            if let value = settings["watchedDirectories"] as? [String] {
                Settings.shared.watchedDirectories = value
            }
            if let value = settings["launchAtLogin"] as? Bool {
                Settings.shared.launchAtLogin = value
            }
        }

        // Import API keys if present
        if let apiKeys = config["apiKeys"] as? [String: String] {
            if let claudeKey = apiKeys["claudeAPIKey"], !claudeKey.isEmpty {
                Settings.shared.claudeAPIKey = claudeKey
                Logger.shared.info("Claude API key imported", category: .configuration)
            }
            if let githubToken = apiKeys["githubToken"], !githubToken.isEmpty {
                Settings.shared.githubToken = githubToken
                Logger.shared.info("GitHub token imported", category: .configuration)
            }
        }

        Logger.shared.info("Configuration imported from: \(fileURL.path)", category: .configuration)
    }

    // MARK: - Validation Helpers

    private func isValidClaudeAPIKey(_ key: String) -> Bool {
        // Basic format check - Claude API keys typically start with "sk-"
        return key.starts(with: "sk-") && key.count > 20
    }

    private func isValidGitHubToken(_ token: String) -> Bool {
        // Basic format check - GitHub tokens typically start with "ghp_" or "github_pat_"
        return (token.starts(with: "ghp_") || token.starts(with: "github_pat_")) && token.count > 20
    }

    private func isDirectoryAccessible(_ path: String) -> Bool {
        return FileManager.default.isReadableFile(atPath: path)
    }
}

// MARK: - Data Models

struct ValidationResult {
    let isValid: Bool
    let errors: [String]
    let warnings: [String]
    let validatedAt: Date

    var hasErrors: Bool { !errors.isEmpty }
    var hasWarnings: Bool { !warnings.isEmpty }

    func formatted() -> String {
        var result = """
        Configuration Validation
        Status: \(isValid ? "✅ Valid" : "❌ Invalid")
        Validated: \(validatedAt.formatted(date: .abbreviated, time: .shortened))
        """

        if !errors.isEmpty {
            result += "\n\nErrors:"
            for error in errors {
                result += "\n  ❌ \(error)"
            }
        }

        if !warnings.isEmpty {
            result += "\n\nWarnings:"
            for warning in warnings {
                result += "\n  ⚠️ \(warning)"
            }
        }

        return result
    }
}

struct SettingsBackup: Codable {
    let createdAt: Date
    let version: String
    let settings: SettingsSnapshot
}

struct SettingsSnapshot: Codable {
    let isEnabled: Bool
    let enableNotifications: Bool
    let enableCodeAnalysis: Bool
    let enableBrowserMonitoring: Bool
    let enableGitHub: Bool
    let enableScreenshots: Bool
    let watchedDirectories: [String]
    let launchAtLogin: Bool
    let hasClaudeAPIKey: Bool
    let hasGitHubToken: Bool
}

struct BackupInfo {
    let fileURL: URL
    let createdAt: Date
    let size: UInt64

    var sizeMB: Double {
        return Double(size) / 1024 / 1024
    }

    func formatted() -> String {
        """
        Backup: \(fileURL.lastPathComponent)
        Created: \(createdAt.formatted(date: .abbreviated, time: .shortened))
        Size: \(String(format: "%.2f", sizeMB)) MB
        """
    }
}
