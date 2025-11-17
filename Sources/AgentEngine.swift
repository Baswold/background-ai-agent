import Foundation
import Cocoa
import AppKit
import ScreenCaptureKit
import UserNotifications

class EnhancedAgentEngine: NSObject {
    private var isEnabled = true
    private var recentActivities: [Activity] = []
    private var workspace: NSWorkspace
    private var appObserver: NSObjectProtocol?

    // Enhanced components
    private var screenshotEngine: ScreenshotCaptureEngine
    private var codeFileMonitor: CodeFileMonitor
    private var githubMonitor: GitHubMonitor
    private var memoryDB: MemoryDatabase

    override init() {
        self.workspace = NSWorkspace.shared
        self.screenshotEngine = ScreenshotCaptureEngine()
        self.codeFileMonitor = CodeFileMonitor()
        self.githubMonitor = GitHubMonitor()
        self.memoryDB = MemoryDatabase()

        super.init()

        // Initialize
        AppConfig.initialize()
        setupNotificationObservers()
    }

    func start() {
        guard isEnabled else { return }

        print("🚀 Enhanced Agent Engine starting...")
        print("🔑 Claude API: \(Settings.shared.claudeAPIKey.isEmpty ? "❌ Not configured" : "✅ Ready")")
        print("🐙 GitHub Token: \(Settings.shared.githubToken.isEmpty ? "❌ Not configured" : "✅ Ready")")

        // Start app monitoring
        startAppMonitoring()

        // Start file watching
        if Settings.shared.enableCodeAnalysis {
            codeFileMonitor.start { [weak self] activity in
                self?.addActivity(activity)
                self?.sendNotification(activity: activity)
            }
        }

        // Start GitHub monitoring
        if Settings.shared.enableGitHub && !Settings.shared.githubToken.isEmpty {
            githubMonitor.startRealMonitoring { [weak self] activity in
                self?.addActivity(activity)
                self?.sendNotification(activity: activity)
            }
        }

        memoryDB.logEvent("Enhanced agent started - Real AI powered!")

        print("✨ Enhanced Agent Engine ready with REAL AI!")
    }

    func stop() {
        print("🛑 Enhanced Agent Engine stopping...")

        if let observer = appObserver {
            workspace.notificationCenter.removeObserver(observer)
        }

        codeFileMonitor.stop()
        githubMonitor.stop()

        memoryDB.logEvent("Enhanced agent stopped")
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            start()
        } else {
            stop()
        }
    }

    func getRecentActivities() -> [Activity] {
        return Array(recentActivities.prefix(50))
    }

    func captureScreenshotManually() {
        print("📸 Manual screenshot capture...")

        screenshotEngine.captureFullScreen { [weak self] screenshot in
            guard let self = self, let screenshot = screenshot else { return }

            self.saveScreenshot(screenshot, appName: "Manual")

            let activity = Activity(
                title: "Screenshot Captured",
                description: "Manual screenshot saved",
                type: .screenshot
            )

            self.addActivity(activity)
            self.sendNotification(activity: activity)
        }
    }

    // MARK: - Setup

    private func setupNotificationObservers() {
        appObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
    }

    private func startAppMonitoring() {
        print("👀 Starting enhanced app monitoring...")
    }

    // MARK: - App Activation Handling

    private func handleAppActivation(_ notification: Notification) {
        guard isEnabled else { return }
        guard Settings.shared.enableScreenshots else { return }

        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let appName = app.localizedName,
              let bundleId = app.bundleIdentifier else {
            return
        }

        print("📱 App activated: \(appName)")

        // Log to memory database
        memoryDB.logEvent("Opened \(appName)")
        memoryDB.logAppUsage(appName: appName, bundleId: bundleId)

        // Delayed capture and analysis
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.captureAndAnalyze(appName: appName, bundleId: bundleId)
        }
    }

    // MARK: - Screenshot Capture & Analysis

    private func captureAndAnalyze(appName: String, bundleId: String) {
        screenshotEngine.captureActiveWindow { [weak self] screenshot in
            guard let self = self, let screenshot = screenshot else { return }

            // Save screenshot
            self.saveScreenshot(screenshot, appName: appName)

            // Analyze based on app type
            Task {
                await self.performIntelligentAnalysis(
                    screenshot: screenshot,
                    appName: appName,
                    bundleId: bundleId
                )
            }
        }
    }

    private func performIntelligentAnalysis(screenshot: NSImage, appName: String, bundleId: String) async {
        do {
            // Extract text using OCR
            let extractedText = try await OCRService.shared.extractText(from: screenshot)

            // Detect if it's code
            if let detectedCode = try await OCRService.shared.detectCode(from: screenshot) {
                await analyzeExtractedCode(detectedCode, appName: appName)
                return
            }

            // Check for forms
            if let detectedForm = try await FormAutomation.shared.detectFormInFrontmostApp() {
                await handleDetectedForm(detectedForm, screenshot: screenshot)
                return
            }

            // General AI analysis with vision
            if !Settings.shared.claudeAPIKey.isEmpty {
                let context = "User is working in \(appName)"
                let analysis = try await AIService.shared.analyzeScreenshot(screenshot, context: context)

                if !analysis.suggestions.isEmpty {
                    let activity = Activity(
                        title: "Insight: \(appName)",
                        description: analysis.suggestions.first ?? "Analysis complete",
                        type: .learning
                    )

                    addActivity(activity)
                    if Settings.shared.enableNotifications {
                        sendNotification(activity: activity)
                    }
                }

                // Save insights to memory
                for suggestion in analysis.suggestions {
                    memoryDB.logInsight(category: appName, insight: suggestion)
                }
            }

        } catch {
            print("❌ Analysis error: \(error)")
        }
    }

    private func analyzeExtractedCode(_ code: DetectedCode, appName: String) async {
        guard !Settings.shared.claudeAPIKey.isEmpty else {
            print("⚠️ Claude API key not configured - skipping AI analysis")
            return
        }

        do {
            let analysis = try await AIService.shared.analyzeCode(code.text, language: code.language)

            let highPriorityIssues = analysis.issues.filter { $0.severity == "high" }

            if !highPriorityIssues.isEmpty {
                let issue = highPriorityIssues.first!

                let activity = Activity(
                    title: "Code Issue Detected in \(appName)",
                    description: "\(issue.type.capitalized): \(issue.description)",
                    type: .vsCodeFix
                )

                addActivity(activity)
                sendNotification(activity: activity)

                // Save to memory
                memoryDB.logCodeIssue(
                    file: appName,
                    language: code.language,
                    issueType: issue.type,
                    description: issue.description,
                    severity: issue.severity
                )
            }

            print("✅ Code analysis complete: \(analysis.issues.count) issues found")

        } catch {
            print("❌ Code analysis error: \(error)")
        }
    }

    private func handleDetectedForm(_ form: DetectedForm, screenshot: NSImage) async {
        let activity = Activity(
            title: "Form Detected in \(form.appName)",
            description: "Found \(form.fieldCount) fields. I can help fill it!",
            type: .formFilled
        )

        addActivity(activity)
        sendNotification(activity: activity)

        // Auto-generate form data
        let formData = await FormAutomation.shared.generateSmartFormData(for: form)

        print("📝 Generated form data for \(form.fieldCount) fields")

        memoryDB.logEvent("Detected form in \(form.appName) with \(form.fieldCount) fields")

        // Could auto-fill here if enabled
        // try? await FormAutomation.shared.fillForm(fields: formData, in: bundleId)
    }

    // MARK: - File Management

    private func saveScreenshot(_ screenshot: NSImage, appName: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())

        let filename = "\(appName)_\(timestamp).png"
        let filepath = AppConfig.screenshotsDir.appendingPathComponent(filename)

        if let tiffData = screenshot.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            try? pngData.write(to: filepath)
            print("📸 Screenshot saved: \(filepath.lastPathComponent)")
        }
    }

    // MARK: - Activity Management

    private func addActivity(_ activity: Activity) {
        DispatchQueue.main.async { [weak self] in
            self?.recentActivities.insert(activity, at: 0)
            if let count = self?.recentActivities.count, count > 100 {
                self?.recentActivities.removeLast()
            }
        }

        // Save to database
        memoryDB.logActivity(activity)
    }

    private func sendNotification(activity: Activity) {
        guard Settings.shared.enableNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = activity.title
        content.body = activity.description
        content.sound = .default

        // Add category for actions
        content.categoryIdentifier = "AGENT_ACTION"

        if #available(macOS 12.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let request = UNNotificationRequest(
            identifier: activity.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Notification error: \(error)")
            } else {
                print("✅ Notification sent: \(activity.title)")
            }
        }
    }

    // MARK: - Analytics

    func getStatistics() -> AgentStatistics {
        return memoryDB.getStatistics()
    }
}

// MARK: - Memory Database

class MemoryDatabase {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.backgroundai.memorydb", qos: .utility)

    init() {
        self.fileURL = AppConfig.baseDirectory.appendingPathComponent("memory.md")

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            initializeFile()
        }
    }

    private func initializeFile() {
        let content = """
        # 🧠 Background AI Agent Memory - Enhanced Edition

        **Started**: \(Date().formatted(date: .long, time: .standard))
        **Mode**: Real AI-Powered Analysis

        ## 🎯 Features Active
        - ✅ Real Claude AI Integration
        - ✅ Live File System Watching
        - ✅ GitHub API Integration
        - ✅ OCR Text Extraction
        - ✅ Form Auto-Detection
        - ✅ Global Keyboard Shortcuts

        ---

        ## 📊 Activity Log

        """

        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func logEvent(_ event: String) {
        queue.async { [weak self] in
            self?.append("\n### [\(Date().formatted(date: .abbreviated, time: .shortened))] \(event)")
        }
    }

    func logActivity(_ activity: Activity) {
        queue.async { [weak self] in
            let entry = """

            ### [\(activity.timestamp.formatted(date: .abbreviated, time: .shortened))] \(activity.type.rawValue.uppercased())
            **\(activity.title)**
            \(activity.description)

            """
            self?.append(entry)
        }
    }

    func logCodeIssue(file: String, language: String, issueType: String, description: String, severity: String) {
        let entry = """

        ### Code Issue - \(severity.uppercased())
        - **File**: \(file)
        - **Language**: \(language)
        - **Type**: \(issueType)
        - **Issue**: \(description)

        """
        queue.async { [weak self] in
            self?.append(entry)
        }
    }

    func logInsight(category: String, insight: String) {
        let entry = """

        ### 💡 Insight: \(category)
        > \(insight)

        """
        queue.async { [weak self] in
            self?.append(entry)
        }
    }

    func logAppUsage(appName: String, bundleId: String) {
        // Track app usage patterns
        queue.async { [weak self] in
            self?.append("\n- Opened: \(appName)")
        }
    }

    private func append(_ text: String) {
        guard var content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        content += text
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func getStatistics() -> AgentStatistics {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return AgentStatistics()
        }

        let lines = content.components(separatedBy: "\n")

        var stats = AgentStatistics()
        stats.totalEvents = lines.filter { $0.starts(with: "###") }.count
        stats.codeIssuesFound = lines.filter { $0.contains("Code Issue") }.count
        stats.insightsGenerated = lines.filter { $0.contains("💡 Insight") }.count

        return stats
    }
}

struct AgentStatistics {
    var totalEvents: Int = 0
    var codeIssuesFound: Int = 0
    var insightsGenerated: Int = 0
    var screenshotsTaken: Int = 0
    var formsDetected: Int = 0
}
