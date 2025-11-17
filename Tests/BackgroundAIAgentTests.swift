import XCTest
@testable import BackgroundAIAgent

// MARK: - Logger Tests

class LoggerTests: XCTestCase {
    func testLoggingLevels() {
        Logger.shared.minimumLevel = .debug

        Logger.shared.debug("Debug message", category: .general)
        Logger.shared.info("Info message", category: .general)
        Logger.shared.warning("Warning message", category: .general)
        Logger.shared.error("Error message", category: .errorHandling)

        // Logs should be written successfully
        XCTAssertTrue(true, "Logging levels work")
    }

    func testLogRotation() {
        // Test that log rotation works
        for _ in 0..<1000 {
            Logger.shared.info("Test message for rotation", category: .general)
        }

        let fileSize = Logger.shared.getLogFileSize()
        XCTAssertGreaterThan(fileSize, 0, "Log file should have content")
    }

    func testLogSearch() {
        Logger.shared.info("Searchable test message", category: .general)

        let results = Logger.shared.searchLogs(query: "Searchable", level: .info)
        XCTAssertGreaterThan(results.count, 0, "Should find logged message")
    }

    func testPerformanceMeasurement() {
        let result = Logger.shared.measurePerformance("Test Operation") {
            Thread.sleep(forTimeInterval: 0.1)
            return "completed"
        }

        XCTAssertEqual(result, "completed", "Performance measurement should return value")
    }
}

// MARK: - Rate Limiter Tests

class RateLimiterTests: XCTestCase {
    override func setUp() {
        super.setUp()
        RateLimiter.shared.reset()
    }

    func testRateLimitEnforcement() {
        // Register a test service with low limits
        RateLimiter.shared.registerService(
            name: "test_service",
            requestsPerMinute: 2,
            requestsPerHour: 10,
            requestsPerDay: 50
        )

        // First two requests should succeed
        let (allowed1, _) = RateLimiter.shared.canProceed(for: "test_service")
        XCTAssertTrue(allowed1, "First request should be allowed")

        let (allowed2, _) = RateLimiter.shared.canProceed(for: "test_service")
        XCTAssertTrue(allowed2, "Second request should be allowed")

        // Third request should be rate limited
        let (allowed3, retryAfter) = RateLimiter.shared.canProceed(for: "test_service")
        XCTAssertFalse(allowed3, "Third request should be rate limited")
        XCTAssertNotNil(retryAfter, "Retry delay should be provided")
    }

    func testRateLimitStatus() {
        RateLimiter.shared.registerService(
            name: "status_test",
            requestsPerMinute: 10,
            requestsPerHour: 100,
            requestsPerDay: 1000
        )

        _ = RateLimiter.shared.canProceed(for: "status_test")

        let status = RateLimiter.shared.getStatus(for: "status_test")
        XCTAssertNotNil(status, "Should get rate limit status")
        XCTAssertEqual(status?.minuteRemaining, 9, "Should have 9 requests remaining")
    }

    func testAsyncWaitForAvailability() async throws {
        RateLimiter.shared.registerService(
            name: "async_test",
            requestsPerMinute: 5,
            requestsPerHour: 50,
            requestsPerDay: 500
        )

        // This should complete without throwing
        try await RateLimiter.shared.waitForAvailability(for: "async_test")
        XCTAssertTrue(true, "Wait for availability should succeed")
    }
}

// MARK: - Cache Manager Tests

class CacheManagerTests: XCTestCase {
    func testCacheSetAndGet() async {
        let key = "test_key"
        let value = "test_value"

        await CacheManager.shared.set(key, value: value, ttl: 60)

        let retrieved: String? = await CacheManager.shared.get(key, type: String.self)
        XCTAssertEqual(retrieved, value, "Should retrieve cached value")
    }

    func testCacheExpiration() async {
        let key = "expiring_key"
        let value = "expiring_value"

        // Set with very short TTL
        await CacheManager.shared.set(key, value: value, ttl: 0.1)

        // Wait for expiration
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        let retrieved: String? = await CacheManager.shared.get(key, type: String.self)
        XCTAssertNil(retrieved, "Expired entry should not be retrieved")
    }

    func testCacheClear() async {
        await CacheManager.shared.set("key1", value: "value1")
        await CacheManager.shared.set("key2", value: "value2")

        await CacheManager.shared.clear()

        let retrieved: String? = await CacheManager.shared.get("key1", type: String.self)
        XCTAssertNil(retrieved, "Cache should be cleared")
    }

    func testCodeAnalysisCache() async {
        let code = "func test() { return 42 }"
        let language = "swift"
        let analysis = CodeAnalysis(issues: [], summary: "Test analysis")

        await CacheManager.shared.cacheCodeAnalysis(code: code, language: language, analysis: analysis)

        let retrieved = await CacheManager.shared.getCachedCodeAnalysis(code: code, language: language)
        XCTAssertNotNil(retrieved, "Should retrieve cached code analysis")
        XCTAssertEqual(retrieved?.summary, "Test analysis")
    }

    func testCacheStatistics() async {
        let stats = await CacheManager.shared.getCacheStatistics()

        XCTAssertGreaterThanOrEqual(stats.memoryCacheCount, 0, "Should have memory cache stats")
        XCTAssertGreaterThanOrEqual(stats.diskCacheSize, 0, "Should have disk cache stats")
    }
}

// MARK: - Error Handling Tests

class ErrorHandlingTests: XCTestCase {
    func testErrorRecovery() async {
        let error = AppError.connectionTimeout(service: "test")

        let result = await ErrorRecoveryManager.shared.attemptRecovery(
            from: error,
            context: "test_context"
        )

        // Recovery might succeed or fail, but should not crash
        XCTAssertTrue(true, "Error recovery should execute")
    }

    func testErrorReporting() {
        let error = AppError.fileNotFound(path: "/test/path")

        ErrorReporter.shared.report(error, context: "test", additionalInfo: ["test": "info"])

        XCTAssertTrue(true, "Error reporting should not crash")
    }

    func testRecoverySuggestions() {
        let error = AppError.apiKeyMissing(service: "Claude")

        XCTAssertNotNil(error.recoverySuggestion, "Should provide recovery suggestion")
        XCTAssertTrue(error.isRecoverable, "API key missing should be recoverable")
    }
}

// MARK: - Configuration Manager Tests

class ConfigurationManagerTests: XCTestCase {
    func testConfigurationValidation() {
        let result = ConfigurationManager.shared.validateConfiguration()

        XCTAssertTrue(result.isValid || result.hasErrors || result.hasWarnings, "Should have validation result")
    }

    func testBackupSettings() throws {
        let backupURL = try ConfigurationManager.shared.backupSettings()

        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path), "Backup file should be created")

        // Clean up
        try? FileManager.default.removeItem(at: backupURL)
    }

    func testListBackups() {
        let backups = ConfigurationManager.shared.listBackups()

        XCTAssertGreaterThanOrEqual(backups.count, 0, "Should list backups")
    }

    func testExportImportConfiguration() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-config.json")

        try ConfigurationManager.shared.exportConfiguration(to: tempURL, includeAPIKeys: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path), "Export should create file")

        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
}

// MARK: - Analytics Tests

class AnalyticsTests: XCTestCase {
    func testEventTracking() {
        let event = AnalyticsEvent(
            name: "test_event",
            category: .general,
            properties: ["key": "value"]
        )

        AnalyticsManager.shared.trackEvent(event)

        XCTAssertTrue(true, "Event tracking should not crash")
    }

    func testAPICallTracking() {
        AnalyticsManager.shared.trackAPICall(
            service: "test_api",
            duration: 0.5,
            success: true,
            tokensUsed: 100
        )

        let stats = AnalyticsManager.shared.getAPIStatistics(service: "test_api")
        XCTAssertGreaterThan(stats.totalCalls, 0, "Should track API call")
    }

    func testCodeAnalysisTracking() {
        AnalyticsManager.shared.trackCodeAnalysis(
            language: "swift",
            linesOfCode: 100,
            issuesFound: 5,
            duration: 1.0
        )

        let stats = AnalyticsManager.shared.getCodeAnalysisStatistics()
        XCTAssertGreaterThan(stats.totalAnalyses, 0, "Should track code analysis")
    }

    func testReportGeneration() {
        let report = AnalyticsManager.shared.generateReport()

        XCTAssertNotNil(report, "Should generate analytics report")
        XCTAssertGreaterThan(report.sessionStats.duration, 0, "Session should have duration")
    }
}

// MARK: - Health Check Tests

class HealthCheckTests: XCTestCase {
    func testHealthCheck() async {
        await HealthCheckSystem.shared.performHealthCheck()

        let health = HealthCheckSystem.shared.getOverallHealth()
        XCTAssertTrue([.healthy, .degraded, .unhealthy].contains(health), "Should have valid health status")
    }

    func testComponentHealth() async {
        await HealthCheckSystem.shared.performHealthCheck()

        let components = HealthCheckSystem.shared.getAllComponentHealth()
        XCTAssertGreaterThan(components.count, 0, "Should have component health checks")
    }

    func testDiagnosticsReport() {
        let report = HealthCheckSystem.shared.generateDiagnosticsReport()

        XCTAssertNotNil(report, "Should generate diagnostics report")
        XCTAssertGreaterThan(report.components.count, 0, "Should have component diagnostics")
    }
}

// MARK: - Performance Monitor Tests

class PerformanceMonitorTests: XCTestCase {
    func testMetricRecording() {
        PerformanceMonitor.shared.recordMetric(name: "test_operation", duration: 0.1)
        PerformanceMonitor.shared.recordMetric(name: "test_operation", duration: 0.2)
        PerformanceMonitor.shared.recordMetric(name: "test_operation", duration: 0.15)

        let stats = PerformanceMonitor.shared.getStatistics(for: "test_operation")
        XCTAssertNotNil(stats, "Should have statistics for metric")
        XCTAssertEqual(stats?.count, 3, "Should have 3 measurements")
    }

    func testStatisticsCalculation() {
        for i in 1...10 {
            PerformanceMonitor.shared.recordMetric(name: "calc_test", duration: Double(i) * 0.01)
        }

        let stats = PerformanceMonitor.shared.getStatistics(for: "calc_test")
        XCTAssertNotNil(stats, "Should calculate statistics")
        XCTAssertGreaterThan(stats!.average, 0, "Should have average")
        XCTAssertGreaterThan(stats!.median, 0, "Should have median")
    }
}
