import Foundation
import Cocoa

class TerminalMonitor {
    private var activityCallback: ((Activity) -> Void)?
    private var commandHistory: [TerminalCommand] = []
    private let maxHistory = 1000

    func start(onActivity: @escaping (Activity) -> Void) {
        activityCallback = onActivity
        monitorShellHistory()
        print("💻 Terminal monitor started")
    }

    private func monitorShellHistory() {
        // Monitor common shell history files
        let historyFiles = [
            ".bash_history",
            ".zsh_history",
            ".fish_history"
        ]

        for file in historyFiles {
            let path = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(file)

            if FileManager.default.fileExists(atPath: path.path) {
                watchHistoryFile(path)
            }
        }
    }

    private func watchHistoryFile(_ path: URL) {
        // Watch for changes
        DispatchQueue.global(qos: .background).async { [weak self] in
            var lastSize = try? FileManager.default.attributesOfItem(atPath: path.path)[.size] as? Int ?? 0

            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                guard let currentSize = try? FileManager.default.attributesOfItem(atPath: path.path)[.size] as? Int else {
                    return
                }

                if currentSize > lastSize {
                    // File grew, read new commands
                    self?.readNewCommands(from: path, lastSize: lastSize)
                    lastSize = currentSize
                }
            }

            RunLoop.current.run()
        }
    }

    private func readNewCommands(from path: URL, lastSize: Int) {
        guard let content = try? String(contentsOf: path, encoding: .utf8) else {
            return
        }

        // Get new commands (simple approach)
        let lines = content.components(separatedBy: "\n")
        guard let lastLine = lines.last, !lastLine.isEmpty else {
            return
        }

        analyzeCommand(lastLine)
    }

    private func analyzeCommand(_ command: String) {
        let cmd = TerminalCommand(command: command, timestamp: Date())
        commandHistory.insert(cmd, at: 0)

        if commandHistory.count > maxHistory {
            commandHistory.removeLast()
        }

        // Detect dangerous commands
        if isDangerousCommand(command) {
            warnDangerousCommand(command)
        }

        // Detect git operations
        if command.starts(with: "git ") {
            analyzeGitCommand(command)
        }

        // Detect build/test commands
        if command.contains("build") || command.contains("test") {
            detectBuildCommand(command)
        }

        // Suggest improvements
        suggestCommandImprovement(command)
    }

    private func isDangerousCommand(_ command: String) -> Bool {
        let dangerous = ["rm -rf /", "chmod 777", "> /dev/sda", "mkfs", "dd if="]
        return dangerous.contains { command.contains($0) }
    }

    private func warnDangerousCommand(_ command: String) {
        let activity = Activity(
            title: "⚠️ Dangerous Command Detected",
            description: "Be careful! Command: \(command.prefix(50))",
            type: .learning
        )
        activityCallback?(activity)
    }

    private func analyzeGitCommand(_ command: String) {
        if command.contains("git push --force") {
            let activity = Activity(
                title: "⚠️ Force Push Detected",
                description: "You're force pushing. Make sure this is intentional!",
                type: .githubPR
            )
            activityCallback?(activity)
        } else if command.contains("git commit") && !command.contains("-m") {
            let activity = Activity(
                title: "Git Commit Starting",
                description: "Don't forget to write a good commit message!",
                type: .githubPR
            )
            activityCallback?(activity)
        }
    }

    private func detectBuildCommand(_ command: String) {
        let activity = Activity(
            title: "Build Started",
            description: "Running: \(command.prefix(50))",
            type: .learning
        )
        activityCallback?(activity)
    }

    private func suggestCommandImprovement(_ command: String) {
        Task {
            // Use AI to suggest better commands
            if !Settings.shared.claudeAPIKey.isEmpty {
                do {
                    let suggestion = try await AIService.shared.callClaude(
                        prompt: "Suggest a better or safer way to run this command: \(command). Be brief.",
                        maxTokens: 150
                    )

                    if !suggestion.contains("already good") && !suggestion.contains("looks fine") {
                        let activity = Activity(
                            title: "Command Suggestion",
                            description: suggestion,
                            type: .learning
                        )
                        activityCallback?(activity)
                    }
                } catch {}
            }
        }
    }

    func getCommandHistory() -> [TerminalCommand] {
        return commandHistory
    }

    func getMostUsedCommands() -> [(String, Int)] {
        var counts: [String: Int] = [:]

        for cmd in commandHistory {
            let base = cmd.command.components(separatedBy: " ").first ?? cmd.command
            counts[base, default: 0] += 1
        }

        return counts.sorted { $0.value > $1.value }
    }
}

struct TerminalCommand {
    let command: String
    let timestamp: Date
}
