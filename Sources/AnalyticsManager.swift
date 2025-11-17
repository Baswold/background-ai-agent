import Foundation

// MARK: - Comprehensive Analytics System

/// Tracks and analyzes agent performance and usage
class AnalyticsManager {
    static let shared = AnalyticsManager()

    private let metricsStore: MetricsStore
    private let queue = DispatchQueue(label: "com.backgroundai.analytics", qos: .utility)

    private init() {
        metricsStore = MetricsStore()
        Logger.shared.info("Analytics manager initialized", category: .system)
    }

    // MARK: - Event Tracking

    func trackEvent(_ event: AnalyticsEvent) {
        queue.async { [weak self] in
            self?.metricsStore.recordEvent(event)
        }

        Logger.shared.verbose("Event tracked: \(event.name)", category: .general)
    }

    func trackAPICall(service: String, duration: TimeInterval, success: Bool, tokensUsed: Int? = nil) {
        let event = AnalyticsEvent(
            name: "api_call",
            category: .api,
            properties: [
                "service": service,
                "duration_ms": duration * 1000,
                "success": success,
                "tokens_used": tokensUsed as Any
            ]
        )

        trackEvent(event)

        // Record performance metric
        PerformanceMonitor.shared.recordMetric(name: "api_\(service)", duration: duration)
    }

    func trackCodeAnalysis(language: String, linesOfCode: Int, issuesFound: Int, duration: TimeInterval) {
        let event = AnalyticsEvent(
            name: "code_analysis",
            category: .codeAnalysis,
            properties: [
                "language": language,
                "lines_of_code": linesOfCode,
                "issues_found": issuesFound,
                "duration_ms": duration * 1000
            ]
        )

        trackEvent(event)
    }

    func trackScreenshotCapture(success: Bool, ocrExtracted: Bool, duration: TimeInterval) {
        let event = AnalyticsEvent(
            name: "screenshot_capture",
            category: .screenshot,
            properties: [
                "success": success,
                "ocr_extracted": ocrExtracted,
                "duration_ms": duration * 1000
            ]
        )

        trackEvent(event)
    }

    func trackCacheHit(cacheType: String, key: String) {
        let event = AnalyticsEvent(
            name: "cache_hit",
            category: .performance,
            properties: [
                "cache_type": cacheType,
                "key": key
            ]
        )

        trackEvent(event)
    }

    func trackError(error: AppError, context: String, recovered: Bool) {
        let event = AnalyticsEvent(
            name: "error",
            category: .error,
            properties: [
                "error_type": String(describing: type(of: error)),
                "context": context,
                "recovered": recovered,
                "description": error.description
            ]
        )

        trackEvent(event)
    }

    // MARK: - Session Tracking

    func startSession() {
        let event = AnalyticsEvent(
            name: "session_start",
            category: .session,
            properties: [:]
        )

        trackEvent(event)
    }

    func endSession() {
        let stats = getSessionStatistics()

        let event = AnalyticsEvent(
            name: "session_end",
            category: .session,
            properties: [
                "duration": stats.duration,
                "events_tracked": stats.totalEvents,
                "api_calls": stats.apiCalls,
                "errors": stats.errors
            ]
        )

        trackEvent(event)
    }

    // MARK: - Statistics

    func getSessionStatistics() -> SessionStatistics {
        return queue.sync {
            return metricsStore.getSessionStatistics()
        }
    }

    func getDailyStatistics() -> DailyStatistics {
        return queue.sync {
            return metricsStore.getDailyStatistics()
        }
    }

    func getAPIStatistics(service: String) -> APIStatistics {
        return queue.sync {
            return metricsStore.getAPIStatistics(for: service)
        }
    }

    func getCodeAnalysisStatistics() -> CodeAnalysisStatistics {
        return queue.sync {
            return metricsStore.getCodeAnalysisStatistics()
        }
    }

    // MARK: - Reports

    func generateReport() -> AnalyticsReport {
        return queue.sync {
            let session = metricsStore.getSessionStatistics()
            let daily = metricsStore.getDailyStatistics()
            let performance = PerformanceMonitor.shared.getAllStatistics()

            return AnalyticsReport(
                sessionStats: session,
                dailyStats: daily,
                performanceMetrics: performance,
                generatedAt: Date()
            )
        }
    }

    func exportMetrics(to fileURL: URL) throws {
        let report = generateReport()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(report)
        try data.write(to: fileURL)

        Logger.shared.info("Metrics exported to: \(fileURL.path)", category: .system)
    }
}

// MARK: - Metrics Store

private class MetricsStore {
    private var events: [AnalyticsEvent] = []
    private let maxStoredEvents = 10000
    private let sessionStartTime = Date()

    func recordEvent(_ event: AnalyticsEvent) {
        events.append(event)

        // Limit stored events
        if events.count > maxStoredEvents {
            events.removeFirst(events.count - maxStoredEvents)
        }
    }

    func getSessionStatistics() -> SessionStatistics {
        let now = Date()
        let duration = now.timeIntervalSince(sessionStartTime)

        return SessionStatistics(
            startTime: sessionStartTime,
            duration: duration,
            totalEvents: events.count,
            apiCalls: events.filter { $0.category == .api }.count,
            errors: events.filter { $0.category == .error }.count,
            codeAnalyses: events.filter { $0.category == .codeAnalysis }.count,
            screenshots: events.filter { $0.category == .screenshot }.count
        )
    }

    func getDailyStatistics() -> DailyStatistics {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let todayEvents = events.filter { event in
            calendar.isDate(event.timestamp, inSameDayAs: today)
        }

        return DailyStatistics(
            date: today,
            totalEvents: todayEvents.count,
            apiCalls: todayEvents.filter { $0.category == .api }.count,
            codeAnalyses: todayEvents.filter { $0.category == .codeAnalysis }.count,
            errors: todayEvents.filter { $0.category == .error }.count,
            cacheHits: todayEvents.filter { $0.name == "cache_hit" }.count
        )
    }

    func getAPIStatistics(for service: String) -> APIStatistics {
        let apiEvents = events.filter { event in
            event.name == "api_call" &&
            event.properties["service"] as? String == service
        }

        let successfulCalls = apiEvents.filter { event in
            event.properties["success"] as? Bool == true
        }.count

        let totalTokens = apiEvents.compactMap { event in
            event.properties["tokens_used"] as? Int
        }.reduce(0, +)

        let durations = apiEvents.compactMap { event in
            event.properties["duration_ms"] as? Double
        }

        let avgDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)

        return APIStatistics(
            service: service,
            totalCalls: apiEvents.count,
            successfulCalls: successfulCalls,
            failedCalls: apiEvents.count - successfulCalls,
            totalTokensUsed: totalTokens,
            averageDurationMs: avgDuration
        )
    }

    func getCodeAnalysisStatistics() -> CodeAnalysisStatistics {
        let analysisEvents = events.filter { $0.name == "code_analysis" }

        let totalIssues = analysisEvents.compactMap { event in
            event.properties["issues_found"] as? Int
        }.reduce(0, +)

        var languageBreakdown: [String: Int] = [:]
        for event in analysisEvents {
            if let language = event.properties["language"] as? String {
                languageBreakdown[language, default: 0] += 1
            }
        }

        return CodeAnalysisStatistics(
            totalAnalyses: analysisEvents.count,
            totalIssuesFound: totalIssues,
            languageBreakdown: languageBreakdown
        )
    }
}

// MARK: - Data Models

struct AnalyticsEvent: Codable {
    let id = UUID()
    let name: String
    let category: EventCategory
    let timestamp = Date()
    let properties: [String: AnyCodableValue]

    init(name: String, category: EventCategory, properties: [String: Any]) {
        self.name = name
        self.category = category
        self.properties = properties.mapValues { AnyCodableValue($0) }
    }
}

enum EventCategory: String, Codable {
    case session
    case api
    case codeAnalysis
    case screenshot
    case clipboard
    case performance
    case error
    case ui
}

// Wrapper for encoding Any values
struct AnyCodableValue: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else {
            value = "null"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else {
            try container.encodeNil()
        }
    }
}

struct SessionStatistics: Codable {
    let startTime: Date
    let duration: TimeInterval
    let totalEvents: Int
    let apiCalls: Int
    let errors: Int
    let codeAnalyses: Int
    let screenshots: Int

    func formatted() -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)

        return """
        Session Statistics:
        Duration: \(hours)h \(minutes)m
        Total Events: \(totalEvents)
        API Calls: \(apiCalls)
        Code Analyses: \(codeAnalyses)
        Screenshots: \(screenshots)
        Errors: \(errors)
        """
    }
}

struct DailyStatistics: Codable {
    let date: Date
    let totalEvents: Int
    let apiCalls: Int
    let codeAnalyses: Int
    let errors: Int
    let cacheHits: Int

    func formatted() -> String {
        return """
        Daily Statistics:
        Date: \(date.formatted(date: .abbreviated, time: .omitted))
        Events: \(totalEvents)
        API Calls: \(apiCalls)
        Code Analyses: \(codeAnalyses)
        Cache Hits: \(cacheHits)
        Errors: \(errors)
        """
    }
}

struct APIStatistics: Codable {
    let service: String
    let totalCalls: Int
    let successfulCalls: Int
    let failedCalls: Int
    let totalTokensUsed: Int
    let averageDurationMs: Double

    var successRate: Double {
        guard totalCalls > 0 else { return 0 }
        return Double(successfulCalls) / Double(totalCalls) * 100
    }

    func formatted() -> String {
        return """
        API Statistics (\(service)):
        Total Calls: \(totalCalls)
        Success Rate: \(String(format: "%.1f", successRate))%
        Tokens Used: \(totalTokensUsed)
        Avg Duration: \(String(format: "%.1f", averageDurationMs))ms
        """
    }
}

struct CodeAnalysisStatistics: Codable {
    let totalAnalyses: Int
    let totalIssuesFound: Int
    let languageBreakdown: [String: Int]

    func formatted() -> String {
        var result = """
        Code Analysis Statistics:
        Total Analyses: \(totalAnalyses)
        Issues Found: \(totalIssuesFound)

        By Language:
        """

        for (language, count) in languageBreakdown.sorted(by: { $0.value > $1.value }) {
            result += "\n  \(language): \(count)"
        }

        return result
    }
}

struct AnalyticsReport: Codable {
    let sessionStats: SessionStatistics
    let dailyStats: DailyStatistics
    let performanceMetrics: [String: MetricStatistics]
    let generatedAt: Date

    func formatted() -> String {
        var result = """
        Analytics Report
        Generated: \(generatedAt.formatted(date: .long, time: .standard))

        \(sessionStats.formatted())

        \(dailyStats.formatted())

        Performance Metrics:
        """

        for (_, stats) in performanceMetrics.sorted(by: { $0.key < $1.key }) {
            result += "\n\n\(stats.formatted())"
        }

        return result
    }
}
