import Foundation

// MARK: - Enhanced AI Integration Layer
// Integrates all advanced AI systems into the main agent

class EnhancedAIIntegration {
    static let shared = EnhancedAIIntegration()

    // All advanced systems
    private let analyticsEngine = AdvancedAnalyticsEngine.shared
    private let suggestionSystem = ContextAwareSuggestionSystem.shared
    private let securityScanner = AdvancedSecurityScanner.shared
    private let testGenerator = AITestGenerator.shared
    private let refactoringEngine = SmartRefactoringEngine.shared

    private var activityCallback: ((Activity) -> Void)?

    private init() {}

    // MARK: - Initialization

    func initialize(onActivity: @escaping (Activity) -> Void) {
        activityCallback = onActivity

        // Start all systems
        analyticsEngine.start(onActivity: onActivity)
        suggestionSystem.start(onActivity: onActivity)
        securityScanner.start(onActivity: onActivity)

        print("🚀 Enhanced AI Integration initialized with 5 advanced systems")
    }

    // MARK: - Comprehensive Code Analysis

    func analyzeCodeComprehensively(file: String, content: String, language: String) async {
        print("🔬 Running comprehensive analysis on \(file)...")

        // Run all analyses in parallel
        await withTaskGroup(of: Void.self) { group in
            // Security scan
            group.addTask {
                let securityResult = await self.securityScanner.scanFile(
                    path: file,
                    content: content,
                    language: language
                )

                if !securityResult.vulnerabilities.isEmpty {
                    let critical = securityResult.vulnerabilities.filter { $0.severity == .critical }.count
                    let activity = Activity(
                        title: "Security Scan Complete",
                        description: "Found \(securityResult.vulnerabilities.count) issues (\(critical) critical). Security Score: \(Int(securityResult.securityScore))/100",
                        type: .vsCodeFix
                    )

                    DispatchQueue.main.async {
                        self.activityCallback?(activity)
                    }
                }
            }

            // Code quality analysis
            group.addTask {
                let qualityReport = self.analyticsEngine.analyzeCodeQuality(
                    file: file,
                    content: content,
                    language: language
                )

                if qualityReport.cyclomaticComplexity > 10 {
                    let activity = Activity(
                        title: "Code Complexity Warning",
                        description: "Cyclomatic complexity: \(qualityReport.cyclomaticComplexity). Consider refactoring.",
                        type: .vsCodeFix
                    )

                    DispatchQueue.main.async {
                        self.activityCallback?(activity)
                    }
                }
            }

            // Refactoring suggestions
            group.addTask {
                let refactorings = await self.refactoringEngine.analyzeForRefactoring(
                    file: file,
                    content: content,
                    language: language
                )

                if !refactorings.isEmpty {
                    let highImpact = refactorings.filter { $0.impact > 0.7 }
                    if !highImpact.isEmpty {
                        let activity = Activity(
                            title: "Refactoring Suggestions Available",
                            description: "\(highImpact.count) high-impact refactorings suggested",
                            type: .vsCodeFix
                        )

                        DispatchQueue.main.async {
                            self.activityCallback?(activity)
                        }
                    }
                }
            }

            // Test generation
            group.addTask {
                do {
                    let testSuite = try await self.testGenerator.generateTests(
                        for: file,
                        code: content,
                        language: language
                    )

                    if !testSuite.unitTests.isEmpty {
                        let activity = Activity(
                            title: "Tests Generated",
                            description: "Generated \(testSuite.unitTests.count) unit tests. Coverage: \(Int(testSuite.estimatedCoverage))%",
                            type: .vsCodeFix
                        )

                        DispatchQueue.main.async {
                            self.activityCallback?(activity)
                        }
                    }
                } catch {
                    print("❌ Test generation error: \(error)")
                }
            }
        }

        print("✅ Comprehensive analysis complete for \(file)")
    }

    // MARK: - Behavior Analytics

    func trackBehavior(event: BehaviorEvent) {
        analyticsEngine.recordBehavior(event: event)
    }

    func updateContext(file: String, language: String) {
        suggestionSystem.updateFileContext(file: file, language: language)
    }

    func reportError(_ error: String) {
        suggestionSystem.reportError(error)
    }

    func reportCommand(_ command: String) {
        suggestionSystem.reportCommand(command)
    }

    // MARK: - Productivity Analytics

    func generateProductivityReport() -> String {
        let report = analyticsEngine.analyzeProductivityTrends()
        let languageStats = analyticsEngine.getLanguageStatistics()
        let insights = analyticsEngine.getInsightHistory().prefix(10)

        return """
        # 📊 Productivity & Code Quality Report

        ## Focus & Productivity
        - **Focus Score**: \(Int(report.focusScore))/100
        - **Current Hour Productivity**: \(Int(report.currentHourProductivity * 100))%
        - **Status**: \(report.isAboveAverage ? "Above Average 🎉" : "Room for Improvement")

        ## Peak Performance
        \(report.peakHours.map { "- \($0.0):00 - Productivity: \(Int($0.1 * 100))%" }.joined(separator: "\n"))

        ## Top Distractions
        \(report.distractionSources.prefix(5).map { "- \($0.name): \(Int($0.impact))% impact" }.joined(separator: "\n"))

        ## Code Quality by Language
        \(languageStats.map { lang, stats in
            "- **\(lang)**: \(stats.filesAnalyzed) files, avg complexity: \(Int(stats.averageComplexity)), \(stats.totalLines) lines"
        }.joined(separator: "\n"))

        ## Recent Insights
        \(insights.map { "- [\($0.category)] \($0.message)" }.joined(separator: "\n"))

        ## Recommendations
        \(report.recommendations.joined(separator: "\n"))

        ---
        *Generated by Enhanced AI Integration*
        """
    }

    // MARK: - Security Report

    func generateSecurityReport() -> String {
        return securityScanner.generateSecurityReport()
    }

    // MARK: - Dashboard Data

    func getDashboardData() -> DashboardData {
        let productivity = analyticsEngine.analyzeProductivityTrends()
        let suggestions = suggestionSystem.getSuggestionHistory().prefix(10)
        let refactorings = refactoringEngine.getRefactoringHistory().prefix(10)
        let tests = testGenerator.getGeneratedTests().prefix(5)
        let security = securityScanner.getScanHistory().prefix(5)

        return DashboardData(
            focusScore: productivity.focusScore,
            productivityScore: productivity.currentHourProductivity,
            recentSuggestions: Array(suggestions),
            recentRefactorings: Array(refactorings),
            testsGenerated: tests.count,
            securityIssuesFound: security.flatMap { $0.result.vulnerabilities }.count,
            languageStats: analyticsEngine.getLanguageStatistics()
        )
    }

    // MARK: - Smart Actions

    func autoFixSecurityIssue(file: String, vulnerability: SecurityVulnerability) async -> String? {
        guard !Settings.shared.claudeAPIKey.isEmpty else { return nil }

        do {
            let prompt = """
            Fix this security vulnerability:

            Type: \(vulnerability.type)
            Description: \(vulnerability.description)
            CWE: \(vulnerability.cwe)
            OWASP: \(vulnerability.owasp)

            Remediation: \(vulnerability.remediation)

            Provide the fixed code (be specific and complete):
            """

            return try await AIService.shared.callClaude(prompt: prompt, maxTokens: 800)
        } catch {
            return nil
        }
    }

    func generateOptimizedVersion(code: String, language: String) async -> String? {
        guard !Settings.shared.claudeAPIKey.isEmpty else { return nil }

        do {
            let prompt = """
            Optimize this \(language) code for:
            1. Performance
            2. Readability
            3. Maintainability

            Original code:
            \(code.prefix(2000))

            Provide the optimized version:
            """

            return try await AIService.shared.callClaude(prompt: prompt, maxTokens: 1000)
        } catch {
            return nil
        }
    }

    // MARK: - Export & Reporting

    func exportComprehensiveReport(to path: URL) throws {
        let productivity = generateProductivityReport()
        let security = generateSecurityReport()
        let dashboard = getDashboardData()

        let report = """
        # 🧠 Background AI Agent - Comprehensive Report

        **Generated**: \(Date().formatted(date: .long, time: .standard))

        \(productivity)

        \(security)

        ## Dashboard Summary
        - **Focus Score**: \(Int(dashboard.focusScore))/100
        - **Productivity**: \(Int(dashboard.productivityScore * 100))%
        - **Tests Generated**: \(dashboard.testsGenerated)
        - **Security Issues**: \(dashboard.securityIssuesFound)
        - **Active Suggestions**: \(dashboard.recentSuggestions.count)
        - **Refactorings Suggested**: \(dashboard.recentRefactorings.count)

        ---
        *Powered by Advanced AI Integration Layer*
        """

        try report.write(to: path, atomically: true, encoding: .utf8)
        print("📄 Comprehensive report exported to: \(path.path)")
    }
}

// MARK: - Data Models

struct DashboardData {
    let focusScore: Double
    let productivityScore: Double
    let recentSuggestions: [Suggestion]
    let recentRefactorings: [RefactoringOperation]
    let testsGenerated: Int
    let securityIssuesFound: Int
    let languageStats: [String: LanguageStatistics]
}
