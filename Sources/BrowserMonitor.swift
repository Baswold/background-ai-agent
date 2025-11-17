import Foundation
import Cocoa
import AppKit

class BrowserMonitor {
    private var isRunning = false
    private var timer: Timer?
    private var activityCallback: ((Activity) -> Void)?
    private let screenshotEngine = ScreenshotCaptureEngine()

    func start(onActivity: @escaping (Activity) -> Void) {
        guard !isRunning else { return }

        isRunning = true
        activityCallback = onActivity

        print("🌐 Browser monitor started")

        // Check browsers every 45 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: true) { [weak self] _ in
            self?.checkBrowsers()
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        print("🛑 Browser monitor stopped")
    }

    private func checkBrowsers() {
        let runningApps = NSWorkspace.shared.runningApplications

        // Check for browsers
        let browsers = runningApps.filter {
            guard let bundleId = $0.bundleIdentifier else { return false }
            return bundleId.contains("Safari") ||
                   bundleId.contains("Chrome") ||
                   bundleId.contains("Firefox") ||
                   bundleId.contains("Edge") ||
                   bundleId.contains("Arc")
        }

        guard let browser = browsers.first,
              let browserName = browser.localizedName,
              let bundleId = browser.bundleIdentifier else {
            return
        }

        print("🔍 Analyzing \(browserName)...")

        // Capture and analyze
        screenshotEngine.captureSpecificApp(bundleIdentifier: bundleId) { [weak self] screenshot in
            guard let self = self, let screenshot = screenshot else { return }

            self.analyzeBrowserScreenshot(screenshot, browserName: browserName)
        }
    }

    private func analyzeBrowserScreenshot(_ screenshot: NSImage, browserName: String) {
        // Simulate AI analysis of browser content
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }

            let scenarios = [
                (
                    title: "Form Auto-Fill Available",
                    description: "I detected a form on this page. I can help fill it out automatically!"
                ),
                (
                    title: "Documentation Helper",
                    description: "Looks like you're reading docs. I saved key points to memory for later!"
                ),
                (
                    title: "GitHub PR Detected",
                    description: "Found a GitHub pull request. Analyzing the code changes..."
                ),
                (
                    title: "Stack Overflow Solution",
                    description: "I found a better solution to this problem. Want me to apply it?"
                ),
                (
                    title: "Shopping Assistant",
                    description: "I can help compare prices or fill out checkout forms!"
                ),
                (
                    title: "Research Helper",
                    description: "I'm summarizing this article and saving it to your memory!"
                )
            ]

            // Randomly trigger browser actions to demonstrate
            if Int.random(in: 0...100) > 50 {
                let scenario = scenarios.randomElement()!

                let activity = Activity(
                    title: scenario.title,
                    description: scenario.description,
                    type: .browserAction
                )

                DispatchQueue.main.async {
                    self.activityCallback?(activity)
                }
            }
        }
    }

    func detectForm() -> Bool {
        // This would use accessibility APIs to detect forms
        return Int.random(in: 0...100) > 70
    }

    func fillForm(fields: [String: String]) {
        // Simulate form filling using accessibility APIs
        print("📝 Auto-filling form with \(fields.count) fields...")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            let activity = Activity(
                title: "Form Auto-Filled",
                description: "Successfully filled \(fields.count) form fields!",
                type: .formFilled
            )

            self?.activityCallback?(activity)
        }
    }
}
