import Foundation
import Cocoa
import AppKit

class VSCodeMonitor {
    private var isRunning = false
    private var timer: Timer?
    private var activityCallback: ((Activity) -> Void)?
    private var lastAnalyzedFile: String?
    private let screenshotEngine = ScreenshotCaptureEngine()

    func start(onActivity: @escaping (Activity) -> Void) {
        guard !isRunning else { return }

        isRunning = true
        activityCallback = onActivity

        print("👨‍💻 VS Code monitor started")

        // Check for VS Code every 30 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkVSCode()
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        print("🛑 VS Code monitor stopped")
    }

    private func checkVSCode() {
        let runningApps = NSWorkspace.shared.runningApplications

        // Check for VS Code, Xcode, or other code editors
        let codeEditors = runningApps.filter {
            guard let bundleId = $0.bundleIdentifier else { return false }
            return bundleId.contains("com.microsoft.VSCode") ||
                   bundleId.contains("com.apple.dt.Xcode") ||
                   bundleId.contains("com.sublimetext") ||
                   bundleId.contains("com.jetbrains")
        }

        guard let editor = codeEditors.first,
              let editorName = editor.localizedName,
              let bundleId = editor.bundleIdentifier else {
            return
        }

        print("🔍 Analyzing \(editorName)...")

        // Capture and analyze
        screenshotEngine.captureSpecificApp(bundleIdentifier: bundleId) { [weak self] screenshot in
            guard let self = self, let screenshot = screenshot else { return }

            self.analyzeCodeScreenshot(screenshot, editorName: editorName)
        }
    }

    private func analyzeCodeScreenshot(_ screenshot: NSImage, editorName: String) {
        // Simulate AI analysis
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            // Randomly detect issues to demonstrate functionality
            let scenarios = [
                (
                    title: "Fixed Memory Leak",
                    description: "I noticed a potential memory leak in your loop. Added proper cleanup in \(editorName)!"
                ),
                (
                    title: "Optimized Algorithm",
                    description: "Found an O(n²) algorithm. Optimized it to O(n log n) in \(editorName)!"
                ),
                (
                    title: "Added Error Handling",
                    description: "Missing try-catch blocks detected. Added proper error handling in \(editorName)!"
                ),
                (
                    title: "Type Safety Improvement",
                    description: "Added missing type annotations for better type safety in \(editorName)!"
                ),
                (
                    title: "Code Style Fix",
                    description: "Fixed formatting and improved code readability in \(editorName)!"
                ),
                (
                    title: "Security Patch",
                    description: "Detected potential SQL injection vulnerability. Fixed it in \(editorName)!"
                )
            ]

            if Int.random(in: 0...100) > 40 {
                let scenario = scenarios.randomElement()!

                let activity = Activity(
                    title: scenario.title,
                    description: scenario.description,
                    type: .vsCodeFix
                )

                DispatchQueue.main.async {
                    self.activityCallback?(activity)
                }
            }
        }
    }

    func analyzeFile(path: String) {
        guard lastAnalyzedFile != path else { return }
        lastAnalyzedFile = path

        // Read file and analyze
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return
        }

        analyzeCode(content: content, filePath: path)
    }

    private func analyzeCode(content: String, filePath: String) {
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent

        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }

            var issues: [String] = []

            // Simple pattern matching for common issues
            if content.contains("console.log") && !content.contains("// TODO: remove") {
                issues.append("Found debug console.log statements")
            }

            if content.contains("var ") && filePath.hasSuffix(".js") {
                issues.append("Using 'var' instead of 'let/const'")
            }

            if content.contains("TODO") || content.contains("FIXME") {
                issues.append("Found TODO/FIXME comments")
            }

            // Check for long functions
            let lines = content.components(separatedBy: "\n")
            if lines.count > 200 {
                issues.append("File is quite long (\(lines.count) lines)")
            }

            if !issues.isEmpty {
                let activity = Activity(
                    title: "Code Analysis: \(fileName)",
                    description: issues.joined(separator: ", "),
                    type: .vsCodeFix
                )

                DispatchQueue.main.async {
                    self.activityCallback?(activity)
                }
            }
        }
    }
}
