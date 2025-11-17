import Foundation

class AutoDocGenerator {
    func generateDocumentation(for code: String, language: String) async throws -> String {
        let prompt = """
        Generate comprehensive documentation for this \(language) code.
        Include:
        - Function/class descriptions
        - Parameter descriptions
        - Return values
        - Usage examples
        - Any important notes

        Code:
        ```\(language)
        \(code)
        ```

        Format as proper documentation comments for \(language).
        """

        return try await AIService.shared.callClaude(prompt: prompt, maxTokens: 2048)
    }

    func generateREADME(for projectPath: String) async throws -> String {
        // Analyze project structure
        let files = try FileManager.default.contentsOfDirectory(atPath: projectPath)

        var codeFiles: [String] = []
        for file in files {
            let ext = (file as NSString).pathExtension
            if ["swift", "js", "py", "go", "rs"].contains(ext) {
                codeFiles.append(file)
            }
        }

        let prompt = """
        Generate a comprehensive README.md for a project with these files:
        \(codeFiles.joined(separator: "\n"))

        Include:
        - Project title and description
        - Features
        - Installation instructions
        - Usage examples
        - Contributing guidelines
        - License section

        Make it professional and detailed.
        """

        return try await AIService.shared.callClaude(prompt: prompt, maxTokens: 3000)
    }

    func addCommentsToCode(_ code: String, language: String) async throws -> String {
        let prompt = """
        Add helpful inline comments to this \(language) code.
        Explain complex logic, but don't over-comment obvious things.

        Code:
        ```\(language)
        \(code)
        ```

        Return the code with comments added.
        """

        return try await AIService.shared.callClaude(prompt: prompt, maxTokens: 4000)
    }

    func generateAPIDocumentation(endpoints: [String]) async throws -> String {
        let prompt = """
        Generate API documentation for these endpoints:
        \(endpoints.joined(separator: "\n"))

        Include:
        - Endpoint descriptions
        - HTTP methods
        - Request parameters
        - Response format
        - Example requests/responses
        - Error codes

        Format as Markdown.
        """

        return try await AIService.shared.callClaude(prompt: prompt, maxTokens: 4000)
    }
}
