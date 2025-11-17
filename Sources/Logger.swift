import Foundation
import os.log

// MARK: - Advanced Logging System

/// Comprehensive logging system with levels, categories, and rotation
class Logger {
    static let shared = Logger()

    private let logsDirectory: URL
    private let currentLogFile: URL
    private let maxLogFileSize: UInt64 = 10 * 1024 * 1024 // 10 MB
    private let maxLogFiles = 5
    private let queue = DispatchQueue(label: "com.backgroundai.logger", qos: .utility)

    // OS logging for system console
    private let osLog = OSLog(subsystem: "com.backgroundai.agent", category: "general")

    // Configuration
    var minimumLevel: LogLevel = .info
    var enableConsoleOutput = true
    var enableFileOutput = true
    var enableOSLog = true

    private init() {
        logsDirectory = AppConfig.logsDir
        currentLogFile = logsDirectory.appendingPathComponent("app.log")

        // Ensure logs directory exists
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        // Rotate logs on initialization if needed
        rotateLogsIfNeeded()
    }

    // MARK: - Public Logging Methods

    func verbose(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .verbose, category: category, file: file, function: function, line: line)
    }

    func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    func error(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }

    func critical(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }

    // MARK: - Performance Logging

    func measurePerformance<T>(_ operation: String, category: LogCategory = .performance, block: () throws -> T) rethrows -> T {
        let start = Date()
        defer {
            let duration = Date().timeIntervalSince(start)
            info("⏱️ \(operation) took \(String(format: "%.2f", duration * 1000))ms", category: category)
        }
        return try block()
    }

    func measurePerformanceAsync<T>(_ operation: String, category: LogCategory = .performance, block: () async throws -> T) async rethrows -> T {
        let start = Date()
        defer {
            let duration = Date().timeIntervalSince(start)
            info("⏱️ \(operation) took \(String(format: "%.2f", duration * 1000))ms", category: category)
        }
        return try await block()
    }

    // MARK: - Core Logging

    private func log(_ message: String, level: LogLevel, category: LogCategory, file: String, function: String, line: Int) {
        guard level.rawValue >= minimumLevel.rawValue else { return }

        let fileName = (file as NSString).lastPathComponent
        let logEntry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            file: fileName,
            function: function,
            line: line
        )

        queue.async { [weak self] in
            self?.processLogEntry(logEntry)
        }
    }

    private func processLogEntry(_ entry: LogEntry) {
        let formattedMessage = formatLogEntry(entry)

        // Console output
        if enableConsoleOutput {
            print(formattedMessage)
        }

        // File output
        if enableFileOutput {
            writeToFile(formattedMessage)
        }

        // OS Log
        if enableOSLog {
            writeToOSLog(entry)
        }
    }

    // MARK: - Formatting

    private func formatLogEntry(_ entry: LogEntry) -> String {
        let timestamp = formatTimestamp(entry.timestamp)
        let levelIcon = entry.level.icon
        let categoryIcon = entry.category.icon

        let location = "[\(entry.file):\(entry.line)]"

        return "\(timestamp) \(levelIcon) \(categoryIcon) [\(entry.category.rawValue)] \(entry.message) \(location)"
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    // MARK: - File Operations

    private func writeToFile(_ message: String) {
        let messageWithNewline = message + "\n"

        guard let data = messageWithNewline.data(using: .utf8) else { return }

        // Check if rotation is needed
        rotateLogsIfNeeded()

        // Append to current log file
        if FileManager.default.fileExists(atPath: currentLogFile.path) {
            if let fileHandle = try? FileHandle(forWritingTo: currentLogFile) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: currentLogFile)
        }
    }

    private func rotateLogsIfNeeded() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: currentLogFile.path),
              let fileSize = attributes[.size] as? UInt64 else {
            return
        }

        guard fileSize >= maxLogFileSize else { return }

        // Rotate existing logs
        for index in (1..<maxLogFiles).reversed() {
            let oldFile = logsDirectory.appendingPathComponent("app.\(index).log")
            let newFile = logsDirectory.appendingPathComponent("app.\(index + 1).log")

            if FileManager.default.fileExists(atPath: oldFile.path) {
                try? FileManager.default.removeItem(at: newFile)
                try? FileManager.default.moveItem(at: oldFile, to: newFile)
            }
        }

        // Move current log to .1
        let rotatedFile = logsDirectory.appendingPathComponent("app.1.log")
        try? FileManager.default.removeItem(at: rotatedFile)
        try? FileManager.default.moveItem(at: currentLogFile, to: rotatedFile)

        info("📋 Log file rotated", category: .system)
    }

    // MARK: - OS Log

    private func writeToOSLog(_ entry: LogEntry) {
        let message = "\(entry.category.icon) [\(entry.category.rawValue)] \(entry.message)"

        switch entry.level {
        case .verbose, .debug:
            os_log(.debug, log: osLog, "%{public}@", message)
        case .info:
            os_log(.info, log: osLog, "%{public}@", message)
        case .warning:
            os_log(.default, log: osLog, "%{public}@", message)
        case .error:
            os_log(.error, log: osLog, "%{public}@", message)
        case .critical:
            os_log(.fault, log: osLog, "%{public}@", message)
        }
    }

    // MARK: - Log Analysis

    func searchLogs(query: String, level: LogLevel? = nil, category: LogCategory? = nil) -> [String] {
        guard let content = try? String(contentsOf: currentLogFile, encoding: .utf8) else {
            return []
        }

        var lines = content.components(separatedBy: "\n")

        // Filter by level
        if let level = level {
            lines = lines.filter { $0.contains(level.icon) }
        }

        // Filter by category
        if let category = category {
            lines = lines.filter { $0.contains("[\(category.rawValue)]") }
        }

        // Filter by query
        if !query.isEmpty {
            lines = lines.filter { $0.localizedCaseInsensitiveContains(query) }
        }

        return lines
    }

    func getRecentLogs(count: Int = 100) -> [String] {
        guard let content = try? String(contentsOf: currentLogFile, encoding: .utf8) else {
            return []
        }

        let lines = content.components(separatedBy: "\n")
        return Array(lines.suffix(count))
    }

    func clearLogs() {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Remove all log files
            try? FileManager.default.removeItem(at: self.currentLogFile)

            for index in 1...self.maxLogFiles {
                let logFile = self.logsDirectory.appendingPathComponent("app.\(index).log")
                try? FileManager.default.removeItem(at: logFile)
            }

            self.info("🗑️ Logs cleared", category: .system)
        }
    }

    func getLogFileSize() -> UInt64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: currentLogFile.path),
              let fileSize = attributes[.size] as? UInt64 else {
            return 0
        }
        return fileSize
    }
}

// MARK: - Log Entry

private struct LogEntry {
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let file: String
    let function: String
    let line: Int
}

// MARK: - Log Level

enum LogLevel: Int, Comparable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5

    var icon: String {
        switch self {
        case .verbose: return "💬"
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🔥"
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Log Category

enum LogCategory: String {
    case general = "General"
    case system = "System"
    case network = "Network"
    case ai = "AI"
    case fileSystem = "FileSystem"
    case github = "GitHub"
    case screenshot = "Screenshot"
    case clipboard = "Clipboard"
    case productivity = "Productivity"
    case security = "Security"
    case performance = "Performance"
    case errorHandling = "ErrorHandling"
    case configuration = "Configuration"

    var icon: String {
        switch self {
        case .general: return "📱"
        case .system: return "⚙️"
        case .network: return "🌐"
        case .ai: return "🤖"
        case .fileSystem: return "📁"
        case .github: return "🐙"
        case .screenshot: return "📸"
        case .clipboard: return "📋"
        case .productivity: return "📊"
        case .security: return "🔒"
        case .performance: return "⏱️"
        case .errorHandling: return "🚨"
        case .configuration: return "🔧"
        }
    }
}

// MARK: - Performance Monitor

class PerformanceMonitor {
    static let shared = PerformanceMonitor()

    private var metrics: [String: [TimeInterval]] = [:]
    private let queue = DispatchQueue(label: "com.backgroundai.performance")

    func recordMetric(name: String, duration: TimeInterval) {
        queue.async { [weak self] in
            self?.metrics[name, default: []].append(duration)

            // Keep only last 100 measurements
            if let count = self?.metrics[name]?.count, count > 100 {
                self?.metrics[name]?.removeFirst()
            }
        }
    }

    func getStatistics(for metric: String) -> MetricStatistics? {
        return queue.sync {
            guard let durations = metrics[metric], !durations.isEmpty else {
                return nil
            }

            let sorted = durations.sorted()
            let count = durations.count

            return MetricStatistics(
                name: metric,
                count: count,
                average: durations.reduce(0, +) / Double(count),
                median: sorted[count / 2],
                min: sorted.first!,
                max: sorted.last!,
                p95: sorted[Int(Double(count) * 0.95)],
                p99: sorted[Int(Double(count) * 0.99)]
            )
        }
    }

    func getAllStatistics() -> [String: MetricStatistics] {
        return queue.sync {
            var result: [String: MetricStatistics] = [:]
            for (name, _) in metrics {
                if let stats = getStatistics(for: name) {
                    result[name] = stats
                }
            }
            return result
        }
    }
}

struct MetricStatistics {
    let name: String
    let count: Int
    let average: TimeInterval
    let median: TimeInterval
    let min: TimeInterval
    let max: TimeInterval
    let p95: TimeInterval
    let p99: TimeInterval

    func formatted() -> String {
        """
        Metric: \(name)
        Samples: \(count)
        Average: \(String(format: "%.2f", average * 1000))ms
        Median: \(String(format: "%.2f", median * 1000))ms
        Min: \(String(format: "%.2f", min * 1000))ms
        Max: \(String(format: "%.2f", max * 1000))ms
        P95: \(String(format: "%.2f", p95 * 1000))ms
        P99: \(String(format: "%.2f", p99 * 1000))ms
        """
    }
}
