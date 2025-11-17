import Foundation
import AppKit

class CodeSnippetManager {
    private var snippets: [CodeSnippet] = []
    private let snippetsDir: URL

    init() {
        snippetsDir = AppConfig.baseDirectory.appendingPathComponent("snippets")
        try? FileManager.default.createDirectory(at: snippetsDir, withIntermediateDirectories: true)
        loadSnippets()
    }

    func saveSnippet(code: String, language: String, tags: [String], description: String) {
        let snippet = CodeSnippet(
            id: UUID(),
            code: code,
            language: language,
            tags: tags,
            description: description,
            timestamp: Date()
        )

        snippets.append(snippet)
        persist(snippet)

        print("💾 Code snippet saved: \(description)")
    }

    func findSnippet(matching query: String) -> [CodeSnippet] {
        return snippets.filter {
            $0.description.lowercased().contains(query.lowercased()) ||
            $0.code.lowercased().contains(query.lowercased()) ||
            $0.tags.contains(where: { $0.lowercased().contains(query.lowercased()) })
        }
    }

    func autoSaveUsefulCode(code: String, language: String) {
        Task {
            // Use AI to determine if code is worth saving
            if !Settings.shared.claudeAPIKey.isEmpty {
                do {
                    let analysis = try await AIService.shared.callClaude(
                        prompt: """
                        Is this code snippet useful enough to save for later? Answer with YES or NO and a brief reason.
                        Code: \(code.prefix(200))
                        """,
                        maxTokens: 100
                    )

                    if analysis.uppercased().contains("YES") {
                        saveSnippet(
                            code: code,
                            language: language,
                            tags: ["auto-saved"],
                            description: "Auto-saved: \(analysis)"
                        )
                    }
                } catch {}
            }
        }
    }

    private func persist(_ snippet: CodeSnippet) {
        let filename = "\(snippet.id.uuidString).json"
        let path = snippetsDir.appendingPathComponent(filename)

        if let data = try? JSONEncoder().encode(snippet) {
            try? data.write(to: path)
        }
    }

    private func loadSnippets() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: snippetsDir, includingPropertiesForKeys: nil) else {
            return
        }

        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let snippet = try? JSONDecoder().decode(CodeSnippet.self, from: data) {
                snippets.append(snippet)
            }
        }

        print("📚 Loaded \(snippets.count) code snippets")
    }

    func getTopSnippets() -> [CodeSnippet] {
        return snippets.sorted { $0.timestamp > $1.timestamp }.prefix(20).map { $0 }
    }

    func exportSnippetsToMarkdown() -> String {
        var markdown = "# Code Snippets\n\n"

        for snippet in snippets.sorted(by: { $0.timestamp > $1.timestamp }) {
            markdown += "## \(snippet.description)\n\n"
            markdown += "**Language:** \(snippet.language)  \n"
            markdown += "**Tags:** \(snippet.tags.joined(separator: ", "))  \n"
            markdown += "**Date:** \(snippet.timestamp.formatted())  \n\n"
            markdown += "```\(snippet.language)\n"
            markdown += snippet.code
            markdown += "\n```\n\n"
            markdown += "---\n\n"
        }

        return markdown
    }
}

struct CodeSnippet: Codable, Identifiable {
    let id: UUID
    let code: String
    let language: String
    let tags: [String]
    let description: String
    let timestamp: Date
}
