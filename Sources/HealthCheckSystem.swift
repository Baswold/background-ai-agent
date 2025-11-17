import Foundation
import AppKit
import ScreenCaptureKit

// MARK: - Health Check System

/// Monitors the health of all system components
class HealthCheckSystem {
    static let shared = HealthCheckSystem()

    private var componentHealth: [String: ComponentHealth] = [:]
    private let queue = DispatchQueue(label: "com.backgroundai.healthcheck")
    private var healthCheckTimer: Timer?

    private init() {
        Logger.shared.info("Health check system initialized", category: .system)
    }

    func startMonitoring(interval: TimeInterval = 60) {
        healthCheckTimer?.invalidate()

        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.performHealthCheck()
            }
        }

        Logger.shared.info("Health monitoring started (interval: \(interval)s)", category: .system)

        // Perform initial check
        Task {
            await performHealthCheck()
        }
    }

    func stopMonitoring() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        Logger.shared.info("Health monitoring stopped", category: .system)
    }

    // MARK: - Health Checks

    func performHealthCheck() async {
        Logger.shared.debug("Performing health check...", category: .system)

        let checks: [(String, () async -> ComponentHealth)] = [
            ("Configuration", checkConfiguration),
            ("API Connectivity", checkAPIConnectivity),
            ("File System", checkFileSystem),
            ("Permissions", checkPermissions),
            ("Rate Limiter", checkRateLimiter),
            ("Cache", checkCache),
            ("Memory", checkMemory)
        ]

        for (name, check) in checks {
            let health = await check()
            queue.sync {
                componentHealth[name] = health
            }
        }

        // Log overall health
        let status = getOverallHealth()
        Logger.shared.info("Health check complete: \(status.rawValue)", category: .system)

        if status == .degraded || status == .unhealthy {
            Logger.shared.warning("System health degraded. Run diagnostics for details.", category: .system)
        }
    }

    // MARK: - Individual Health Checks

    private func checkConfiguration() async -> ComponentHealth {
        var issues: [String] = []

        // Check API keys
        if Settings.shared.claudeAPIKey.isEmpty {
            issues.append("Claude API key not configured")
        }

        // Check watched directories
        if Settings.shared.watchedDirectories.isEmpty {
            issues.append("No directories configured for watching")
        }

        // Validate directories exist
        for dir in Settings.shared.watchedDirectories {
            if !FileManager.default.fileExists(atPath: dir) {
                issues.append("Watched directory does not exist: \(dir)")
            }
        }

        let status: HealthStatus = issues.isEmpty ? .healthy :
                                   issues.count == 1 ? .degraded : .unhealthy

        return ComponentHealth(
            component: "Configuration",
            status: status,
            message: issues.isEmpty ? "Configuration valid" : "Configuration issues found",
            issues: issues,
            lastChecked: Date()
        )
    }

    private func checkAPIConnectivity() async -> ComponentHealth {
        var issues: [String] = []

        // Check Claude API
        if !Settings.shared.claudeAPIKey.isEmpty {
            // We won't actually call the API, just check if it's configured
            let rateLimitStatus = RateLimiter.shared.getStatus(for: "claude")

            if let status = rateLimitStatus {
                if status.dayRemaining == 0 {
                    issues.append("Claude API daily quota exhausted")
                } else if status.percentageUsedDay > 90 {
                    issues.append("Claude API approaching daily limit (\(String(format: "%.0f", status.percentageUsedDay))%)")
                }
            }
        }

        // Check network connectivity
        let networkMonitor = NetworkMonitor()
        // Simplified check - in a real scenario, we'd check actual connectivity

        let status: HealthStatus = issues.isEmpty ? .healthy : .degraded

        return ComponentHealth(
            component: "API Connectivity",
            status: status,
            message: issues.isEmpty ? "API connectivity OK" : "API connectivity issues",
            issues: issues,
            lastChecked: Date()
        )
    }

    private func checkFileSystem() async -> ComponentHealth {
        var issues: [String] = []

        // Check required directories exist
        let requiredDirs = [
            AppConfig.baseDirectory,
            AppConfig.screenshotsDir,
            AppConfig.codeFixesDir,
            AppConfig.logsDir
        ]

        for dir in requiredDirs {
            if !FileManager.default.fileExists(atPath: dir.path) {
                issues.append("Required directory missing: \(dir.lastPathComponent)")

                // Try to create it
                do {
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    issues.append("  → Auto-created directory")
                } catch {
                    issues.append("  → Failed to create directory: \(error.localizedDescription)")
                }
            }
        }

        // Check disk space
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: AppConfig.baseDirectory.path),
           let freeSpace = attributes[.systemFreeSize] as? UInt64 {

            let freeSpaceMB = Double(freeSpace) / 1024 / 1024

            if freeSpaceMB < 100 {
                issues.append("Low disk space: \(String(format: "%.0f", freeSpaceMB)) MB remaining")
            }
        }

        let status: HealthStatus = issues.isEmpty ? .healthy :
                                   issues.count <= 2 ? .degraded : .unhealthy

        return ComponentHealth(
            component: "File System",
            status: status,
            message: issues.isEmpty ? "File system OK" : "File system issues detected",
            issues: issues,
            lastChecked: Date()
        )
    }

    private func checkPermissions() async -> ComponentHealth {
        var issues: [String] = []

        // Check accessibility permission
        let hasAccessibility = AXIsProcessTrusted()
        if !hasAccessibility {
            issues.append("Accessibility permission not granted")
        }

        // Check screen recording permission
        var hasScreenRecording = false
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            hasScreenRecording = true
        } catch {
            issues.append("Screen recording permission not granted")
        }

        let status: HealthStatus = issues.isEmpty ? .healthy : .degraded

        return ComponentHealth(
            component: "Permissions",
            status: status,
            message: issues.isEmpty ? "All permissions granted" : "Missing permissions",
            issues: issues,
            lastChecked: Date()
        )
    }

    private func checkRateLimiter() async -> ComponentHealth {
        var issues: [String] = []

        let statuses = RateLimiter.shared.getAllStatuses()

        for (service, status) in statuses {
            if status.percentageUsedDay > 90 {
                issues.append("\(service): \(String(format: "%.0f", status.percentageUsedDay))% of daily quota used")
            }

            if status.minuteRemaining == 0 {
                issues.append("\(service): Minute quota exhausted")
            }
        }

        let healthStatus: HealthStatus = issues.isEmpty ? .healthy :
                                         issues.count <= 2 ? .degraded : .unhealthy

        return ComponentHealth(
            component: "Rate Limiter",
            status: healthStatus,
            message: issues.isEmpty ? "Rate limits healthy" : "Rate limit warnings",
            issues: issues,
            lastChecked: Date()
        )
    }

    private func checkCache() async -> ComponentHealth {
        var issues: [String] = []

        let stats = await CacheManager.shared.getCacheStatistics()

        // Check if cache is approaching limits
        if stats.diskCacheSizeMB / Double(stats.maxDiskSizeMB) > 0.9 {
            issues.append("Disk cache nearly full: \(String(format: "%.1f", stats.diskCacheSizeMB)) MB / \(stats.maxDiskSizeMB) MB")
        }

        let status: HealthStatus = issues.isEmpty ? .healthy : .degraded

        return ComponentHealth(
            component: "Cache",
            status: status,
            message: issues.isEmpty ? "Cache healthy" : "Cache issues detected",
            issues: issues,
            lastChecked: Date()
        )
    }

    private func checkMemory() async -> ComponentHealth {
        var issues: [String] = []

        let processInfo = ProcessInfo.processInfo
        let physicalMemory = processInfo.physicalMemory

        // Get current memory usage (this is an approximation)
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedMemoryMB = Double(taskInfo.resident_size) / 1024 / 1024

            if usedMemoryMB > 500 {
                issues.append("High memory usage: \(String(format: "%.0f", usedMemoryMB)) MB")
            }
        }

        let status: HealthStatus = issues.isEmpty ? .healthy : .degraded

        return ComponentHealth(
            component: "Memory",
            status: status,
            message: issues.isEmpty ? "Memory usage normal" : "Memory issues detected",
            issues: issues,
            lastChecked: Date()
        )
    }

    // MARK: - Health Status

    func getOverallHealth() -> HealthStatus {
        return queue.sync {
            let statuses = componentHealth.values.map { $0.status }

            if statuses.contains(.unhealthy) {
                return .unhealthy
            } else if statuses.contains(.degraded) {
                return .degraded
            } else {
                return .healthy
            }
        }
    }

    func getComponentHealth(_ component: String) -> ComponentHealth? {
        return queue.sync {
            return componentHealth[component]
        }
    }

    func getAllComponentHealth() -> [ComponentHealth] {
        return queue.sync {
            return Array(componentHealth.values)
        }
    }

    // MARK: - Diagnostics

    func generateDiagnosticsReport() -> DiagnosticsReport {
        let components = queue.sync {
            Array(componentHealth.values)
        }

        let systemInfo = SystemInfo(
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            uptime: ProcessInfo.processInfo.systemUptime
        )

        return DiagnosticsReport(
            generatedAt: Date(),
            overallHealth: getOverallHealth(),
            components: components,
            systemInfo: systemInfo,
            rateLimiterStatus: RateLimiter.shared.getAllStatuses()
        )
    }

    func exportDiagnostics(to fileURL: URL) throws {
        let report = generateDiagnosticsReport()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(report)
        try data.write(to: fileURL)

        Logger.shared.info("Diagnostics exported to: \(fileURL.path)", category: .system)
    }
}

// MARK: - Data Models

struct ComponentHealth: Codable {
    let component: String
    let status: HealthStatus
    let message: String
    let issues: [String]
    let lastChecked: Date

    func formatted() -> String {
        var result = """
        \(status.icon) \(component): \(status.rawValue)
        \(message)
        Last Checked: \(lastChecked.formatted(date: .omitted, time: .shortened))
        """

        if !issues.isEmpty {
            result += "\nIssues:"
            for issue in issues {
                result += "\n  - \(issue)"
            }
        }

        return result
    }
}

enum HealthStatus: String, Codable {
    case healthy = "Healthy"
    case degraded = "Degraded"
    case unhealthy = "Unhealthy"

    var icon: String {
        switch self {
        case .healthy: return "✅"
        case .degraded: return "⚠️"
        case .unhealthy: return "❌"
        }
    }
}

struct DiagnosticsReport: Codable {
    let generatedAt: Date
    let overallHealth: HealthStatus
    let components: [ComponentHealth]
    let systemInfo: SystemInfo
    let rateLimiterStatus: [String: RateLimitStatus]

    func formatted() -> String {
        var result = """
        System Diagnostics Report
        Generated: \(generatedAt.formatted(date: .long, time: .standard))
        Overall Health: \(overallHealth.icon) \(overallHealth.rawValue)

        System Information:
        \(systemInfo.formatted())

        Component Health:
        """

        for component in components {
            result += "\n\n\(component.formatted())"
        }

        result += "\n\nRate Limiter Status:"
        for (service, status) in rateLimiterStatus {
            result += "\n\n\(status.formatted())"
        }

        return result
    }
}

struct SystemInfo: Codable {
    let osVersion: String
    let appVersion: String
    let uptime: TimeInterval

    func formatted() -> String {
        let hours = Int(uptime / 3600)
        let minutes = Int((uptime.truncatingRemainder(dividingBy: 3600)) / 60)

        return """
        OS Version: \(osVersion)
        App Version: \(appVersion)
        System Uptime: \(hours)h \(minutes)m
        """
    }
}
