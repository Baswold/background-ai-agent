import Foundation
import Cocoa
import ScreenCaptureKit
import CoreGraphics

class ScreenshotCaptureEngine {
    func captureActiveWindow(completion: @escaping (NSImage?) -> Void) {
        Task {
            await captureScreen(completion: completion)
        }
    }

    func captureFullScreen(completion: @escaping (NSImage?) -> Void) {
        Task {
            await captureScreen(fullScreen: true, completion: completion)
        }
    }

    private func captureScreen(fullScreen: Bool = false, completion: @escaping (NSImage?) -> Void) async {
        do {
            // Get available content
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            guard let display = content.displays.first else {
                print("❌ No display found")
                completion(nil)
                return
            }

            var filter: SCContentFilter

            if fullScreen {
                // Capture entire display
                filter = SCContentFilter(display: display, excludingWindows: [])
            } else {
                // Try to capture the active window
                if let activeWindow = getActiveWindow(from: content.windows) {
                    filter = SCContentFilter(desktopIndependentWindow: activeWindow)
                } else {
                    // Fallback to full screen if no active window
                    filter = SCContentFilter(display: display, excludingWindows: [])
                }
            }

            let config = SCStreamConfiguration()
            config.width = fullScreen ? Int(display.width) : 1920
            config.height = fullScreen ? Int(display.height) : 1080
            config.scalesToFit = true

            // Capture the screenshot
            let screenshot = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            // Convert CGImage to NSImage
            let nsImage = NSImage(cgImage: screenshot, size: NSSize(width: screenshot.width, height: screenshot.height))

            DispatchQueue.main.async {
                completion(nsImage)
            }

        } catch {
            print("❌ Screenshot capture error: \(error)")
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }

    private func getActiveWindow(from windows: [SCWindow]) -> SCWindow? {
        // Get the frontmost application
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        // Find the window belonging to the frontmost app
        return windows.first { window in
            window.owningApplication?.bundleIdentifier == frontApp.bundleIdentifier &&
            window.isOnScreen &&
            window.frame.width > 100 &&
            window.frame.height > 100
        }
    }

    func captureSpecificApp(bundleIdentifier: String, completion: @escaping (NSImage?) -> Void) {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false,
                    onScreenWindowsOnly: true
                )

                // Find windows for specific app
                let appWindows = content.windows.filter {
                    $0.owningApplication?.bundleIdentifier == bundleIdentifier &&
                    $0.isOnScreen
                }

                guard let window = appWindows.first else {
                    print("❌ No window found for app: \(bundleIdentifier)")
                    completion(nil)
                    return
                }

                let filter = SCContentFilter(desktopIndependentWindow: window)
                let config = SCStreamConfiguration()
                config.width = 1920
                config.height = 1080
                config.scalesToFit = true

                let screenshot = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )

                let nsImage = NSImage(cgImage: screenshot, size: NSSize(width: screenshot.width, height: screenshot.height))

                DispatchQueue.main.async {
                    completion(nsImage)
                }

            } catch {
                print("❌ App screenshot error: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}
