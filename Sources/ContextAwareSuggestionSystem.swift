import Foundation
import AppKit

// MARK: - Context-Aware AI Suggestion System
// Provides intelligent, context-aware suggestions based on current work context and patterns

class ContextAwareSuggestionSystem {
    static let shared = ContextAwareSuggestionSystem()

    private var currentContext: WorkContext?
    private var contextHistory: [WorkContext] = []
    private var suggestionHistory: [Suggestion] = []
    private var activityCallback: ((Activity) -> Void)?

    private let queue = DispatchQueue(label: "com.backgroundai.suggestions", qos: .userInitiated)

    // Context tracking
    private var currentFile: String?
    private var currentLanguage: String?
    private var recentErrors: [String] = []
    private var recentCommands: [String] = []
    private var activeApps: Set<String> = []

    // AI-powered suggestion cache
    private var suggestionCache: [String: [Suggestion]] = [:]
    private let cacheExpiration: TimeInterval = 3600 // 1 hour

    private init() {
        startContextMonitoring()
    }

    func start(onActivity: @escaping (Activity) -> Void) {
        activityCallback = onActivity
        print("🧠 Context-Aware Suggestion System started")
    }

    // MARK: - Context Monitoring

    private func startContextMonitoring() {
        // Monitor every 5 seconds for context changes
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateCurrentContext()
        }
    }

    func updateCurrentContext() {
        queue.async { [weak self] in
            guard let self = self else { return }

            let newContext = self.buildCurrentContext()

            // Check if context has changed significantly
            if self.hasSignificantContextChange(from: self.currentContext, to: newContext) {
                self.currentContext = newContext
                self.contextHistory.append(newContext)

                // Limit history size
                if self.contextHistory.count > 100 {
                    self.contextHistory.removeFirst()
                }

                // Generate suggestions for new context
                Task {
                    await self.generateContextualSuggestions(for: newContext)
                }
            }
        }
    }

    private func buildCurrentContext() -> WorkContext {
        var context = WorkContext(timestamp: Date())

        // Get active application
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            context.activeApp = frontApp.localizedName ?? "Unknown"
            context.appBundleId = frontApp.bundleIdentifier
        }

        // Determine current activity type
        context.activityType = determineActivityType(from: context.activeApp ?? "")

        // Get current file context if in code editor
        context.currentFile = currentFile
        context.currentLanguage = currentLanguage

        // Add recent errors
        context.recentErrors = Array(recentErrors.suffix(5))

        // Add recent commands
        context.recentCommands = Array(recentCommands.suffix(10))

        // Time context
        let hour = Calendar.current.component(.hour, from: Date())
        context.timeOfDay = determineTimeOfDay(hour: hour)
        context.isWeekend = Calendar.current.isDateInWeekend(Date())

        return context
    }

    private func hasSignificantContextChange(from old: WorkContext?, to new: WorkContext) -> Bool {
        guard let old = old else { return true }

        return old.activeApp != new.activeApp ||
               old.currentFile != new.currentFile ||
               old.activityType != new.activityType ||
               !Set(old.recentErrors).isSubset(of: Set(new.recentErrors))
    }

    private func determineActivityType(from appName: String) -> ActivityType {
        let codeEditors = ["Visual Studio Code", "Xcode", "IntelliJ", "Sublime Text", "Vim"]
        let browsers = ["Safari", "Chrome", "Firefox", "Edge"]
        let communication = ["Slack", "Discord", "Mail", "Teams", "Zoom"]
        let terminals = ["Terminal", "iTerm"]

        if codeEditors.contains(where: { appName.contains($0) }) {
            return .coding
        } else if browsers.contains(where: { appName.contains($0) }) {
            return .researching
        } else if communication.contains(where: { appName.contains($0) }) {
            return .communicating
        } else if terminals.contains(where: { appName.contains($0) }) {
            return .executing
        } else {
            return .other
        }
    }

    private func determineTimeOfDay(hour: Int) -> TimeOfDay {
        switch hour {
        case 6..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }

    // MARK: - Suggestion Generation

    func generateContextualSuggestions(for context: WorkContext) async {
        var suggestions: [Suggestion] = []

        // Check cache first
        let cacheKey = context.cacheKey
        if let cached = suggestionCache[cacheKey],
           let firstSuggestion = cached.first,
           Date().timeIntervalSince(firstSuggestion.timestamp) < cacheExpiration {
            suggestions = cached
        } else {
            // Generate new suggestions
            suggestions = await generateFreshSuggestions(for: context)
            suggestionCache[cacheKey] = suggestions
        }

        // Filter and rank suggestions
        let rankedSuggestions = rankSuggestions(suggestions, for: context)

        // Present top suggestions
        for suggestion in rankedSuggestions.prefix(3) {
            presentSuggestion(suggestion)
        }
    }

    private func generateFreshSuggestions(for context: WorkContext) async -> [Suggestion] {
        var suggestions: [Suggestion] = []

        // Activity-specific suggestions
        switch context.activityType {
        case .coding:
            suggestions.append(contentsOf: await generateCodingSuggestions(context))
        case .researching:
            suggestions.append(contentsOf: generateResearchSuggestions(context))
        case .debugging:
            suggestions.append(contentsOf: await generateDebuggingSuggestions(context))
        case .executing:
            suggestions.append(contentsOf: generateTerminalSuggestions(context))
        default:
            suggestions.append(contentsOf: generateGeneralSuggestions(context))
        }

        // Time-based suggestions
        suggestions.append(contentsOf: generateTimeBasedSuggestions(context))

        // Pattern-based suggestions
        suggestions.append(contentsOf: generatePatternBasedSuggestions(context))

        // Error-based suggestions
        if !context.recentErrors.isEmpty {
            suggestions.append(contentsOf: await generateErrorBasedSuggestions(context))
        }

        return suggestions
    }

    private func generateCodingSuggestions(_ context: WorkContext) async -> [Suggestion] {
        var suggestions: [Suggestion] = []

        // Suggest running tests if code was recently modified
        if let file = context.currentFile, file.contains("test") == false {
            suggestions.append(Suggestion(
                type: .action,
                category: .testing,
                title: "Run Tests",
                description: "It's a good time to run your test suite",
                confidence: 0.7,
                action: .runTests,
                timestamp: Date()
            ))
        }

        // Suggest code review if many changes
        if contextHistory.filter({ $0.activityType == .coding }).count > 20 {
            suggestions.append(Suggestion(
                type: .action,
                category: .codeQuality,
                title: "Consider Code Review",
                description: "You've made significant changes. Time for a review?",
                confidence: 0.65,
                action: .requestCodeReview,
                timestamp: Date()
            ))
        }

        // AI-powered suggestions using Claude
        if !Settings.shared.claudeAPIKey.isEmpty, let file = context.currentFile {
            do {
                let aiSuggestion = try await AIService.shared.callClaude(
                    prompt: """
                    Based on this coding context, provide ONE specific, actionable suggestion:
                    - Current file: \(file)
                    - Language: \(context.currentLanguage ?? "unknown")
                    - Time: \(context.timeOfDay.rawValue)
                    - Recent activity: Coding for extended period

                    Suggestion should be brief (max 1 sentence):
                    """,
                    maxTokens: 100
                )

                suggestions.append(Suggestion(
                    type: .insight,
                    category: .productivity,
                    title: "AI Insight",
                    description: aiSuggestion,
                    confidence: 0.8,
                    action: .none,
                    timestamp: Date()
                ))
            } catch {}
        }

        return suggestions
    }

    private func generateResearchSuggestions(_ context: WorkContext) -> [Suggestion] {
        var suggestions: [Suggestion] = []

        // Suggest documenting findings
        suggestions.append(Suggestion(
            type: .action,
            category: .documentation,
            title: "Document Your Research",
            description: "Save useful links and notes for future reference",
            confidence: 0.6,
            action: .createNote,
            timestamp: Date()
        ))

        // Suggest code snippets for common patterns found online
        if context.activeApp?.contains("Safari") ?? false || context.activeApp?.contains("Chrome") ?? false {
            suggestions.append(Suggestion(
                type: .action,
                category: .productivity,
                title: "Save Code Snippet",
                description: "Found useful code? Save it to your snippet library",
                confidence: 0.55,
                action: .saveSnippet,
                timestamp: Date()
            ))
        }

        return suggestions
    }

    private func generateDebuggingSuggestions(_ context: WorkContext) async -> [Suggestion] {
        var suggestions: [Suggestion] = []

        // Suggest taking a break if debugging for too long
        let recentDebuggingTime = contextHistory
            .filter { $0.activityType == .debugging && $0.timestamp > Date().addingTimeInterval(-3600) }
            .count

        if recentDebuggingTime > 20 { // More than 100 minutes
            suggestions.append(Suggestion(
                type: .wellbeing,
                category: .health,
                title: "Take a Break",
                description: "You've been debugging for a while. A fresh perspective might help!",
                confidence: 0.85,
                action: .takeBreak,
                timestamp: Date()
            ))
        }

        // AI-powered debugging suggestions
        if !Settings.shared.claudeAPIKey.isEmpty, !context.recentErrors.isEmpty {
            do {
                let error = context.recentErrors.last ?? ""
                let solution = try await AIService.shared.callClaude(
                    prompt: """
                    Provide a concise debugging tip for this error:
                    \(error.prefix(200))

                    Be specific and actionable (max 2 sentences):
                    """,
                    maxTokens: 150
                )

                suggestions.append(Suggestion(
                    type: .insight,
                    category: .debugging,
                    title: "Debugging Tip",
                    description: solution,
                    confidence: 0.75,
                    action: .none,
                    timestamp: Date()
                ))
            } catch {}
        }

        return suggestions
    }

    private func generateTerminalSuggestions(_ context: WorkContext) -> [Suggestion] {
        var suggestions: [Suggestion] = []

        // Git workflow suggestions
        if context.recentCommands.contains(where: { $0.contains("git add") }) &&
           !context.recentCommands.contains(where: { $0.contains("git commit") }) {
            suggestions.append(Suggestion(
                type: .action,
                category: .git,
                title: "Commit Your Changes",
                description: "You've staged files. Don't forget to commit!",
                confidence: 0.8,
                action: .gitCommit,
                timestamp: Date()
            ))
        }

        if context.recentCommands.contains(where: { $0.contains("git commit") }) &&
           !context.recentCommands.contains(where: { $0.contains("git push") }) {
            suggestions.append(Suggestion(
                type: .action,
                category: .git,
                title: "Push Your Commits",
                description: "Don't forget to push your local commits",
                confidence: 0.75,
                action: .gitPush,
                timestamp: Date()
            ))
        }

        return suggestions
    }

    private func generateGeneralSuggestions(_ context: WorkContext) -> [Suggestion] {
        var suggestions: [Suggestion] = []

        // Productivity suggestions based on time of day
        if context.timeOfDay == .night && !context.isWeekend {
            suggestions.append(Suggestion(
                type: .wellbeing,
                category: .health,
                title: "Consider Wrapping Up",
                description: "It's getting late. Make sure to get good rest!",
                confidence: 0.6,
                action: .none,
                timestamp: Date()
            ))
        }

        return suggestions
    }

    private func generateTimeBasedSuggestions(_ context: WorkContext) -> [Suggestion] {
        var suggestions: [Suggestion] = []

        // Morning suggestions
        if context.timeOfDay == .morning {
            suggestions.append(Suggestion(
                type: .insight,
                category: .productivity,
                title: "Morning Planning",
                description: "Start your day by reviewing your task list",
                confidence: 0.5,
                action: .none,
                timestamp: Date()
            ))
        }

        // End of day suggestions
        if context.timeOfDay == .evening {
            suggestions.append(Suggestion(
                type: .action,
                category: .productivity,
                title: "Daily Wrap-up",
                description: "Review what you accomplished today and plan for tomorrow",
                confidence: 0.55,
                action: .none,
                timestamp: Date()
            ))
        }

        return suggestions
    }

    private func generatePatternBasedSuggestions(_ context: WorkContext) -> [Suggestion] {
        var suggestions: [Suggestion] = []

        // Analyze recent context history for patterns
        let recentContexts = contextHistory.suffix(20)

        // Check for context switching pattern
        let uniqueApps = Set(recentContexts.compactMap { $0.activeApp })
        if uniqueApps.count > 8 {
            suggestions.append(Suggestion(
                type: .insight,
                category: .focus,
                title: "Reduce Context Switching",
                description: "You've switched between many apps. Try focusing on one task at a time.",
                confidence: 0.7,
                action: .none,
                timestamp: Date()
            ))
        }

        // Check for repetitive file editing
        let fileEdits = recentContexts.compactMap { $0.currentFile }
        let fileCounts = Dictionary(grouping: fileEdits, by: { $0 }).mapValues { $0.count }
        if let (file, count) = fileCounts.max(by: { $0.value < $1.value }), count > 10 {
            suggestions.append(Suggestion(
                type: .insight,
                category: .codeQuality,
                title: "Frequent File Edits",
                description: "You're editing \((file as NSString).lastPathComponent) frequently. Consider refactoring.",
                confidence: 0.65,
                action: .none,
                timestamp: Date()
            ))
        }

        return suggestions
    }

    private func generateErrorBasedSuggestions(_ context: WorkContext) async -> [Suggestion] {
        var suggestions: [Suggestion] = []

        // Group similar errors
        let errorCounts = Dictionary(grouping: context.recentErrors, by: { $0 }).mapValues { $0.count }

        if let (error, count) = errorCounts.max(by: { $0.value < $1.value }), count >= 2 {
            suggestions.append(Suggestion(
                type: .action,
                category: .debugging,
                title: "Recurring Error",
                description: "This error appeared \(count) times. It might need deeper investigation.",
                confidence: 0.8,
                action: .investigateError,
                timestamp: Date()
            ))
        }

        return suggestions
    }

    // MARK: - Suggestion Ranking

    private func rankSuggestions(_ suggestions: [Suggestion], for context: WorkContext) -> [Suggestion] {
        return suggestions.sorted { s1, s2 in
            // Calculate relevance score
            let score1 = calculateRelevanceScore(s1, for: context)
            let score2 = calculateRelevanceScore(s2, for: context)

            return score1 > score2
        }
    }

    private func calculateRelevanceScore(_ suggestion: Suggestion, for context: WorkContext) -> Double {
        var score = suggestion.confidence

        // Boost score based on category match
        switch (suggestion.category, context.activityType) {
        case (.testing, .coding): score += 0.2
        case (.debugging, .debugging): score += 0.3
        case (.git, .coding): score += 0.15
        case (.health, _): score += 0.1 // Always somewhat relevant
        default: break
        }

        // Boost for time-appropriate suggestions
        if suggestion.category == .health && context.timeOfDay == .night {
            score += 0.2
        }

        // Reduce score for recently shown suggestions
        if suggestionHistory.contains(where: { $0.title == suggestion.title &&
            Date().timeIntervalSince($0.timestamp) < 1800 }) { // 30 minutes
            score -= 0.3
        }

        return max(0, min(1, score))
    }

    // MARK: - Suggestion Presentation

    private func presentSuggestion(_ suggestion: Suggestion) {
        suggestionHistory.append(suggestion)

        // Limit history
        if suggestionHistory.count > 100 {
            suggestionHistory.removeFirst()
        }

        let activity = Activity(
            title: suggestion.title,
            description: suggestion.description,
            type: mapSuggestionToActivityType(suggestion)
        )

        DispatchQueue.main.async { [weak self] in
            self?.activityCallback?(activity)
        }

        print("💡 Suggestion: \(suggestion.title)")
    }

    private func mapSuggestionToActivityType(_ suggestion: Suggestion) -> ActivityType {
        switch suggestion.category {
        case .testing, .codeQuality:
            return .vsCodeFix
        case .git:
            return .githubPR
        case .documentation:
            return .learning
        default:
            return .learning
        }
    }

    // MARK: - Public API

    func updateFileContext(file: String, language: String) {
        currentFile = file
        currentLanguage = language
        updateCurrentContext()
    }

    func reportError(_ error: String) {
        recentErrors.append(error)
        if recentErrors.count > 20 {
            recentErrors.removeFirst()
        }

        // Immediately generate error-based suggestions
        Task {
            if let context = currentContext {
                let suggestions = await generateErrorBasedSuggestions(context)
                for suggestion in suggestions {
                    presentSuggestion(suggestion)
                }
            }
        }
    }

    func reportCommand(_ command: String) {
        recentCommands.append(command)
        if recentCommands.count > 50 {
            recentCommands.removeFirst()
        }
        updateCurrentContext()
    }

    func getSuggestionHistory() -> [Suggestion] {
        return suggestionHistory.sorted { $0.timestamp > $1.timestamp }
    }

    func clearSuggestionCache() {
        suggestionCache.removeAll()
        print("🗑️ Suggestion cache cleared")
    }
}

// MARK: - Data Models

struct WorkContext {
    let timestamp: Date
    var activeApp: String?
    var appBundleId: String?
    var activityType: ActivityType = .other
    var currentFile: String?
    var currentLanguage: String?
    var recentErrors: [String] = []
    var recentCommands: [String] = []
    var timeOfDay: TimeOfDay = .morning
    var isWeekend: Bool = false

    var cacheKey: String {
        return "\(activeApp ?? "")_\(activityType.rawValue)_\(timeOfDay.rawValue)"
    }
}

enum ActivityType: String {
    case coding
    case debugging
    case researching
    case communicating
    case executing
    case other
}

enum TimeOfDay: String {
    case morning
    case afternoon
    case evening
    case night
}

struct Suggestion {
    let id = UUID()
    let type: SuggestionType
    let category: SuggestionCategory
    let title: String
    let description: String
    let confidence: Double
    let action: SuggestionAction
    let timestamp: Date
}

enum SuggestionType {
    case action      // Actionable suggestion
    case insight     // Informational insight
    case wellbeing   // Health/wellness suggestion
    case warning     // Warning or alert
}

enum SuggestionCategory {
    case testing
    case codeQuality
    case debugging
    case git
    case documentation
    case productivity
    case focus
    case health
}

enum SuggestionAction {
    case runTests
    case gitCommit
    case gitPush
    case requestCodeReview
    case createNote
    case saveSnippet
    case takeBreak
    case investigateError
    case none
}
