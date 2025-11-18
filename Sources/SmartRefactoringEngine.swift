import Foundation

// MARK: - Smart Refactoring Engine
// AI-powered code refactoring with intelligent suggestions

class SmartRefactoringEngine {
    static let shared = SmartRefactoringEngine()

    private let queue = DispatchQueue(label: "com.backgroundai.refactoring", qos: .userInitiated)
    private var refactoringHistory: [RefactoringOperation] = []

    private init() {}

    // MARK: - Refactoring Detection & Suggestions

    func analyzeForRefactoring(file: String, content: String, language: String) async -> [RefactoringSuggestion] {
        var suggestions: [RefactoringSuggestion] = []

        print("🔧 Analyzing \(file) for refactoring opportunities...")

        // Detect various refactoring opportunities
        suggestions.append(contentsOf: detectExtractMethod(content, language))
        suggestions.append(contentsOf: detectExtractVariable(content, language))
        suggestions.append(contentsOf: detectRenameVariable(content, language))
        suggestions.append(contentsOf: detectInlineVariable(content, language))
        suggestions.append(contentsOf: detectExtractClass(content, language))
        suggestions.append(contentsOf: detectMoveMethod(content, language))
        suggestions.append(contentsOf: detectReplaceConditional(content, language))
        suggestions.append(contentsOf: detectIntroduceParameter(content, language))
        suggestions.append(contentsOf: detectRemoveDeadCode(content, language))
        suggestions.append(contentsOf: detectSimplifyBooleanExpression(content, language))

        // AI-powered refactoring suggestions
        if !Settings.shared.claudeAPIKey.isEmpty {
            suggestions.append(contentsOf: await generateAIRefactoringSuggestions(content, language))
        }

        // Rank suggestions by impact
        return suggestions.sorted { $0.impact > $1.impact }
    }

    // MARK: - Refactoring Patterns

    private func detectExtractMethod(_ content: String, _ language: String) -> [RefactoringSuggestion] {
        var suggestions: [RefactoringSuggestion] = []

        let lines = content.components(separatedBy: .newlines)

        // Find code blocks that should be extracted
        var consecutiveLines = 0
        var startLine = 0

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
                consecutiveLines = 0
                continue
            }

            if !trimmed.contains("func") && !trimmed.contains("def") && !trimmed.contains("function") {
                if consecutiveLines == 0 {
                    startLine = index
                }
                consecutiveLines += 1

                // If we have 8+ lines of code in sequence, suggest extract method
                if consecutiveLines >= 8 {
                    let codeBlock = lines[startLine...index].joined(separator: "\n")

                    // Check if it's actually extractable (has cohesive logic)
                    if isExtractable(codeBlock) {
                        suggestions.append(RefactoringSuggestion(
                            type: .extractMethod,
                            severity: .medium,
                            title: "Extract Method",
                            description: "Extract \(consecutiveLines) lines into a separate method",
                            location: startLine + 1,
                            impact: 0.7,
                            before: codeBlock,
                            after: generateExtractedMethod(codeBlock, language)
                        ))

                        consecutiveLines = 0
                    }
                }
            } else {
                consecutiveLines = 0
            }
        }

        return suggestions
    }

    private func isExtractable(_ code: String) -> Bool {
        // Check if code block is cohesive enough to extract
        let lines = code.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        // Should have at least some operations
        let hasOperations = code.contains("=") || code.contains("if") || code.contains("for")

        // Should not be just variable declarations
        let declarationCount = lines.filter { $0.contains("let ") || $0.contains("var ") || $0.contains("const ") }.count
        let notJustDeclarations = declarationCount < lines.count / 2

        return hasOperations && notJustDeclarations && lines.count >= 5
    }

    private func generateExtractedMethod(_ code: String, _ language: String) -> String {
        switch language {
        case "swift":
            return """
            private func extractedMethod() {
                \(code)
            }
            """
        case "javascript":
            return """
            function extractedMethod() {
                \(code)
            }
            """
        case "python":
            return """
            def extracted_method(self):
                \(code)
            """
        default:
            return code
        }
    }

    private func detectExtractVariable(_ content: String, _ language: String) -> [RefactoringSuggestion] {
        var suggestions: [RefactoringSuggestion] = []

        // Find complex expressions that should be extracted to variables
        let complexPatterns = [
            "\\([^)]{50,}\\)",  // Long expressions in parentheses
            "\\[[^\\]]{50,}\\]", // Long array/dictionary literals
            "\\.\\w+\\.\\w+\\.\\w+\\.\\w+" // Deep property access chains
        ]

        for pattern in complexPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))

                for match in matches {
                    if let range = Range(match.range, in: content) {
                        let expression = String(content[range])

                        suggestions.append(RefactoringSuggestion(
                            type: .extractVariable,
                            severity: .low,
                            title: "Extract Variable",
                            description: "Extract complex expression to improve readability",
                            location: 0,
                            impact: 0.5,
                            before: expression,
                            after: "let extractedValue = \(expression)"
                        ))
                    }
                }
            }
        }

        return suggestions
    }

    private func detectRenameVariable(_ content: String, _ language: String) -> [RefactoringSuggestion] {
        var suggestions: [RefactoringSuggestion] = []

        // Find poorly named variables
        let poorNames = ["temp", "tmp", "data", "info", "obj", "x", "y", "z", "a", "b", "c", "foo", "bar"]

        for name in poorNames {
            let pattern = "\\b\(name)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))

                if !matches.isEmpty {
                    suggestions.append(RefactoringSuggestion(
                        type: .rename,
                        severity: .low,
                        title: "Rename Variable",
                        description: "'\(name)' is not descriptive. Consider renaming for clarity.",
                        location: 0,
                        impact: 0.4,
                        before: name,
                        after: "\(name)Renamed // TODO: Choose better name"
                    ))
                }
            }
        }

        return suggestions
    }

    private func detectInlineVariable(_ content: String, _ language: String) -> [RefactoringSuggestion] {
        var suggestions: [RefactoringSuggestion] = []

        let lines = content.components(separatedBy: .newlines)

        // Find single-use variables that can be inlined
        for (index, line) in lines.enumerated() {
            if line.contains("let ") || line.contains("const ") || line.contains("var ") {
                let parts = line.components(separatedBy: "=")
                if parts.count == 2 {
                    let varName = parts[0]
                        .replacingOccurrences(of: "let ", with: "")
                        .replacingOccurrences(of: "const ", with: "")
                        .replacingOccurrences(of: "var ", with: "")
                        .trimmingCharacters(in: .whitespaces)

                    // Count usage
                    let restOfCode = lines[(index+1)...].joined()
                    let usageCount = restOfCode.components(separatedBy: varName).count - 1

                    if usageCount == 1 {
                        suggestions.append(RefactoringSuggestion(
                            type: .inlineVariable,
                            severity: .low,
                            title: "Inline Variable",
                            description: "Variable '\(varName)' is only used once, consider inlining",
                            location: index + 1,
                            impact: 0.3,
                            before: line,
                            after: "// Inline this variable"
                        ))
                    }
                }
            }
        }

        return suggestions
    }

    private func detectExtractClass(_ content: String, _ language: String) -> [RefactoringSuggestion] {
        var suggestions: [RefactoringSuggestion] = []

        let lines = content.components(separatedBy: .newlines)

        // Check class size
        if let classStart = lines.firstIndex(where: { $0.contains("class ") }) {
            var braceCount = 0
            var classSize = 0

            for i in classStart..<lines.count {
                if lines[i].contains("{") { braceCount += 1 }
                if lines[i].contains("}") { braceCount -= 1 }
                if braceCount > 0 { classSize += 1 }
                if braceCount == 0 && i > classStart { break }
            }

            if classSize > 200 {
                suggestions.append(RefactoringSuggestion(
                    type: .extractClass,
                    severity: .high,
                    title: "Extract Class",
                    description: "Class has \(classSize) lines. Consider splitting into multiple classes.",
                    location: classStart + 1,
                    impact: 0.8,
                    before: "Large class",
                    after: "Split into focused classes"
                ))
            }
        }

        return suggestions
    }

    private func detectMoveMethod(_ content: String, _ language: String) -> [RefactoringSuggestion] {
        var suggestions: [RefactoringSuggestion] = []

        // Detect methods that might belong to a different class
        // This is a simplified heuristic
        let lines = content.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            if line.contains("func ") || line.contains("def ") || line.contains("function ") {
                // Check if method uses external class extensively
                let methodBody = extractMethodBody(from: lines, startingAt: index)

                // Count external class references
                var externalRefs: [String: Int] = [:]

                let words = methodBody.components(separatedBy: .whitespacesAndNewlines)
                for word in words {
                    if word.contains(".") && !word.starts(with: "self.") && !word.starts(with: "this.") {
                        let className = word.components(separatedBy: ".").first ?? ""
                        externalRefs[className, default: 0] += 1
                    }
                }

                // If method references one external class heavily, suggest move
                if let (className, count) = externalRefs.max(by: { $0.value < $1.value }), count >= 3 {
                    suggestions.append(RefactoringSuggestion(
                        type: .moveMethod,
                        severity: .medium,
                        title: "Move Method",
                        description: "Method references '\(className)' extensively. Consider moving it there.",
                        location: index + 1,
                        impact: 0.6,
                        before: "Method in current class",
                        after: "Method in \(className)"
                    ))
                }
            }
        }

        return suggestions
    }

    private func extractMethodBody(from lines: [String], startingAt index: Int) -> String {
        var body = ""
        var braceCount = 0
        var started = false

        for i in index..<lines.count {
            let line = lines[i]
            for char in line {
                if char == "{" { braceCount += 1; started = true }
                if char == "}" { braceCount -= 1 }
            }

            if started { body += line + "\n" }
            if started && braceCount == 0 { break }
        }

        return body
    }

    private func detectReplaceConditional(_ content: String, _ language: String) -> [RefactoringSuggestion] {
        var suggestions: [RefactoringSuggestion] = []

        // Find complex conditionals
        let lines = content.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            if line.contains("if") && (line.components(separatedBy: "&&").count > 3 || line.components(separatedBy: "||").count > 3) {
                suggestions.append(RefactoringSuggestion(
                    type: .replaceConditional,
                    severity: .medium,
                    title: "Replace Complex Conditional",
                    description: "Complex conditional should be extracted to a method",
                    location: index + 1,
                    impact: 0.65,
                    before: line,
                    after: "if isValidCondition() { ... }"
                ))
            }
        }

        return suggestions
    }

    private func detectIntroduceParameter(_ content: String, _ language: String) -> [RefactoringSuggestion] {
        var suggestions: [RefactoringSuggestion] = []

        // Detect hardcoded values that should be parameters
        let lines = content.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            // Find magic numbers/strings
            let numberPattern = try? NSRegularExpression(pattern: "\\b\\d{2,}\\b", options: [])
            let stringPattern = try? NSRegularExpression(pattern: "\"[^\"]{10,}\"", options: [])

            let range = NSRange(line.startIndex..., in: line)

            if let matches = numberPattern?.matches(in: line, range: range), !matches.isEmpty {
                suggestions.append(RefactoringSuggestion(
                    type: .introduceParameter,
                    severity: .low,
                    title: "Introduce Parameter",
                    description: "Magic number found - consider making it a parameter or constant",
                    location: index + 1,
                    impact: 0.4,
                    before: line,
                    after: "// Extract to parameter/constant"
                ))
            }
        }

        return suggestions
    }

    private func detectRemoveDeadCode(_ content: String, _ language: String) -> [RefactoringSuggestion] {
        var suggestions: [RefactoringSuggestion] = []

        let lines = content.components(separatedBy: .newlines)

        // Detect commented code
        var commentedCodeLines = 0
        var commentStart = 0

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
                // Check if it looks like code (has operators, keywords, etc.)
                if trimmed.contains("=") || trimmed.contains("if") || trimmed.contains("func") {
                    if commentedCodeLines == 0 {
                        commentStart = index
                    }
                    commentedCodeLines += 1
                }
            } else {
                if commentedCodeLines >= 3 {
                    suggestions.append(RefactoringSuggestion(
                        type: .removeDeadCode,
                        severity: .low,
                        title: "Remove Dead Code",
                        description: "Found \(commentedCodeLines) lines of commented code",
                        location: commentStart + 1,
                        impact: 0.3,
                        before: "Commented code",
                        after: "Remove if not needed"
                    ))
                }
                commentedCodeLines = 0
            }
        }

        // Detect unreachable code
        for (index, line) in lines.enumerated() {
            if line.contains("return") && index < lines.count - 2 {
                let nextLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
                if !nextLine.isEmpty && !nextLine.hasPrefix("}") && !nextLine.hasPrefix("//") {
                    suggestions.append(RefactoringSuggestion(
                        type: .removeDeadCode,
                        severity: .medium,
                        title: "Unreachable Code",
                        description: "Code after return statement is unreachable",
                        location: index + 2,
                        impact: 0.5,
                        before: "Code after return",
                        after: "Remove unreachable code"
                    ))
                }
            }
        }

        return suggestions
    }

    private func detectSimplifyBooleanExpression(_ content: String, _ language: String) -> [RefactoringSuggestion] {
        var suggestions: [RefactoringSuggestion] = []

        // Find redundant boolean expressions
        let patterns = [
            "== true",
            "== false",
            "!= true",
            "!= false"
        ]

        for pattern in patterns {
            if content.contains(pattern) {
                suggestions.append(RefactoringSuggestion(
                    type: .simplifyBoolean,
                    severity: .low,
                    title: "Simplify Boolean Expression",
                    description: "Redundant boolean comparison found",
                    location: 0,
                    impact: 0.3,
                    before: "if value == true",
                    after: "if value"
                ))
                break
            }
        }

        return suggestions
    }

    // MARK: - AI-Powered Refactoring

    private func generateAIRefactoringSuggestions(_ content: String, _ language: String) async -> [RefactoringSuggestion] {
        var suggestions: [RefactoringSuggestion] = []

        do {
            let prompt = """
            Analyze this \(language) code and suggest 2-3 most important refactorings:

            \(content.prefix(2000))

            For each suggestion provide:
            1. Refactoring type (e.g., Extract Method, Rename, etc.)
            2. Brief reason (1 sentence)
            3. Impact (high/medium/low)

            Format as JSON array:
            [{"type": "...", "reason": "...", "impact": "..."}]
            """

            let response = try await AIService.shared.callClaude(prompt: prompt, maxTokens: 400)

            // Parse AI response (simplified)
            if response.contains("Extract Method") || response.contains("extract method") {
                suggestions.append(RefactoringSuggestion(
                    type: .extractMethod,
                    severity: .high,
                    title: "AI Suggestion: Extract Method",
                    description: response.prefix(200).description,
                    location: 0,
                    impact: 0.8,
                    before: "",
                    after: ""
                ))
            }
        } catch {}

        return suggestions
    }

    // MARK: - Apply Refactoring

    func applyRefactoring(_ suggestion: RefactoringSuggestion, to content: String) -> String {
        var result = content

        switch suggestion.type {
        case .rename:
            result = result.replacingOccurrences(of: suggestion.before, with: suggestion.after)

        case .extractVariable:
            // This would require more sophisticated code manipulation
            result = "// TODO: Apply extract variable refactoring\n" + result

        case .removeDeadCode:
            // Remove the suggested dead code
            result = result.replacingOccurrences(of: suggestion.before, with: "")

        default:
            // Other refactorings would require AST manipulation
            result = "// TODO: Apply \(suggestion.type) refactoring\n" + result
        }

        // Record the operation
        refactoringHistory.append(RefactoringOperation(
            timestamp: Date(),
            suggestion: suggestion,
            applied: true
        ))

        return result
    }

    // MARK: - Public API

    func getRefactoringHistory() -> [RefactoringOperation] {
        return refactoringHistory.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Data Models

struct RefactoringSuggestion {
    let id = UUID()
    let type: RefactoringType
    let severity: RefactoringSeverity
    let title: String
    let description: String
    let location: Int
    let impact: Double
    let before: String
    let after: String
}

enum RefactoringType {
    case extractMethod
    case extractVariable
    case extractClass
    case inlineVariable
    case rename
    case moveMethod
    case replaceConditional
    case introduceParameter
    case removeDeadCode
    case simplifyBoolean
}

enum RefactoringSeverity {
    case high
    case medium
    case low
}

struct RefactoringOperation {
    let timestamp: Date
    let suggestion: RefactoringSuggestion
    let applied: Bool
}
