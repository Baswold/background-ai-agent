import Cocoa
import SwiftUI
import ScreenCaptureKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var menuBarView: MenuBarView?
    var popover: NSPopover?
    var agentEngine: EnhancedAgentEngine?
    var isEnabled: Bool = true {
        didSet {
            Settings.shared.isEnabled = isEnabled
            agentEngine?.setEnabled(isEnabled)
        }
    }

    // Additional powerful tools
    private var clipboardMonitor: ClipboardMonitor?
    private var productivityTracker: ProductivityTracker?
    private var smartReminders: SmartReminders?
    private var terminalMonitor: TerminalMonitor?
    private var networkMonitor: NetworkMonitor?
    private var snippetManager: CodeSnippetManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Enhanced Background AI Agent starting up...")
        print("🎯 Loading MASSIVE feature set...")

        // Initialize configuration
        AppConfig.initialize()

        // Request permissions
        requestPermissions()

        // Setup menu bar
        setupMenuBar()

        // Initialize the ENHANCED AI agent engine
        agentEngine = EnhancedAgentEngine()

        // Initialize all the powerful tools
        initializeAdvancedTools()

        // Setup keyboard shortcuts
        KeyboardShortcuts.shared.registerDefaultShortcuts(delegate: self)

        // Load saved state
        isEnabled = Settings.shared.isEnabled

        // Start monitoring if enabled
        if isEnabled {
            startAllSystems()
        }

        print("✨ Enhanced Background AI Agent READY!")
        print("📊 Features loaded:")
        print("  ✅ Real AI Analysis (Claude API)")
        print("  ✅ File System Watching")
        print("  ✅ GitHub Integration")
        print("  ✅ OCR Text Extraction")
        print("  ✅ Form Automation")
        print("  ✅ Clipboard Monitoring")
        print("  ✅ Productivity Tracking")
        print("  ✅ Smart Reminders")
        print("  ✅ Terminal Monitoring")
        print("  ✅ Network Monitoring")
        print("  ✅ Code Snippet Manager")
        print("  ✅ Auto Documentation")
        print("  ✅ Keyboard Shortcuts")
        print("  🎉 AND MORE!")
    }

    private func initializeAdvancedTools() {
        clipboardMonitor = ClipboardMonitor()
        productivityTracker = ProductivityTracker()
        smartReminders = SmartReminders()
        terminalMonitor = TerminalMonitor()
        networkMonitor = NetworkMonitor()
        snippetManager = CodeSnippetManager()

        print("🛠️ Advanced tools initialized")
    }

    private func startAllSystems() {
        // Start main engine
        agentEngine?.start()

        // Start clipboard monitoring
        clipboardMonitor?.start { [weak self] activity in
            self?.handleActivity(activity)
        }

        // Start productivity tracking
        productivityTracker?.start()

        // Start smart reminders
        smartReminders?.start { [weak self] activity in
            self?.handleActivity(activity)
        }

        // Start terminal monitoring
        terminalMonitor?.start { [weak self] activity in
            self?.handleActivity(activity)
        }

        // Start network monitoring
        networkMonitor?.start { [weak self] activity in
            self?.handleActivity(activity)
        }

        print("🚀 All systems operational!")
    }

    private func handleActivity(_ activity: Activity) {
        // Additional activity handling could go here
        print("📝 Activity logged: \(activity.title)")
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

    // Public access for keyboard shortcuts
    func getProductivityReport() -> ProductivityReport? {
        return productivityTracker?.getProductivityReport()
    }

    func getCodeSnippets() -> [CodeSnippet] {
        return snippetManager?.getTopSnippets() ?? []
    }
}
