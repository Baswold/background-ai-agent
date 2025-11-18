import Foundation
import AppKit

// MARK: - Advanced Analytics & Insights Engine
// This engine provides ML-powered pattern recognition, behavior analysis, and predictive insights

class AdvancedAnalyticsEngine {
    static let shared = AdvancedAnalyticsEngine()

    private let queue = DispatchQueue(label: "com.backgroundai.analytics", qos: .utility)
    private var behaviorPatterns: [BehaviorPattern] = []
    private var workflowStates: [WorkflowState] = []
    private var insightHistory: [Insight] = []
    private var activityCallback: ((Activity) -> Void)?

    // Time-based analytics
    private var hourlyProductivity: [Int: ProductivityMetrics] = [:]
    private var dailyPatterns: [DayOfWeek: DailyPattern] = [:]
    private var focusPatterns: [FocusPattern] = []

    // Code analytics
    private var languageStats: [String: LanguageStatistics] = [:]
    private var errorPatterns: [ErrorPattern] = []
    private var codeComplexity: [ComplexityAnalysis] = []

    // Predictive analytics
    private var predictionEngine: PredictionEngine
    private var anomalyDetector: AnomalyDetector

    private init() {
        self.predictionEngine = PredictionEngine()
        self.anomalyDetector = AnomalyDetector()
        loadHistoricalData()
    }

    func start(onActivity: @escaping (Activity) -> Void) {
        activityCallback = onActivity
        print("📊 Advanced Analytics Engine started")

        // Run periodic analysis
        Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
            self?.performPeriodicAnalysis()
        }

        // Run deep analysis daily
        Timer.scheduledTimer(withTimeInterval: 86400.0, repeats: true) { [weak self] _ in
            self?.performDeepAnalysis()
        }
    }

    // MARK: - Behavior Pattern Recognition

    func recordBehavior(event: BehaviorEvent) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Update current patterns
            self.updateBehaviorPatterns(with: event)

            // Detect anomalies
            if self.anomalyDetector.isAnomalous(event: event, baseline: self.behaviorPatterns) {
                self.reportAnomaly(event)
            }

            // Generate predictions
            if let prediction = self.predictionEngine.predictNextAction(based: self.behaviorPatterns) {
                self.offerProactiveSuggestion(prediction)
            }
        }
    }

    private func updateBehaviorPatterns(with event: BehaviorEvent) {
        // Cluster similar behaviors
        if let existingPattern = behaviorPatterns.first(where: { $0.matches(event) }) {
            existingPattern.addOccurrence(event)
        } else {
            let newPattern = BehaviorPattern(initialEvent: event)
            behaviorPatterns.append(newPattern)
        }

        // Prune old patterns (keep last 1000)
        if behaviorPatterns.count > 1000 {
            behaviorPatterns.sort { $0.lastOccurrence > $1.lastOccurrence }
            behaviorPatterns = Array(behaviorPatterns.prefix(1000))
        }
    }

    // MARK: - Productivity Analytics

    func analyzeProductivityTrends() -> ProductivityReport {
        var report = ProductivityReport()

        // Analyze hourly patterns
        let currentHour = Calendar.current.component(.hour, from: Date())
        if let metrics = hourlyProductivity[currentHour] {
            report.currentHourProductivity = metrics.score
            report.isAboveAverage = metrics.score > calculateAverageProductivity()
        }

        // Identify peak hours
        report.peakHours = hourlyProductivity
            .sorted { $0.value.score > $1.value.score }
            .prefix(3)
            .map { ($0.key, $0.value.score) }

        // Calculate focus score
        report.focusScore = calculateFocusScore()

        // Identify distractions
        report.distractionSources = identifyDistractionSources()

        // Generate recommendations
        report.recommendations = generateProductivityRecommendations()

        return report
    }

    private func calculateAverageProductivity() -> Double {
        let scores = hourlyProductivity.values.map { $0.score }
        return scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
    }

    private func calculateFocusScore() -> Double {
        // Calculate based on:
        // 1. Duration of focused work sessions
        // 2. Context switching frequency
        // 3. Interruption patterns

        let recentPatterns = focusPatterns.filter {
            $0.timestamp > Date().addingTimeInterval(-3600) // Last hour
        }

        guard !recentPatterns.isEmpty else { return 0.0 }

        let avgDuration = recentPatterns.map { $0.duration }.reduce(0, +) / Double(recentPatterns.count)
        let avgInterruptions = recentPatterns.map { Double($0.interruptions) }.reduce(0, +) / Double(recentPatterns.count)

        // Score from 0-100
        let durationScore = min(avgDuration / 60.0, 60.0) / 60.0 * 50.0 // Max 50 points for 60+ min sessions
        let interruptionScore = max(0, 50.0 - (avgInterruptions * 5.0)) // Lose 5 points per interruption

        return durationScore + interruptionScore
    }

    private func identifyDistractionSources() -> [DistractionSource] {
        var sources: [DistractionSource] = []

        // Analyze app switching patterns
        let frequentSwitches = behaviorPatterns
            .filter { $0.eventType == .appSwitch }
            .sorted { $0.occurrenceCount > $1.occurrenceCount }

        for pattern in frequentSwitches.prefix(5) {
            sources.append(DistractionSource(
                name: pattern.description,
                frequency: pattern.occurrenceCount,
                impact: calculateDistractionImpact(pattern)
            ))
        }

        return sources
    }

    private func calculateDistractionImpact(_ pattern: BehaviorPattern) -> Double {
        // Impact is higher for:
        // - Frequent switches
        // - Switches during deep work periods
        // - Short duration visits

        let frequencyImpact = min(Double(pattern.occurrenceCount) / 100.0, 1.0) * 40.0
        let timingImpact = pattern.occursDuringFocusTime ? 40.0 : 20.0
        let durationImpact = pattern.averageDuration < 60 ? 20.0 : 0.0

        return frequencyImpact + timingImpact + durationImpact
    }

    // MARK: - Code Quality Analytics

    func analyzeCodeQuality(file: String, content: String, language: String) -> CodeQualityReport {
        var report = CodeQualityReport(file: file)

        // Calculate cyclomatic complexity
        report.cyclomaticComplexity = calculateCyclomaticComplexity(content: content, language: language)

        // Calculate maintainability index
        report.maintainabilityIndex = calculateMaintainabilityIndex(content: content)

        // Detect code smells
        report.codeSmells = detectCodeSmells(content: content, language: language)

        // Calculate technical debt
        report.technicalDebtMinutes = estimateTechnicalDebt(smells: report.codeSmells, complexity: report.cyclomaticComplexity)

        // Lines of code metrics
        let lines = content.components(separatedBy: .newlines)
        report.totalLines = lines.count
        report.codeLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.count
        report.commentLines = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.count

        // Calculate comment ratio
        report.commentRatio = report.codeLines > 0 ? Double(report.commentLines) / Double(report.codeLines) : 0.0

        // Update language stats
        updateLanguageStats(language: language, report: report)

        return report
    }

    private func calculateCyclomaticComplexity(content: String, language: String) -> Int {
        // Count decision points: if, while, for, case, &&, ||, ?:, catch
        let patterns = ["if ", "while ", "for ", "case ", "&&", "||", "?", "catch"]

        var complexity = 1 // Base complexity

        for pattern in patterns {
            let occurrences = content.components(separatedBy: pattern).count - 1
            complexity += occurrences
        }

        return complexity
    }

    private func calculateMaintainabilityIndex(content: String) -> Double {
        // Simplified maintainability index
        // MI = 171 - 5.2 * ln(HV) - 0.23 * CC - 16.2 * ln(LOC)
        // Where: HV = Halstead Volume, CC = Cyclomatic Complexity, LOC = Lines of Code

        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let loc = Double(lines.count)
        let cc = Double(calculateCyclomaticComplexity(content: content, language: ""))

        // Simplified calculation
        let mi = max(0, 171.0 - 5.2 * log(loc + 1) - 0.23 * cc - 16.2 * log(loc + 1))

        return min(100.0, mi) // Normalize to 0-100
    }

    private func detectCodeSmells(content: String, language: String) -> [CodeSmell] {
        var smells: [CodeSmell] = []

        let lines = content.components(separatedBy: .newlines)

        // Long method detection
        if lines.count > 50 {
            smells.append(CodeSmell(
                type: .longMethod,
                severity: .medium,
                description: "Method has \(lines.count) lines (recommended: < 50)",
                line: 1
            ))
        }

        // Deep nesting detection
        for (index, line) in lines.enumerated() {
            let indentLevel = line.prefix(while: { $0 == " " || $0 == "\t" }).count / 4
            if indentLevel > 4 {
                smells.append(CodeSmell(
                    type: .deepNesting,
                    severity: .high,
                    description: "Deep nesting detected (level \(indentLevel))",
                    line: index + 1
                ))
            }
        }

        // Magic numbers
        let numberPattern = try? NSRegularExpression(pattern: "\\b\\d{2,}\\b", options: [])
        for (index, line) in lines.enumerated() {
            let range = NSRange(line.startIndex..., in: line)
            if let matches = numberPattern?.matches(in: line, range: range), !matches.isEmpty {
                smells.append(CodeSmell(
                    type: .magicNumber,
                    severity: .low,
                    description: "Magic number found - consider using a named constant",
                    line: index + 1
                ))
            }
        }

        // Long parameter lists
        if content.contains("func ") || content.contains("def ") {
            let functionPattern = try? NSRegularExpression(pattern: "(func|def)\\s+\\w+\\([^)]{100,}\\)", options: [])
            let range = NSRange(content.startIndex..., in: content)
            if let matches = functionPattern?.matches(in: content, range: range), !matches.isEmpty {
                smells.append(CodeSmell(
                    type: .longParameterList,
                    severity: .medium,
                    description: "Function has too many parameters - consider using a parameter object",
                    line: 1
                ))
            }
        }

        // Duplicate code detection (simplified)
        var lineFrequency: [String: Int] = [:]
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.count > 20 { // Only check substantial lines
                lineFrequency[trimmed, default: 0] += 1
            }
        }

        for (line, count) in lineFrequency where count >= 3 {
            smells.append(CodeSmell(
                type: .duplicateCode,
                severity: .medium,
                description: "Duplicate code detected (\(count) occurrences)",
                line: 0
            ))
        }

        return smells
    }

    private func estimateTechnicalDebt(smells: [CodeSmell], complexity: Int) -> Int {
        var debt = 0

        for smell in smells {
            switch smell.severity {
            case .high: debt += 60
            case .medium: debt += 30
            case .low: debt += 10
            }
        }

        // Add debt for high complexity
        if complexity > 20 {
            debt += (complexity - 20) * 5
        }

        return debt
    }

    private func updateLanguageStats(language: String, report: CodeQualityReport) {
        if languageStats[language] == nil {
            languageStats[language] = LanguageStatistics(language: language)
        }

        languageStats[language]?.filesAnalyzed += 1
        languageStats[language]?.totalLines += report.totalLines
        languageStats[language]?.averageComplexity = (
            (languageStats[language]?.averageComplexity ?? 0) * Double((languageStats[language]?.filesAnalyzed ?? 1) - 1) +
            Double(report.cyclomaticComplexity)
        ) / Double(languageStats[language]?.filesAnalyzed ?? 1)
    }

    // MARK: - Predictive Analytics

    private func offerProactiveSuggestion(_ prediction: ActionPrediction) {
        let activity = Activity(
            title: "💡 Smart Suggestion",
            description: prediction.suggestion,
            type: .learning
        )

        DispatchQueue.main.async { [weak self] in
            self?.activityCallback?(activity)
        }
    }

    // MARK: - Anomaly Detection

    private func reportAnomaly(_ event: BehaviorEvent) {
        let activity = Activity(
            title: "⚠️ Unusual Activity Detected",
            description: "This is different from your usual pattern: \(event.description)",
            type: .learning
        )

        DispatchQueue.main.async { [weak self] in
            self?.activityCallback?(activity)
        }
    }

    // MARK: - Periodic Analysis

    private func performPeriodicAnalysis() {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Analyze recent patterns
            let insights = self.generateInsights()

            for insight in insights {
                self.insightHistory.append(insight)

                if insight.importance >= 0.7 {
                    let activity = Activity(
                        title: "📈 Insight: \(insight.category)",
                        description: insight.message,
                        type: .learning
                    )

                    DispatchQueue.main.async {
                        self.activityCallback?(activity)
                    }
                }
            }
        }
    }

    private func performDeepAnalysis() {
        queue.async { [weak self] in
            guard let self = self else { return }

            print("🔬 Performing deep analysis...")

            // Analyze workflow efficiency
            let workflowReport = self.analyzeWorkflowEfficiency()

            // Generate comprehensive report
            let report = self.generateDailyReport()

            // Save to analytics file
            self.saveAnalyticsReport(report)

            print("✅ Deep analysis complete")
        }
    }

    private func generateInsights() -> [Insight] {
        var insights: [Insight] = []

        // Productivity insights
        if let peakHour = hourlyProductivity.max(by: { $0.value.score < $1.value.score }) {
            insights.append(Insight(
                category: "Productivity",
                message: "You're most productive at \(peakHour.key):00. Consider scheduling important tasks then.",
                importance: 0.8,
                timestamp: Date()
            ))
        }

        // Focus insights
        let focusScore = calculateFocusScore()
        if focusScore < 50 {
            insights.append(Insight(
                category: "Focus",
                message: "Your focus score is \(Int(focusScore))/100. Try using the Pomodoro technique.",
                importance: 0.9,
                timestamp: Date()
            ))
        }

        // Code quality insights
        for (language, stats) in languageStats {
            if stats.averageComplexity > 15 {
                insights.append(Insight(
                    category: "Code Quality",
                    message: "Your \(language) code complexity is high (\(Int(stats.averageComplexity))). Consider refactoring.",
                    importance: 0.75,
                    timestamp: Date()
                ))
            }
        }

        return insights
    }

    private func analyzeWorkflowEfficiency() -> WorkflowEfficiencyReport {
        var report = WorkflowEfficiencyReport()

        // Calculate time spent on different activities
        report.codingTime = workflowStates.filter { $0.activity == .coding }.reduce(0) { $0 + $1.duration }
        report.debuggingTime = workflowStates.filter { $0.activity == .debugging }.reduce(0) { $0 + $1.duration }
        report.meetingTime = workflowStates.filter { $0.activity == .meeting }.reduce(0) { $0 + $1.duration }
        report.researchTime = workflowStates.filter { $0.activity == .research }.reduce(0) { $0 + $1.duration }

        // Calculate efficiency score
        let productiveTime = report.codingTime + report.debuggingTime + report.researchTime
        let totalTime = productiveTime + report.meetingTime
        report.efficiencyScore = totalTime > 0 ? productiveTime / totalTime : 0

        return report
    }

    private func generateDailyReport() -> String {
        let productivity = analyzeProductivityTrends()
        let workflow = analyzeWorkflowEfficiency()

        return """
        # Daily Analytics Report

        **Date:** \(Date().formatted(date: .long, time: .standard))

        ## Productivity Metrics
        - Focus Score: \(Int(productivity.focusScore))/100
        - Current Hour Productivity: \(Int(productivity.currentHourProductivity * 100))%
        - Above Average: \(productivity.isAboveAverage ? "Yes" : "No")

        ## Peak Performance Hours
        \(productivity.peakHours.map { "\($0.0):00 - \(Int($0.1 * 100))%" }.joined(separator: "\n"))

        ## Workflow Efficiency
        - Coding Time: \(Int(workflow.codingTime / 60)) minutes
        - Debugging Time: \(Int(workflow.debuggingTime / 60)) minutes
        - Meeting Time: \(Int(workflow.meetingTime / 60)) minutes
        - Research Time: \(Int(workflow.researchTime / 60)) minutes
        - Efficiency Score: \(Int(workflow.efficiencyScore * 100))%

        ## Code Quality Stats
        \(languageStats.map { lang, stats in
            "- \(lang): \(stats.filesAnalyzed) files, avg complexity: \(Int(stats.averageComplexity))"
        }.joined(separator: "\n"))

        ## Top Distractions
        \(productivity.distractionSources.prefix(3).map { "- \($0.name): \(Int($0.impact))% impact" }.joined(separator: "\n"))

        ## Recommendations
        \(productivity.recommendations.joined(separator: "\n"))

        ---
        *Generated by Advanced Analytics Engine*
        """
    }

    private func generateProductivityRecommendations() -> [String] {
        var recommendations: [String] = []

        // Based on focus score
        let focusScore = calculateFocusScore()
        if focusScore < 60 {
            recommendations.append("💡 Try time-blocking to improve focus")
        }

        // Based on productivity patterns
        if let peakHours = hourlyProductivity.max(by: { $0.value.score < $1.value.score }) {
            recommendations.append("⏰ Schedule deep work during your peak hours around \(peakHours.key):00")
        }

        // Based on distractions
        let distractions = identifyDistractionSources()
        if !distractions.isEmpty {
            recommendations.append("🔕 Consider blocking \(distractions.first!.name) during focus sessions")
        }

        return recommendations
    }

    private func saveAnalyticsReport(_ report: String) {
        let filename = "analytics-\(Date().formatted(date: .abbreviated, time: .omitted)).md"
        let path = AppConfig.baseDirectory
            .appendingPathComponent("logs")
            .appendingPathComponent(filename)

        try? report.write(to: path, atomically: true, encoding: .utf8)
        print("📊 Analytics report saved: \(filename)")
    }

    private func loadHistoricalData() {
        // Load previous analytics data
        // Implementation would read from persistent storage
        print("📚 Loading historical analytics data...")
    }

    // MARK: - Public API

    func getLanguageStatistics() -> [String: LanguageStatistics] {
        return languageStats
    }

    func getInsightHistory() -> [Insight] {
        return insightHistory.sorted { $0.timestamp > $1.timestamp }
    }

    func getBehaviorPatterns() -> [BehaviorPattern] {
        return behaviorPatterns.sorted { $0.occurrenceCount > $1.occurrenceCount }
    }
}

// MARK: - Data Models

class BehaviorPattern {
    let id = UUID()
    var eventType: BehaviorEventType
    var description: String
    var occurrenceCount: Int = 1
    var lastOccurrence: Date
    var averageDuration: TimeInterval = 0
    var occursDuringFocusTime: Bool = false
    private var durations: [TimeInterval] = []

    init(initialEvent: BehaviorEvent) {
        self.eventType = initialEvent.type
        self.description = initialEvent.description
        self.lastOccurrence = initialEvent.timestamp
        self.averageDuration = initialEvent.duration
        self.durations.append(initialEvent.duration)
    }

    func matches(_ event: BehaviorEvent) -> Bool {
        return event.type == eventType &&
               event.description.contains(description.prefix(20))
    }

    func addOccurrence(_ event: BehaviorEvent) {
        occurrenceCount += 1
        lastOccurrence = event.timestamp
        durations.append(event.duration)

        if durations.count > 100 {
            durations.removeFirst()
        }

        averageDuration = durations.reduce(0, +) / Double(durations.count)
    }
}

struct BehaviorEvent {
    let type: BehaviorEventType
    let description: String
    let timestamp: Date
    let duration: TimeInterval
}

enum BehaviorEventType {
    case appSwitch
    case codeEdit
    case gitCommit
    case debugSession
    case meeting
    case research
}

struct WorkflowState {
    let activity: WorkflowActivity
    let timestamp: Date
    let duration: TimeInterval
}

enum WorkflowActivity {
    case coding
    case debugging
    case meeting
    case research
    case communication
}

struct ProductivityMetrics {
    var score: Double
    var focusLevel: Double
    var interruptions: Int
    var tasksCompleted: Int
}

enum DayOfWeek: Int {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}

struct DailyPattern {
    var averageProductivity: Double
    var peakHours: [Int]
    var commonTasks: [String]
}

struct FocusPattern {
    let timestamp: Date
    let duration: TimeInterval
    let interruptions: Int
    let task: String
}

struct LanguageStatistics {
    let language: String
    var filesAnalyzed: Int = 0
    var totalLines: Int = 0
    var averageComplexity: Double = 0
    var commonIssues: [String] = []
}

struct ErrorPattern {
    let errorType: String
    let frequency: Int
    let lastOccurrence: Date
    let suggestedFix: String?
}

struct ComplexityAnalysis {
    let file: String
    let complexity: Int
    let maintainability: Double
    let timestamp: Date
}

class PredictionEngine {
    func predictNextAction(based patterns: [BehaviorPattern]) -> ActionPrediction? {
        // Simplified prediction based on recent patterns
        guard let recentPattern = patterns.first(where: {
            $0.lastOccurrence > Date().addingTimeInterval(-300)
        }) else {
            return nil
        }

        // Generate contextual suggestion
        let suggestion = generateSuggestion(for: recentPattern)

        return ActionPrediction(
            action: recentPattern.eventType,
            confidence: 0.75,
            suggestion: suggestion,
            timestamp: Date()
        )
    }

    private func generateSuggestion(for pattern: BehaviorPattern) -> String {
        switch pattern.eventType {
        case .codeEdit:
            return "Based on your pattern, you might want to run tests soon"
        case .debugSession:
            return "Consider taking a break - you've been debugging for a while"
        case .gitCommit:
            return "Don't forget to push your commits!"
        case .meeting:
            return "Update your task list based on meeting outcomes"
        case .research:
            return "Document your findings for future reference"
        case .appSwitch:
            return "Try to maintain focus on your current task"
        }
    }
}

struct ActionPrediction {
    let action: BehaviorEventType
    let confidence: Double
    let suggestion: String
    let timestamp: Date
}

class AnomalyDetector {
    func isAnomalous(event: BehaviorEvent, baseline: [BehaviorPattern]) -> Bool {
        // Detect unusual behavior patterns

        // Check if event happens at unusual time
        let hour = Calendar.current.component(.hour, from: event.timestamp)
        if hour < 6 || hour > 23 {
            return true // Working at unusual hours
        }

        // Check if duration is unusually long
        if event.duration > 7200 { // More than 2 hours
            return true
        }

        // Check if it's a rare event type
        let similarEvents = baseline.filter { $0.eventType == event.type }
        if similarEvents.isEmpty || similarEvents.count < 3 {
            return true
        }

        return false
    }
}

struct Insight {
    let id = UUID()
    let category: String
    let message: String
    let importance: Double
    let timestamp: Date
}

struct ProductivityReport {
    var currentHourProductivity: Double = 0
    var isAboveAverage: Bool = false
    var peakHours: [(Int, Double)] = []
    var focusScore: Double = 0
    var distractionSources: [DistractionSource] = []
    var recommendations: [String] = []
}

struct DistractionSource {
    let name: String
    let frequency: Int
    let impact: Double
}

struct CodeQualityReport {
    let file: String
    var cyclomaticComplexity: Int = 0
    var maintainabilityIndex: Double = 0
    var codeSmells: [CodeSmell] = []
    var technicalDebtMinutes: Int = 0
    var totalLines: Int = 0
    var codeLines: Int = 0
    var commentLines: Int = 0
    var commentRatio: Double = 0
}

struct CodeSmell {
    let type: CodeSmellType
    let severity: CodeSmellSeverity
    let description: String
    let line: Int
}

enum CodeSmellType {
    case longMethod
    case deepNesting
    case magicNumber
    case duplicateCode
    case longParameterList
    case deadCode
    case complexConditional
}

enum CodeSmellSeverity {
    case low
    case medium
    case high
}

struct WorkflowEfficiencyReport {
    var codingTime: TimeInterval = 0
    var debuggingTime: TimeInterval = 0
    var meetingTime: TimeInterval = 0
    var researchTime: TimeInterval = 0
    var efficiencyScore: Double = 0
}
