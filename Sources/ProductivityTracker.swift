import Foundation
import Cocoa

class ProductivityTracker {
    private var appTimeTracking: [String: TimeInterval] = [:]
    private var currentApp: String?
    private var currentAppStartTime: Date?
    private var dailyStats: DailyStats = DailyStats()
    private var focusSessions: [FocusSession] = []

    func start() {
        // Track app switches
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppSwitch(notification)
        }

        print("📊 Productivity tracker started")
    }

    private func handleAppSwitch(_ notification: Notification) {
        // Save time for previous app
        if let currentApp = currentApp,
           let startTime = currentAppStartTime {
            let duration = Date().timeIntervalSince(startTime)
            appTimeTracking[currentApp, default: 0] += duration
        }

        // Start tracking new app
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           let appName = app.localizedName {
            currentApp = appName
            currentAppStartTime = Date()

            // Categorize app
            categorizeActivity(appName: appName)
        }
    }

    private func categorizeActivity(appName: String) {
        let productiveApps = ["Xcode", "Visual Studio Code", "Terminal", "iTerm", "Sublime Text"]
        let communicationApps = ["Slack", "Discord", "Mail", "Messages", "Zoom"]
        let browsingApps = ["Safari", "Chrome", "Firefox"]

        if productiveApps.contains(where: { appName.contains($0) }) {
            dailyStats.productiveTime += 1
        } else if communicationApps.contains(where: { appName.contains($0) }) {
            dailyStats.communicationTime += 1
        } else if browsingApps.contains(where: { appName.contains($0) }) {
            dailyStats.browsingTime += 1
        }
    }

    func startFocusSession(duration: TimeInterval = 25 * 60) {
        let session = FocusSession(
            id: UUID(),
            startTime: Date(),
            plannedDuration: duration,
            type: .pomodoro
        )
        focusSessions.append(session)

        print("🎯 Focus session started: \(duration/60) minutes")
    }

    func getProductivityReport() -> ProductivityReport {
        let sortedApps = appTimeTracking.sorted { $0.value > $1.value }

        return ProductivityReport(
            topApps: sortedApps.prefix(10).map { ($0.key, $0.value) },
            totalTime: appTimeTracking.values.reduce(0, +),
            dailyStats: dailyStats,
            focusSessions: focusSessions.count
        )
    }

    func detectDeepWorkPeriod() -> Bool {
        // Detect if user has been focused on code/productive apps
        guard let currentApp = currentApp,
              let startTime = currentAppStartTime else {
            return false
        }

        let duration = Date().timeIntervalSince(startTime)
        let isProductiveApp = currentApp.contains("Code") || currentApp.contains("Xcode")

        return isProductiveApp && duration > 30 * 60 // 30 minutes
    }
}

struct DailyStats {
    var productiveTime: TimeInterval = 0
    var communicationTime: TimeInterval = 0
    var browsingTime: TimeInterval = 0
    var distractedTime: TimeInterval = 0
}

struct FocusSession: Identifiable {
    let id: UUID
    let startTime: Date
    let plannedDuration: TimeInterval
    let type: FocusType
    var endTime: Date?
    var completed: Bool = false
}

enum FocusType {
    case pomodoro
    case deepWork
    case custom
}

struct ProductivityReport {
    let topApps: [(String, TimeInterval)]
    let totalTime: TimeInterval
    let dailyStats: DailyStats
    let focusSessions: Int
}
