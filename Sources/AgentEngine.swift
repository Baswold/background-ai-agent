import Foundation
import Cocoa
import AppKit
import ScreenCaptureKit
import UserNotifications

class AgentEngine: NSObject {
    private var isEnabled = true
    private var recentActivities: [Activity] = []
    private var workspace: NSWorkspace
    private var appObserver: NSObjectProtocol?
    private var memoryManager: MemoryManager
    private var screenshotCaptureEngine: ScreenshotCaptureEngine
    private var vsCodeMonitor: VSCodeMonitor
    private var browserMonitor: BrowserMonitor
    private var githubMonitor: GitHubMonitor

    override init() {
        self.workspace = NSWorkspace.shared
        self.memoryManager = MemoryManager()
        self.screenshotCaptureEngine = ScreenshotCaptureEngine()
        self.vsCodeMonitor = VSCodeMonitor()
        self.browserMonitor = BrowserMonitor()
        self.githubMonitor = GitHubMonitor()

        super.init()

        setupNotificationObservers()
    }

    func start() {
        guard isEnabled else { return }

        print("🧠 Agent Engine starting...")

        // Start monitoring app activations
        startAppMonitoring()

        // Start VS Code monitoring
        vsCodeMonitor.start { [weak self] activity in
            self?.addActivity(activity)
            self?.sendNotification(activity: activity)
        }

        // Start browser monitoring
        browserMonitor.start { [weak self] activity in
            self?.addActivity(activity)
            self?.sendNotification(activity: activity)
        }

        // Start GitHub monitoring
        githubMonitor.start { [weak self] activity in
            self?.addActivity(activity)
            self?.sendNotification(activity: activity)
        }

        memoryManager.logEvent("Agent started monitoring")
    }

    func stop() {
        print("🛑 Agent Engine stopping...")

        if let observer = appObserver {
            workspace.notificationCenter.removeObserver(observer)
        }

        vsCodeMonitor.stop()
        browserMonitor.stop()
        githubMonitor.stop()

        memoryManager.logEvent("Agent stopped monitoring")
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
        return Array(recentActivities.prefix(20))
    }

    private func setupNotificationObservers() {
        // Observe app activations
        appObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
    }

    private func startAppMonitoring() {
        print("👀 Starting app monitoring...")
    }

    private func handleAppActivation(_ notification: Notification) {
        guard isEnabled else { return }

        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let appName = app.localizedName else {
            return
        }

        print("📱 App activated: \(appName)")

        // Log to memory
        memoryManager.logEvent("Opened \(appName)")

        // Take screenshot after a short delay to let the app open
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.captureAndAnalyzeApp(appName: appName, bundleId: app.bundleIdentifier ?? "")
        }
    }

    private func captureAndAnalyzeApp(appName: String, bundleId: String) {
        screenshotCaptureEngine.captureActiveWindow { [weak self] screenshot in
            guard let self = self, let screenshot = screenshot else { return }

            // Save screenshot
            self.saveScreenshot(screenshot, appName: appName)

            // Analyze based on app type
            if bundleId.contains("com.microsoft.VSCode") || bundleId.contains("Xcode") {
                self.analyzeCodeEditor(screenshot, appName: appName)
            } else if bundleId.contains("Safari") || bundleId.contains("Chrome") || bundleId.contains("Firefox") {
                self.analyzeBrowser(screenshot, appName: appName)
            }

            let activity = Activity(
                title: "Captured \(appName)",
                description: "Screenshot saved and analyzed",
                type: .screenshot
            )
            self.addActivity(activity)
        }
    }

    private func analyzeCodeEditor(_ screenshot: NSImage, appName: String) {
        // Simulate AI analysis of code
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }

            // Simulate finding an issue
            let foundIssue = Int.random(in: 0...100) > 60

            if foundIssue {
                let issues = [
                    "potential memory leak in loop",
                    "unused variable declaration",
                    "missing error handling",
                    "inefficient algorithm detected",
                    "missing type annotation"
                ]

                let fixes = [
                    "Added proper cleanup",
                    "Removed unused code",
                    "Added try-catch block",
                    "Optimized the algorithm",
                    "Added type definitions"
                ]

                let issue = issues.randomElement()!
                let fix = fixes.randomElement()!

                let activity = Activity(
                    title: "Fixed Code Issue",
                    description: "Found \(issue). \(fix)!",
                    type: .vsCodeFix
                )

                self.addActivity(activity)
                self.sendNotification(activity: activity)
                self.memoryManager.logEvent("Fixed: \(issue)")
            }
        }
    }

    private func analyzeBrowser(_ screenshot: NSImage, appName: String) {
        // Simulate AI analysis of browser content
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }

            let detectedForm = Int.random(in: 0...100) > 70

            if detectedForm {
                let activity = Activity(
                    title: "Form Detected",
                    description: "I can help fill out this form automatically!",
                    type: .formFilled
                )

                self.addActivity(activity)
                self.sendNotification(activity: activity)
            }
        }
    }

    private func saveScreenshot(_ screenshot: NSImage, appName: String) {
        let screenshotsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".background-ai-agent")
            .appendingPathComponent("screenshots")

        try? FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())

        let filename = "\(appName)_\(timestamp).png"
        let filepath = screenshotsDir.appendingPathComponent(filename)

        if let tiffData = screenshot.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            try? pngData.write(to: filepath)
            print("📸 Screenshot saved: \(filepath.path)")
        }
    }

    private func addActivity(_ activity: Activity) {
        DispatchQueue.main.async { [weak self] in
            self?.recentActivities.insert(activity, at: 0)
            if let count = self?.recentActivities.count, count > 50 {
                self?.recentActivities.removeLast()
            }
        }
    }

    private func sendNotification(activity: Activity) {
        let content = UNMutableNotificationContent()
        content.title = activity.title
        content.body = activity.description
        content.sound = .default

        // Add custom sound and style
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
}
