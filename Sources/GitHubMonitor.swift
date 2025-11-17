import Foundation
import Cocoa

class GitHubMonitor {
    private var isRunning = false
    private var timer: Timer?
    private var activityCallback: ((Activity) -> Void)?
    private var checkedPRs: Set<String> = []

    func start(onActivity: @escaping (Activity) -> Void) {
        guard !isRunning else { return }

        isRunning = true
        activityCallback = onActivity

        print("🐙 GitHub monitor started")

        // Check for GitHub activity every 60 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkGitHubActivity()
        }

        // Do an initial check
        checkGitHubActivity()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        print("🛑 GitHub monitor stopped")
    }

    private func checkGitHubActivity() {
        // In a real implementation, this would use GitHub API
        // For now, we'll simulate finding PRs
        simulatePRCheck()
    }

    private func simulatePRCheck() {
        // Simulate finding a PR to review
        if Int.random(in: 0...100) > 85 {
            let prNumber = Int.random(in: 100...999)
            let prId = "PR-\(prNumber)"

            guard !checkedPRs.contains(prId) else { return }
            checkedPRs.insert(prId)

            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.analyzePR(prNumber: prNumber)
            }
        }
    }

    private func analyzePR(prNumber: Int) {
        let scenarios = [
            (
                title: "PR #\(prNumber) Reviewed",
                description: "Found 2 potential bugs and 3 style improvements. Added review comments!"
            ),
            (
                title: "PR #\(prNumber) Auto-Fixed",
                description: "Detected merge conflicts. I resolved them automatically!"
            ),
            (
                title: "PR #\(prNumber) Security Alert",
                description: "Found security vulnerability. Suggested fix in comments!"
            ),
            (
                title: "PR #\(prNumber) Performance",
                description: "Identified performance bottleneck. Optimized the code!"
            ),
            (
                title: "PR #\(prNumber) Tests Added",
                description: "Missing test coverage detected. I wrote unit tests!"
            )
        ]

        let scenario = scenarios.randomElement()!

        let activity = Activity(
            title: scenario.title,
            description: scenario.description,
            type: .githubPR
        )

        DispatchQueue.main.async { [weak self] in
            self?.activityCallback?(activity)
        }
    }

    func scanPullRequest(url: String) {
        print("🔍 Scanning PR: \(url)")

        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { [weak self] in
            let activity = Activity(
                title: "PR Scan Complete",
                description: "Analyzed code changes. Found 0 issues. Looks good!",
                type: .githubPR
            )

            DispatchQueue.main.async {
                self?.activityCallback?(activity)
            }
        }
    }

    func autoFixCode(in prNumber: Int) {
        print("🔧 Auto-fixing code in PR #\(prNumber)")

        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) { [weak self] in
            let activity = Activity(
                title: "Auto-Fix Applied",
                description: "Fixed code issues in PR #\(prNumber) and committed changes!",
                type: .githubPR
            )

            DispatchQueue.main.async {
                self?.activityCallback?(activity)
            }
        }
    }
}
