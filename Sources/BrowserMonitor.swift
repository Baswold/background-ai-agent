import Foundation
import Cocoa
import AppKit

class BrowserMonitor {
    var isRunning = false
    var timer: Timer?
    var activityCallback: ((Activity) -> Void)?

    func start(onActivity: @escaping (Activity) -> Void) {
        guard !isRunning else { return }
        isRunning = true
        activityCallback = onActivity
        print("🌐 Browser monitor started (legacy mode - screenshot analysis is better)")
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        print("🛑 Browser monitor stopped")
    }
}
