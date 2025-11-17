import Foundation

// MARK: - Rate Limiting System

/// Token bucket rate limiter with per-service tracking
class RateLimiter {
    static let shared = RateLimiter()

    private var buckets: [String: TokenBucket] = [:]
    private let queue = DispatchQueue(label: "com.backgroundai.ratelimiter")

    private init() {
        setupDefaultLimits()
    }

    private func setupDefaultLimits() {
        // Claude API limits (adjust based on your plan)
        registerService(
            name: "claude",
            requestsPerMinute: 50,
            requestsPerHour: 1000,
            requestsPerDay: 10000
        )

        // GitHub API limits
        registerService(
            name: "github",
            requestsPerMinute: 60,
            requestsPerHour: 5000,
            requestsPerDay: 5000
        )

        // OCR/Vision processing (local, but still want to limit)
        registerService(
            name: "ocr",
            requestsPerMinute: 30,
            requestsPerHour: 500,
            requestsPerDay: 2000
        )

        // Screenshot capture
        registerService(
            name: "screenshot",
            requestsPerMinute: 10,
            requestsPerHour: 100,
            requestsPerDay: 500
        )
    }

    func registerService(name: String, requestsPerMinute: Int, requestsPerHour: Int, requestsPerDay: Int) {
        queue.sync {
            buckets[name] = TokenBucket(
                name: name,
                requestsPerMinute: requestsPerMinute,
                requestsPerHour: requestsPerHour,
                requestsPerDay: requestsPerDay
            )
        }

        Logger.shared.debug("Registered rate limit for \(name): \(requestsPerMinute)/min, \(requestsPerHour)/hr, \(requestsPerDay)/day", category: .configuration)
    }

    /// Check if a request can proceed for the given service
    func canProceed(for service: String) -> (allowed: Bool, retryAfter: TimeInterval?) {
        return queue.sync {
            guard let bucket = buckets[service] else {
                Logger.shared.warning("No rate limit configured for service: \(service)", category: .configuration)
                return (true, nil)
            }

            return bucket.consumeToken()
        }
    }

    /// Wait until a request can proceed (async)
    func waitForAvailability(for service: String) async throws {
        let (allowed, retryAfter) = canProceed(for: service)

        guard !allowed else { return }

        guard let delay = retryAfter else {
            throw AppError.apiRateLimitExceeded(service: service, retryAfter: nil)
        }

        Logger.shared.warning("Rate limit exceeded for \(service). Waiting \(String(format: "%.1f", delay))s", category: .network)

        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        // Try again after waiting
        let (stillAllowed, _) = canProceed(for: service)
        if !stillAllowed {
            throw AppError.apiRateLimitExceeded(service: service, retryAfter: delay)
        }
    }

    /// Execute a request with rate limiting
    func execute<T>(
        for service: String,
        operation: () async throws -> T
    ) async throws -> T {
        try await waitForAvailability(for: service)
        return try await operation()
    }

    /// Get current status for a service
    func getStatus(for service: String) -> RateLimitStatus? {
        return queue.sync {
            guard let bucket = buckets[service] else { return nil }
            return bucket.getStatus()
        }
    }

    /// Get status for all services
    func getAllStatuses() -> [String: RateLimitStatus] {
        return queue.sync {
            var statuses: [String: RateLimitStatus] = [:]
            for (name, bucket) in buckets {
                statuses[name] = bucket.getStatus()
            }
            return statuses
        }
    }

    /// Reset all rate limiters (useful for testing)
    func reset() {
        queue.sync {
            for bucket in buckets.values {
                bucket.reset()
            }
        }
    }
}

// MARK: - Token Bucket Implementation

private class TokenBucket {
    let name: String

    // Limits
    let requestsPerMinute: Int
    let requestsPerHour: Int
    let requestsPerDay: Int

    // Tracking
    private var minuteTokens: Int
    private var hourTokens: Int
    private var dayTokens: Int

    private var lastMinuteReset: Date
    private var lastHourReset: Date
    private var lastDayReset: Date

    init(name: String, requestsPerMinute: Int, requestsPerHour: Int, requestsPerDay: Int) {
        self.name = name
        self.requestsPerMinute = requestsPerMinute
        self.requestsPerHour = requestsPerHour
        self.requestsPerDay = requestsPerDay

        self.minuteTokens = requestsPerMinute
        self.hourTokens = requestsPerHour
        self.dayTokens = requestsPerDay

        let now = Date()
        self.lastMinuteReset = now
        self.lastHourReset = now
        self.lastDayReset = now
    }

    func consumeToken() -> (allowed: Bool, retryAfter: TimeInterval?) {
        let now = Date()

        // Refill tokens if time windows have passed
        refillTokens(at: now)

        // Check if we have tokens available
        guard minuteTokens > 0, hourTokens > 0, dayTokens > 0 else {
            return (false, calculateRetryDelay(at: now))
        }

        // Consume tokens
        minuteTokens -= 1
        hourTokens -= 1
        dayTokens -= 1

        return (true, nil)
    }

    private func refillTokens(at now: Date) {
        // Refill minute bucket
        if now.timeIntervalSince(lastMinuteReset) >= 60 {
            minuteTokens = requestsPerMinute
            lastMinuteReset = now
        }

        // Refill hour bucket
        if now.timeIntervalSince(lastHourReset) >= 3600 {
            hourTokens = requestsPerHour
            lastHourReset = now
        }

        // Refill day bucket
        if now.timeIntervalSince(lastDayReset) >= 86400 {
            dayTokens = requestsPerDay
            lastDayReset = now
        }
    }

    private func calculateRetryDelay(at now: Date) -> TimeInterval {
        var delays: [TimeInterval] = []

        if minuteTokens <= 0 {
            delays.append(60 - now.timeIntervalSince(lastMinuteReset))
        }

        if hourTokens <= 0 {
            delays.append(3600 - now.timeIntervalSince(lastHourReset))
        }

        if dayTokens <= 0 {
            delays.append(86400 - now.timeIntervalSince(lastDayReset))
        }

        return delays.min() ?? 60
    }

    func getStatus() -> RateLimitStatus {
        let now = Date()
        refillTokens(at: now)

        return RateLimitStatus(
            service: name,
            minuteRemaining: minuteTokens,
            minuteLimit: requestsPerMinute,
            hourRemaining: hourTokens,
            hourLimit: requestsPerHour,
            dayRemaining: dayTokens,
            dayLimit: requestsPerDay
        )
    }

    func reset() {
        let now = Date()
        minuteTokens = requestsPerMinute
        hourTokens = requestsPerHour
        dayTokens = requestsPerDay
        lastMinuteReset = now
        lastHourReset = now
        lastDayReset = now
    }
}

// MARK: - Rate Limit Status

struct RateLimitStatus: Codable {
    let service: String
    let minuteRemaining: Int
    let minuteLimit: Int
    let hourRemaining: Int
    let hourLimit: Int
    let dayRemaining: Int
    let dayLimit: Int

    var percentageUsedMinute: Double {
        Double(minuteLimit - minuteRemaining) / Double(minuteLimit) * 100
    }

    var percentageUsedHour: Double {
        Double(hourLimit - hourRemaining) / Double(hourLimit) * 100
    }

    var percentageUsedDay: Double {
        Double(dayLimit - dayRemaining) / Double(dayLimit) * 100
    }

    func formatted() -> String {
        """
        Service: \(service)
        Minute: \(minuteRemaining)/\(minuteLimit) (\(String(format: "%.1f", percentageUsedMinute))% used)
        Hour: \(hourRemaining)/\(hourLimit) (\(String(format: "%.1f", percentageUsedHour))% used)
        Day: \(dayRemaining)/\(dayLimit) (\(String(format: "%.1f", percentageUsedDay))% used)
        """
    }
}

// MARK: - Request Queue Manager

/// Manages queued requests with priority
class RequestQueueManager {
    static let shared = RequestQueueManager()

    private var queues: [String: PriorityQueue<QueuedRequest>] = [:]
    private let queue = DispatchQueue(label: "com.backgroundai.requestqueue")
    private var isProcessing: [String: Bool] = [:]

    private init() {}

    func enqueue(
        service: String,
        priority: RequestPriority = .normal,
        operation: @escaping () async throws -> Void
    ) {
        queue.async { [weak self] in
            guard let self = self else { return }

            if self.queues[service] == nil {
                self.queues[service] = PriorityQueue<QueuedRequest>()
            }

            let request = QueuedRequest(
                id: UUID(),
                service: service,
                priority: priority,
                operation: operation,
                enqueuedAt: Date()
            )

            self.queues[service]?.enqueue(request, priority: priority.rawValue)

            // Start processing if not already running
            if self.isProcessing[service] != true {
                Task {
                    await self.processQueue(for: service)
                }
            }
        }
    }

    private func processQueue(for service: String) async {
        queue.sync {
            isProcessing[service] = true
        }

        defer {
            queue.sync {
                isProcessing[service] = false
            }
        }

        while true {
            let request: QueuedRequest? = queue.sync {
                return queues[service]?.dequeue()
            }

            guard let request = request else {
                break
            }

            let waitTime = Date().timeIntervalSince(request.enqueuedAt)
            Logger.shared.debug("Processing queued request for \(service) (waited \(String(format: "%.1f", waitTime))s)", category: .network)

            do {
                try await RateLimiter.shared.waitForAvailability(for: service)
                try await request.operation()
            } catch {
                Logger.shared.error("Queued request failed for \(service): \(error)", category: .network)
            }
        }
    }

    func getQueueSize(for service: String) -> Int {
        return queue.sync {
            return queues[service]?.count ?? 0
        }
    }
}

// MARK: - Supporting Types

private struct QueuedRequest {
    let id: UUID
    let service: String
    let priority: RequestPriority
    let operation: () async throws -> Void
    let enqueuedAt: Date
}

enum RequestPriority: Int {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
}

// MARK: - Simple Priority Queue

private struct PriorityQueue<T> {
    private var elements: [(T, Int)] = []

    var count: Int {
        return elements.count
    }

    var isEmpty: Bool {
        return elements.isEmpty
    }

    mutating func enqueue(_ element: T, priority: Int) {
        elements.append((element, priority))
        elements.sort { $0.1 > $1.1 } // Higher priority first
    }

    mutating func dequeue() -> T? {
        guard !isEmpty else { return nil }
        return elements.removeFirst().0
    }
}
