import Cocoa
import SwiftUI
import ScreenCaptureKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var menuBarView: MenuBarView?
    var popover: NSPopover?
    var agentEngine: AgentEngine?
    var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "agentEnabled")
            agentEngine?.setEnabled(isEnabled)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Background AI Agent starting up...")

        // Request permissions
        requestPermissions()

        // Setup menu bar
        setupMenuBar()

        // Initialize the AI agent engine
        agentEngine = AgentEngine()

        // Load saved state
        isEnabled = UserDefaults.standard.bool(forKey: "agentEnabled")
        if !UserDefaults.standard.object(forKey: "agentEnabled") != nil {
            isEnabled = true // Default to enabled on first launch
        }

        // Start monitoring if enabled
        if isEnabled {
            agentEngine?.start()
        }

        print("✅ Background AI Agent ready!")
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "AI Agent")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create the popover with SwiftUI view
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 500)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarView(delegate: self))
    }

    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(nil)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    func requestPermissions() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("❌ Notification permission denied")
            }
        }

        // Request screen recording permission
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                print("✅ Screen recording permission granted")
            } catch {
                print("❌ Screen recording permission needed - please enable in System Settings")
                showPermissionAlert()
            }
        }

        // Request accessibility permissions
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("⚠️ Accessibility permission needed - please enable in System Settings")
            showAccessibilityAlert()
        }
    }

    func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = "Please enable Screen Recording permission in System Settings > Privacy & Security > Screen Recording"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")

            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
            }
        }
    }

    func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Please enable Accessibility permission in System Settings > Privacy & Security > Accessibility"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")

            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }
}
