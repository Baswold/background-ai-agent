import SwiftUI

// MARK: - Advanced Dashboard & Monitoring UI

struct DashboardView: View {
    @State private var selectedTab = 0
    @State private var refreshTimer: Timer?

    // State
    @State private var healthStatus: HealthStatus = .healthy
    @State private var componentHealth: [ComponentHealth] = []
    @State private var rateLimitStatuses: [String: RateLimitStatus] = [:]
    @State private var cacheStats: CacheStatistics?
    @State private var analyticsReport: AnalyticsReport?
    @State private var performanceMetrics: [String: MetricStatistics] = [:]
    @State private var recentLogs: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            DashboardHeader(healthStatus: healthStatus)

            // Tabs
            Picker("View", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("Health").tag(1)
                Text("Performance").tag(2)
                Text("Analytics").tag(3)
                Text("Logs").tag(4)
                Text("Configuration").tag(5)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            TabView(selection: $selectedTab) {
                OverviewTab(
                    healthStatus: healthStatus,
                    componentHealth: componentHealth,
                    cacheStats: cacheStats,
                    analyticsReport: analyticsReport
                )
                .tag(0)

                HealthTab(
                    overallHealth: healthStatus,
                    components: componentHealth
                )
                .tag(1)

                PerformanceTab(
                    metrics: performanceMetrics,
                    cacheStats: cacheStats
                )
                .tag(2)

                AnalyticsTab(
                    report: analyticsReport,
                    rateLimitStatuses: rateLimitStatuses
                )
                .tag(3)

                LogsTab(recentLogs: recentLogs)
                    .tag(4)

                ConfigurationTab()
                    .tag(5)
            }
            .tabViewStyle(.automatic)
        }
        .frame(width: 800, height: 600)
        .onAppear {
            refreshData()
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
    }

    // MARK: - Data Management

    private func refreshData() {
        Task {
            // Health status
            await HealthCheckSystem.shared.performHealthCheck()
            healthStatus = HealthCheckSystem.shared.getOverallHealth()
            componentHealth = HealthCheckSystem.shared.getAllComponentHealth()

            // Rate limits
            rateLimitStatuses = RateLimiter.shared.getAllStatuses()

            // Cache stats
            cacheStats = await CacheManager.shared.getCacheStatistics()

            // Analytics
            analyticsReport = AnalyticsManager.shared.generateReport()

            // Performance metrics
            performanceMetrics = PerformanceMonitor.shared.getAllStatistics()

            // Recent logs
            recentLogs = Logger.shared.getRecentLogs(count: 100)
        }
    }

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            refreshData()
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Dashboard Header

struct DashboardHeader: View {
    let healthStatus: HealthStatus

    var body: some View {
        HStack {
            Image(systemName: "chart.bar.fill")
                .font(.title)
                .foregroundColor(.blue)

            VStack(alignment: .leading) {
                Text("Background AI Agent Dashboard")
                    .font(.headline)

                Text("Production Monitoring & Analytics")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Health indicator
            HStack(spacing: 4) {
                Text(healthStatus.icon)
                Text(healthStatus.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(healthStatusColor(healthStatus))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(healthStatusColor(healthStatus).opacity(0.2))
            )
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func healthStatusColor(_ status: HealthStatus) -> Color {
        switch status {
        case .healthy: return .green
        case .degraded: return .orange
        case .unhealthy: return .red
        }
    }
}

// MARK: - Overview Tab

struct OverviewTab: View {
    let healthStatus: HealthStatus
    let componentHealth: [ComponentHealth]
    let cacheStats: CacheStatistics?
    let analyticsReport: AnalyticsReport?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Quick stats
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(
                        title: "System Health",
                        value: healthStatus.rawValue,
                        icon: "heart.fill",
                        color: .green
                    )

                    if let report = analyticsReport {
                        StatCard(
                            title: "API Calls",
                            value: "\(report.sessionStats.apiCalls)",
                            icon: "network",
                            color: .blue
                        )

                        StatCard(
                            title: "Uptime",
                            value: formatDuration(report.sessionStats.duration),
                            icon: "clock.fill",
                            color: .purple
                        )
                    }
                }

                // Cache stats
                if let cache = cacheStats {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cache Performance")
                            .font(.headline)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Memory")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("\(cache.memoryCacheCount) entries")
                                    .font(.title3)
                            }

                            Spacer()

                            VStack(alignment: .trailing) {
                                Text("Disk")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("\(cache.diskCacheFileCount) files")
                                    .font(.title3)

                                Text("\(String(format: "%.1f", cache.diskCacheSizeMB)) MB")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                    }
                }

                // Component health summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Component Status")
                        .font(.headline)

                    ForEach(componentHealth.prefix(5), id: \.component) { component in
                        HStack {
                            Text(component.status.icon)
                            Text(component.component)
                            Spacer()
                            Text(component.status.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
            }
            .padding()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Health Tab

struct HealthTab: View {
    let overallHealth: HealthStatus
    let components: [ComponentHealth]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("System Health")
                    .font(.title2)
                    .fontWeight(.bold)

                ForEach(components, id: \.component) { component in
                    ComponentHealthCard(health: component)
                }
            }
            .padding()
        }
    }
}

struct ComponentHealthCard: View {
    let health: ComponentHealth

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(health.status.icon)
                    .font(.title2)

                Text(health.component)
                    .font(.headline)

                Spacer()

                Text(health.status.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusColor(health.status).opacity(0.2))
                    )
                    .foregroundColor(statusColor(health.status))
            }

            Text(health.message)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !health.issues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Issues:")
                        .font(.caption)
                        .fontWeight(.semibold)

                    ForEach(health.issues, id: \.self) { issue in
                        HStack(alignment: .top) {
                            Text("•")
                            Text(issue)
                                .font(.caption)
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange.opacity(0.1))
                )
            }

            Text("Last checked: \(health.lastChecked.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private func statusColor(_ status: HealthStatus) -> Color {
        switch status {
        case .healthy: return .green
        case .degraded: return .orange
        case .unhealthy: return .red
        }
    }
}

// MARK: - Performance Tab

struct PerformanceTab: View {
    let metrics: [String: MetricStatistics]
    let cacheStats: CacheStatistics?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Performance Metrics")
                    .font(.title2)
                    .fontWeight(.bold)

                ForEach(metrics.sorted(by: { $0.key < $1.key }), id: \.key) { key, stat in
                    MetricCard(name: key, stats: stat)
                }
            }
            .padding()
        }
    }
}

struct MetricCard: View {
    let name: String
    let stats: MetricStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricValue(label: "Average", value: String(format: "%.1fms", stats.average * 1000))
                MetricValue(label: "Median", value: String(format: "%.1fms", stats.median * 1000))
                MetricValue(label: "P95", value: String(format: "%.1fms", stats.p95 * 1000))
                MetricValue(label: "Min", value: String(format: "%.1fms", stats.min * 1000))
                MetricValue(label: "Max", value: String(format: "%.1fms", stats.max * 1000))
                MetricValue(label: "Samples", value: "\(stats.count)")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct MetricValue: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Analytics Tab

struct AnalyticsTab: View {
    let report: AnalyticsReport?
    let rateLimitStatuses: [String: RateLimitStatus]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Analytics")
                    .font(.title2)
                    .fontWeight(.bold)

                if let report = report {
                    // Session stats
                    AnalyticsSection(title: "Session Statistics") {
                        Text(report.sessionStats.formatted())
                            .font(.caption)
                            .monospaced()
                    }

                    // Daily stats
                    AnalyticsSection(title: "Daily Statistics") {
                        Text(report.dailyStats.formatted())
                            .font(.caption)
                            .monospaced()
                    }
                }

                // Rate limits
                AnalyticsSection(title: "Rate Limits") {
                    ForEach(rateLimitStatuses.sorted(by: { $0.key < $1.key }), id: \.key) { service, status in
                        RateLimitCard(service: service, status: status)
                    }
                }
            }
            .padding()
        }
    }
}

struct AnalyticsSection<Content: View>: View {
    let title: String
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct RateLimitCard: View {
    let service: String
    let status: RateLimitStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(service.capitalized)
                .font(.subheadline)
                .fontWeight(.semibold)

            ProgressView(value: 1.0 - (Double(status.minuteRemaining) / Double(status.minuteLimit))) {
                Text("Minute: \(status.minuteRemaining)/\(status.minuteLimit)")
                    .font(.caption2)
            }

            ProgressView(value: 1.0 - (Double(status.hourRemaining) / Double(status.hourLimit))) {
                Text("Hour: \(status.hourRemaining)/\(status.hourLimit)")
                    .font(.caption2)
            }

            ProgressView(value: 1.0 - (Double(status.dayRemaining) / Double(status.dayLimit))) {
                Text("Day: \(status.dayRemaining)/\(status.dayLimit)")
                    .font(.caption2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.windowBackgroundColor))
        )
    }
}

// MARK: - Logs Tab

struct LogsTab: View {
    let recentLogs: [String]
    @State private var searchText = ""
    @State private var selectedLevel: LogLevel?

    var filteredLogs: [String] {
        var logs = recentLogs

        if !searchText.isEmpty {
            logs = logs.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }

        if let level = selectedLevel {
            logs = logs.filter { $0.contains(level.icon) }
        }

        return logs
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search and filters
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.plain)

                Picker("Level", selection: $selectedLevel) {
                    Text("All").tag(nil as LogLevel?)
                    Text(LogLevel.info.icon).tag(LogLevel.info as LogLevel?)
                    Text(LogLevel.warning.icon).tag(LogLevel.warning as LogLevel?)
                    Text(LogLevel.error.icon).tag(LogLevel.error as LogLevel?)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding()

            Divider()

            // Logs list
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(filteredLogs, id: \.self) { log in
                        Text(log)
                            .font(.caption)
                            .monospaced()
                            .textSelection(.enabled)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Configuration Tab

struct ConfigurationTab: View {
    @State private var validationResult: ValidationResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Configuration")
                    .font(.title2)
                    .fontWeight(.bold)

                Button("Validate Configuration") {
                    validationResult = ConfigurationManager.shared.validateConfiguration()
                }
                .buttonStyle(.borderedProminent)

                if let result = validationResult {
                    Text(result.formatted())
                        .font(.caption)
                        .monospaced()
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                }

                Divider()

                Text("Backup & Restore")
                    .font(.headline)

                HStack {
                    Button("Create Backup") {
                        do {
                            let url = try ConfigurationManager.shared.backupSettings()
                            Logger.shared.info("Backup created: \(url.lastPathComponent)", category: .configuration)
                        } catch {
                            Logger.shared.error("Backup failed: \(error)", category: .errorHandling)
                        }
                    }

                    Button("View Backups") {
                        let backups = ConfigurationManager.shared.listBackups()
                        for backup in backups {
                            print(backup.formatted())
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

#Preview {
    DashboardView()
}
