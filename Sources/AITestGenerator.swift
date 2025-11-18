import Foundation

// MARK: - AI-Powered Test Generator
// Automatically generates comprehensive test cases for code

class AITestGenerator {
    static let shared = AITestGenerator()

    private let queue = DispatchQueue(label: "com.backgroundai.testgen", qos: .utility)
    private var generatedTests: [GeneratedTest] = []
    private var testCoverage: [String: CoverageReport] = [:]

    private init() {}

    // MARK: - Test Generation

    func generateTests(for file: String, code: String, language: String) async throws -> GeneratedTestSuite {
        print("🧪 Generating tests for \(file)...")

        var testSuite = GeneratedTestSuite(sourceFile: file, language: language)

        // Analyze code structure
        let analysis = analyzeCode(code, language: language)

        // Generate different types of tests
        testSuite.unitTests = await generateUnitTests(analysis, language: language)
        testSuite.integrationTests = await generateIntegrationTests(analysis, language: language)
        testSuite.edgeCaseTests = generateEdgeCaseTests(analysis, language: language)
        testSuite.errorHandlingTests = generateErrorHandlingTests(analysis, language: language)

        // Generate mocks if needed
        if analysis.hasDependencies {
            testSuite.mocks = await generateMocks(analysis, language: language)
        }

        // Generate test fixtures
        testSuite.fixtures = generateFixtures(analysis, language: language)

        // Calculate estimated coverage
        testSuite.estimatedCoverage = estimateCoverage(testSuite, analysis)

        // Save generated tests
        generatedTests.append(GeneratedTest(
            timestamp: Date(),
            sourceFile: file,
            testSuite: testSuite
        ))

        return testSuite
    }

    // MARK: - Code Analysis

    private func analyzeCode(_ code: String, language: String) -> CodeStructure {
        var structure = CodeStructure()

        let lines = code.components(separatedBy: .newlines)

        // Extract functions
        for (index, line) in lines.enumerated() {
            if let function = extractFunction(from: line, language: language) {
                // Get function body
                let body = extractFunctionBody(from: lines, startingAt: index, language: language)
                function.body = body

                // Analyze parameters
                function.parameters = extractParameters(from: line, language: language)

                // Analyze return type
                function.returnType = extractReturnType(from: line, language: language)

                // Check for async
                function.isAsync = line.contains("async") || line.contains("await")

                // Check for throws
                function.canThrow = line.contains("throws") || line.contains("raise")

                structure.functions.append(function)
            }

            // Extract classes
            if line.contains("class ") || line.contains("struct ") {
                if let className = extractClassName(from: line, language: language) {
                    structure.classes.append(className)
                }
            }

            // Detect dependencies
            if line.contains("import ") || line.contains("require") || line.contains("#include") {
                if let dependency = extractDependency(from: line) {
                    structure.dependencies.append(dependency)
                }
            }
        }

        structure.hasDependencies = !structure.dependencies.isEmpty
        structure.complexityScore = calculateComplexity(code)

        return structure
    }

    private func extractFunction(from line: String, language: String) -> FunctionInfo? {
        let patterns: [String: String] = [
            "swift": "func\\s+(\\w+)\\s*\\(",
            "javascript": "function\\s+(\\w+)\\s*\\(|const\\s+(\\w+)\\s*=.*=>",
            "python": "def\\s+(\\w+)\\s*\\(",
            "java": "(public|private|protected)?\\s*\\w+\\s+(\\w+)\\s*\\("
        ]

        guard let pattern = patterns[language],
              let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let range = NSRange(line.startIndex..., in: line)
        if let match = regex.firstMatch(in: line, range: range) {
            let nameRange = match.range(at: match.numberOfRanges - 1)
            if let swiftRange = Range(nameRange, in: line) {
                let name = String(line[swiftRange])
                return FunctionInfo(name: name, language: language)
            }
        }

        return nil
    }

    private func extractFunctionBody(from lines: [String], startingAt index: Int, language: String) -> String {
        var body = ""
        var braceCount = 0
        var started = false

        for i in index..<lines.count {
            let line = lines[i]

            for char in line {
                if char == "{" {
                    braceCount += 1
                    started = true
                } else if char == "}" {
                    braceCount -= 1
                }
            }

            if started {
                body += line + "\n"
            }

            if started && braceCount == 0 {
                break
            }
        }

        return body
    }

    private func extractParameters(from line: String, language: String) -> [Parameter] {
        var parameters: [Parameter] = []

        // Extract parameters from function signature
        if let startIndex = line.firstIndex(of: "("),
           let endIndex = line.firstIndex(of: ")") {
            let paramString = String(line[line.index(after: startIndex)..<endIndex])
            let params = paramString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

            for param in params where !param.isEmpty {
                let parts = param.components(separatedBy: ":")
                if parts.count >= 2 {
                    parameters.append(Parameter(
                        name: parts[0].trimmingCharacters(in: .whitespaces),
                        type: parts[1].trimmingCharacters(in: .whitespaces)
                    ))
                }
            }
        }

        return parameters
    }

    private func extractReturnType(from line: String, language: String) -> String? {
        if language == "swift" {
            if let range = line.range(of: "->") {
                let returnPart = String(line[range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: " ").first
                return returnPart
            }
        }
        return nil
    }

    private func extractClassName(from line: String, language: String) -> String? {
        let patterns = ["class\\s+(\\w+)", "struct\\s+(\\w+)"]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                let nameRange = match.range(at: 1)
                if let swiftRange = Range(nameRange, in: line) {
                    return String(line[swiftRange])
                }
            }
        }

        return nil
    }

    private func extractDependency(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("import ") {
            return trimmed.replacingOccurrences(of: "import ", with: "")
                .components(separatedBy: " ").first
        }
        return nil
    }

    private func calculateComplexity(_ code: String) -> Int {
        let complexityIndicators = ["if ", "else ", "while ", "for ", "switch ", "case "]
        var complexity = 1

        for indicator in complexityIndicators {
            complexity += code.components(separatedBy: indicator).count - 1
        }

        return complexity
    }

    // MARK: - Test Generation (AI-Powered)

    private func generateUnitTests(_ structure: CodeStructure, language: String) async -> [String] {
        var tests: [String] = []

        for function in structure.functions {
            if let test = await generateUnitTest(for: function, language: language) {
                tests.append(test)
            }
        }

        return tests
    }

    private func generateUnitTest(for function: FunctionInfo, language: String) async -> String? {
        guard !Settings.shared.claudeAPIKey.isEmpty else {
            return generateBasicUnitTest(for: function, language: language)
        }

        do {
            let prompt = """
            Generate a comprehensive unit test for this \(language) function:

            Function: \(function.name)
            Parameters: \(function.parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", "))
            Returns: \(function.returnType ?? "void")
            \(function.isAsync ? "Is async" : "")
            \(function.canThrow ? "Can throw errors" : "")

            Function body:
            \(function.body)

            Generate a complete, runnable test that:
            1. Tests the happy path
            2. Uses appropriate test framework for \(language)
            3. Includes assertions
            4. Has clear test name

            Return ONLY the test code, no explanations:
            """

            let testCode = try await AIService.shared.callClaude(prompt: prompt, maxTokens: 500)
            return testCode
        } catch {
            return generateBasicUnitTest(for: function, language: language)
        }
    }

    private func generateBasicUnitTest(for function: FunctionInfo, language: String) -> String {
        switch language {
        case "swift":
            return """
            func test\(function.name.capitalized)() \(function.canThrow ? "throws" : "") {
                // Arrange
                \(function.parameters.map { "let \($0.name) = <#\($0.type)#>" }.joined(separator: "\n    "))

                // Act
                \(function.isAsync ? "let result = try await" : "let result =") \(function.name)(\(function.parameters.map { "\($0.name): \($0.name)" }.joined(separator: ", ")))

                // Assert
                XCTAssertNotNil(result)
            }
            """

        case "javascript":
            return """
            test('\(function.name) should work correctly', \(function.isAsync ? "async" : "")() => {
                // Arrange
                \(function.parameters.map { "const \($0.name) = <#value#>;" }.joined(separator: "\n    "))

                // Act
                const result = \(function.isAsync ? "await" : "") \(function.name)(\(function.parameters.map { $0.name }.joined(separator: ", ")));

                // Assert
                expect(result).toBeDefined();
            });
            """

        case "python":
            return """
            def test_\(function.name)(self):
                # Arrange
                \(function.parameters.map { "\($0.name) = None  # TODO: Set test value" }.joined(separator: "\n        "))

                # Act
                result = \(function.name)(\(function.parameters.map { $0.name }.joined(separator: ", ")))

                # Assert
                self.assertIsNotNone(result)
            """

        default:
            return "// Test for \(function.name)"
        }
    }

    private func generateIntegrationTests(_ structure: CodeStructure, language: String) async -> [String] {
        var tests: [String] = []

        // Generate integration tests for classes with dependencies
        if structure.hasDependencies && !structure.classes.isEmpty {
            for className in structure.classes {
                if let test = await generateIntegrationTest(for: className, dependencies: structure.dependencies, language: language) {
                    tests.append(test)
                }
            }
        }

        return tests
    }

    private func generateIntegrationTest(for className: String, dependencies: [String], language: String) async -> String? {
        guard !Settings.shared.claudeAPIKey.isEmpty else { return nil }

        do {
            let prompt = """
            Generate an integration test for class \(className) in \(language).
            Dependencies: \(dependencies.joined(separator: ", "))

            The test should:
            1. Test interaction between components
            2. Set up required dependencies
            3. Verify end-to-end behavior

            Return ONLY the test code:
            """

            return try await AIService.shared.callClaude(prompt: prompt, maxTokens: 600)
        } catch {
            return nil
        }
    }

    private func generateEdgeCaseTests(_ structure: CodeStructure, language: String) -> [String] {
        var tests: [String] = []

        for function in structure.functions {
            // Generate tests for edge cases
            tests.append(contentsOf: generateEdgeCaseTests(for: function, language: language))
        }

        return tests
    }

    private func generateEdgeCaseTests(for function: FunctionInfo, language: String) -> [String] {
        var tests: [String] = []

        // Empty input test
        if !function.parameters.isEmpty {
            tests.append("// TODO: Test with empty/nil inputs")
        }

        // Boundary value tests
        for param in function.parameters {
            if param.type.contains("Int") || param.type.contains("Number") {
                tests.append("// TODO: Test \(function.name) with min/max values for \(param.name)")
            }
            if param.type.contains("String") {
                tests.append("// TODO: Test \(function.name) with empty string for \(param.name)")
            }
            if param.type.contains("Array") || param.type.contains("List") {
                tests.append("// TODO: Test \(function.name) with empty array for \(param.name)")
            }
        }

        return tests
    }

    private func generateErrorHandlingTests(_ structure: CodeStructure, language: String) -> [String] {
        var tests: [String] = []

        for function in structure.functions where function.canThrow {
            tests.append("// TODO: Test error handling for \(function.name)")
        }

        return tests
    }

    private func generateMocks(_ structure: CodeStructure, language: String) async -> [String] {
        var mocks: [String] = []

        for dependency in structure.dependencies {
            if let mock = await generateMock(for: dependency, language: language) {
                mocks.append(mock)
            }
        }

        return mocks
    }

    private func generateMock(for dependency: String, language: String) async -> String? {
        guard !Settings.shared.claudeAPIKey.isEmpty else { return nil }

        do {
            let prompt = """
            Generate a mock/stub for the \(dependency) dependency in \(language).
            Include common methods that would be needed for testing.

            Return ONLY the mock code:
            """

            return try await AIService.shared.callClaude(prompt: prompt, maxTokens: 400)
        } catch {
            return nil
        }
    }

    private func generateFixtures(_ structure: CodeStructure, language: String) -> [String] {
        var fixtures: [String] = []

        // Generate test data fixtures
        for className in structure.classes {
            fixtures.append("// TODO: Generate fixture data for \(className)")
        }

        return fixtures
    }

    private func estimateCoverage(_ testSuite: GeneratedTestSuite, _ structure: CodeStructure) -> Double {
        let totalFunctions = structure.functions.count
        let testedFunctions = testSuite.unitTests.count

        return totalFunctions > 0 ? Double(testedFunctions) / Double(totalFunctions) * 100.0 : 0.0
    }

    // MARK: - Test Suite Export

    func exportTestSuite(_ testSuite: GeneratedTestSuite, format: TestExportFormat = .framework) -> String {
        var output = ""

        switch testSuite.language {
        case "swift":
            output = exportSwiftTests(testSuite, format: format)
        case "javascript":
            output = exportJavaScriptTests(testSuite, format: format)
        case "python":
            output = exportPythonTests(testSuite, format: format)
        default:
            output = exportGenericTests(testSuite)
        }

        return output
    }

    private func exportSwiftTests(_ testSuite: GeneratedTestSuite, format: TestExportFormat) -> String {
        var output = """
        import XCTest
        @testable import YourModule

        class \(testSuite.sourceFile.replacingOccurrences(of: ".swift", with: ""))Tests: XCTestCase {

        """

        // Add unit tests
        for test in testSuite.unitTests {
            output += "\n\(test)\n"
        }

        // Add integration tests
        for test in testSuite.integrationTests {
            output += "\n\(test)\n"
        }

        output += "\n}\n"

        return output
    }

    private func exportJavaScriptTests(_ testSuite: GeneratedTestSuite, format: TestExportFormat) -> String {
        var output = """
        const { describe, it, expect } = require('@jest/globals');

        describe('\(testSuite.sourceFile)', () => {

        """

        for test in testSuite.unitTests {
            output += "\n\(test)\n"
        }

        output += "\n});\n"

        return output
    }

    private func exportPythonTests(_ testSuite: GeneratedTestSuite, format: TestExportFormat) -> String {
        var output = """
        import unittest

        class Test\(testSuite.sourceFile.replacingOccurrences(of: ".py", with: "").capitalized)(unittest.TestCase):

        """

        for test in testSuite.unitTests {
            output += "\n    \(test)\n"
        }

        output += """

        if __name__ == '__main__':
            unittest.main()
        """

        return output
    }

    private func exportGenericTests(_ testSuite: GeneratedTestSuite) -> String {
        return testSuite.unitTests.joined(separator: "\n\n")
    }

    // MARK: - Coverage Analysis

    func analyzeCoverage(for file: String, testFile: String) -> CoverageReport {
        var report = CoverageReport(sourceFile: file, testFile: testFile)

        // This would integrate with actual coverage tools
        // For now, we estimate based on generated tests

        report.lineCoverage = 75.0 // Placeholder
        report.branchCoverage = 60.0 // Placeholder
        report.functionCoverage = 80.0 // Placeholder

        return report
    }

    // MARK: - Public API

    func getGeneratedTests() -> [GeneratedTest] {
        return generatedTests.sorted { $0.timestamp > $1.timestamp }
    }

    func saveTestSuite(_ testSuite: GeneratedTestSuite, to path: URL) throws {
        let content = exportTestSuite(testSuite)
        try content.write(to: path, atomically: true, encoding: .utf8)
        print("💾 Test suite saved to: \(path.path)")
    }
}

// MARK: - Data Models

class FunctionInfo {
    let name: String
    let language: String
    var parameters: [Parameter] = []
    var returnType: String?
    var body: String = ""
    var isAsync: Bool = false
    var canThrow: Bool = false

    init(name: String, language: String) {
        self.name = name
        self.language = language
    }
}

struct Parameter {
    let name: String
    let type: String
}

struct CodeStructure {
    var functions: [FunctionInfo] = []
    var classes: [String] = []
    var dependencies: [String] = []
    var hasDependencies: Bool = false
    var complexityScore: Int = 0
}

struct GeneratedTestSuite {
    let sourceFile: String
    let language: String
    var unitTests: [String] = []
    var integrationTests: [String] = []
    var edgeCaseTests: [String] = []
    var errorHandlingTests: [String] = []
    var mocks: [String] = []
    var fixtures: [String] = []
    var estimatedCoverage: Double = 0.0
    let timestamp = Date()
}

struct GeneratedTest {
    let timestamp: Date
    let sourceFile: String
    let testSuite: GeneratedTestSuite
}

struct CoverageReport {
    let sourceFile: String
    let testFile: String
    var lineCoverage: Double = 0.0
    var branchCoverage: Double = 0.0
    var functionCoverage: Double = 0.0
}

enum TestExportFormat {
    case framework  // Native test framework
    case plain      // Plain text
    case markdown   // Documentation format
}
