import Foundation
import Cocoa
import AppKit

class VSCodeMonitor {
    var isRunning = false
    var timer: Timer?
    var activityCallback: ((Activity) -> Void)?
    private var lastAnalyzedFile: String?
    private let screenshotEngine = ScreenshotCaptureEngine()

    func start(onActivity: @escaping (Activity) -> Void) {
        guard !isRunning else { return }

        isRunning = true
        activityCallback = onActivity

        print("👨‍💻 VS Code monitor started (legacy mode - file watching is better)")
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        print("🛑 VS Code monitor stopped")
    }
}
