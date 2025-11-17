import Foundation

class MemoryManager {
    private let memoryFileURL: URL
    private let queue = DispatchQueue(label: "com.backgroundai.memory", qos: .utility)

    init() {
        let baseDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".background-ai-agent")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)

        memoryFileURL = baseDir.appendingPathComponent("memory.md")

        // Initialize memory file if it doesn't exist
        if !FileManager.default.fileExists(atPath: memoryFileURL.path) {
            initializeMemoryFile()
        }
    }

    private func initializeMemoryFile() {
        let initialContent = """
        # Background AI Agent Memory

        This file contains my learned patterns and observations about your work habits.

        ## Started
        \(Date().formatted(date: .long, time: .standard))

        ## Observations

        ---

        """

        try? initialContent.write(to: memoryFileURL, atomically: true, encoding: .utf8)
        print("📝 Memory file initialized at: \(memoryFileURL.path)")
    }

    func logEvent(_ event: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let timestamp = Date().formatted(date: .abbreviated, time: .shortened)
            let entry = "\n### [\(timestamp)] \(event)\n"

            do {
                var content = try String(contentsOf: self.memoryFileURL, encoding: .utf8)
                content += entry
                try content.write(to: self.memoryFileURL, atomically: true, encoding: .utf8)
                print("📝 Logged to memory: \(event)")
            } catch {
                print("❌ Memory write error: \(error)")
            }
        }
    }

    func logPattern(_ pattern: String, details: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let timestamp = Date().formatted(date: .abbreviated, time: .shortened)
            let entry = """

            ### [\(timestamp)] Pattern Detected: \(pattern)
            \(details)

            """

            do {
                var content = try String(contentsOf: self.memoryFileURL, encoding: .utf8)
                content += entry
                try content.write(to: self.memoryFileURL, atomically: true, encoding: .utf8)
                print("🧠 Pattern logged: \(pattern)")
            } catch {
                print("❌ Memory write error: \(error)")
            }
        }
    }

    func logInsight(_ category: String, insight: String) {
        let timestamp = Date().formatted(date: .abbreviated, time: .shortened)
        let entry = """

        ### [\(timestamp)] Insight: \(category)
        > \(insight)

        """

        queue.async { [weak self] in
            guard let self = self else { return }

            do {
                var content = try String(contentsOf: self.memoryFileURL, encoding: .utf8)
                content += entry
                try content.write(to: self.memoryFileURL, atomically: true, encoding: .utf8)
                print("💡 Insight logged: \(category)")
            } catch {
                print("❌ Memory write error: \(error)")
            }
        }
    }

    func getMemoryContent() -> String? {
        return try? String(contentsOf: memoryFileURL, encoding: .utf8)
    }

    func analyzePatterns() {
        queue.async { [weak self] in
            guard let self = self,
                  let content = self.getMemoryContent() else { return }

            // Simple pattern analysis
            let lines = content.components(separatedBy: "\n")

            // Count app usage
            var appCounts: [String: Int] = [:]
            for line in lines {
                if line.contains("Opened ") {
                    let components = line.components(separatedBy: "Opened ")
                    if components.count > 1 {
                        let appName = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        appCounts[appName, default: 0] += 1
                    }
                }
            }

            // Log most used app
            if let mostUsed = appCounts.max(by: { $0.value < $1.value }) {
                self.logInsight(
                    "Usage Pattern",
                    "Your most used app is \(mostUsed.key) (\(mostUsed.value) times)"
                )
            }
        }
    }
}
