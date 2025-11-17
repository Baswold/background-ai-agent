import Foundation

struct AppConfig {
    // AI Configuration
    static let claudeAPIKey = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"] ?? ""
    static let claudeModel = "claude-sonnet-4-5-20250929"
    static let claudeAPIURL = "https://api.anthropic.com/v1/messages"

    // GitHub Configuration
    static let githubToken = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] ?? ""
    static let githubAPIURL = "https://api.github.com"

    // App Settings
    static let screenshotInterval: TimeInterval = 30.0 // seconds
    static let codeCheckInterval: TimeInterval = 15.0
    static let browserCheckInterval: TimeInterval = 20.0
    static let githubCheckInterval: TimeInterval = 300.0 // 5 minutes

    // Paths
    static let baseDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".background-ai-agent")
    static let memoryDB = baseDirectory.appendingPathComponent("memory.db")
    static let screenshotsDir = baseDirectory.appendingPathComponent("screenshots")
    static let codeFixesDir = baseDirectory.appendingPathComponent("code-fixes")
    static let logsDir = baseDirectory.appendingPathComponent("logs")

    // Feature Flags
    static var enableAIAnalysis = true
    static var enableCodeFixes = true
    static var enableGitHubIntegration = true
    static var enableFormFilling = true
    static var enableScreenshots = true
    static var enableFileWatching = true

    static func initialize() {
        let dirs = [baseDirectory, screenshotsDir, codeFixesDir, logsDir]
        for dir in dirs {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}

class Settings: ObservableObject {
    static let shared = Settings()

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "agent.enabled") }
    }

    @Published var enableNotifications: Bool {
        didSet { UserDefaults.standard.set(enableNotifications, forKey: "agent.notifications") }
    }

    @Published var enableCodeAnalysis: Bool {
        didSet { UserDefaults.standard.set(enableCodeAnalysis, forKey: "agent.codeAnalysis") }
    }

    @Published var enableBrowserMonitoring: Bool {
        didSet { UserDefaults.standard.set(enableBrowserMonitoring, forKey: "agent.browserMonitoring") }
    }

    @Published var enableGitHub: Bool {
        didSet { UserDefaults.standard.set(enableGitHub, forKey: "agent.github") }
    }

    @Published var enableScreenshots: Bool {
        didSet { UserDefaults.standard.set(enableScreenshots, forKey: "agent.screenshots") }
    }

    @Published var claudeAPIKey: String {
        didSet {
            if !claudeAPIKey.isEmpty {
                try? saveToKeychain(key: "claude.api.key", value: claudeAPIKey)
            }
        }
    }

    @Published var githubToken: String {
        didSet {
            if !githubToken.isEmpty {
                try? saveToKeychain(key: "github.token", value: githubToken)
            }
        }
    }

    @Published var watchedDirectories: [String] {
        didSet {
            UserDefaults.standard.set(watchedDirectories, forKey: "agent.watchedDirs")
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "agent.launchAtLogin")
            configureLaunchAtLogin(launchAtLogin)
        }
    }

    private init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "agent.enabled") as? Bool ?? true
        self.enableNotifications = UserDefaults.standard.object(forKey: "agent.notifications") as? Bool ?? true
        self.enableCodeAnalysis = UserDefaults.standard.object(forKey: "agent.codeAnalysis") as? Bool ?? true
        self.enableBrowserMonitoring = UserDefaults.standard.object(forKey: "agent.browserMonitoring") as? Bool ?? true
        self.enableGitHub = UserDefaults.standard.object(forKey: "agent.github") as? Bool ?? true
        self.enableScreenshots = UserDefaults.standard.object(forKey: "agent.screenshots") as? Bool ?? true
        self.watchedDirectories = UserDefaults.standard.object(forKey: "agent.watchedDirs") as? [String] ?? []
        self.launchAtLogin = UserDefaults.standard.object(forKey: "agent.launchAtLogin") as? Bool ?? false

        // Load from keychain
        self.claudeAPIKey = (try? loadFromKeychain(key: "claude.api.key")) ?? AppConfig.claudeAPIKey
        self.githubToken = (try? loadFromKeychain(key: "github.token")) ?? AppConfig.githubToken
    }

    private func saveToKeychain(key: String, value: String) throws {
        let data = value.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadFromKeychain(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func configureLaunchAtLogin(_ enabled: Bool) {
        // This would use SMLoginItemSetEnabled in a real implementation
        // For now, we'll log the intent
        print(enabled ? "✅ Launch at login enabled" : "❌ Launch at login disabled")
    }
}
