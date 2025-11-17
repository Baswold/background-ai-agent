import Foundation
import AppKit

class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount = 0
    private var activityCallback: ((Activity) -> Void)?
    private var clipboardHistory: [ClipboardItem] = []
    private let maxHistorySize = 100

    func start(onActivity: @escaping (Activity) -> Void) {
        activityCallback = onActivity
        lastChangeCount = NSPasteboard.general.changeCount

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }

        print("📋 Clipboard monitor started")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // Get clipboard content
        if let string = pasteboard.string(forType: .string) {
            handleClipboardChange(string)
        } else if let image = pasteboard.data(forType: .png) {
            handleImageCopy(image)
        }
    }

    private func handleClipboardChange(_ text: String) {
        // Save to history
        let item = ClipboardItem(content: text, type: .text, timestamp: Date())
        clipboardHistory.insert(item, at: 0)
        if clipboardHistory.count > maxHistorySize {
            clipboardHistory.removeLast()
        }

        // Smart detection
        if isURL(text) {
            analyzeURL(text)
        } else if isCode(text) {
            analyzeCode(text)
        } else if isJSON(text) {
            analyzeJSON(text)
        } else if isStackTrace(text) {
            analyzeError(text)
        } else if isAPIKey(text) {
            warnAboutSecret(text)
        }
    }

    private func handleImageCopy(_ imageData: Data) {
        print("📸 Image copied to clipboard")

        let item = ClipboardItem(content: "Image", type: .image, timestamp: Date())
        clipboardHistory.insert(item, at: 0)

        // Could do OCR on the image
        Task {
            if let image = NSImage(data: imageData) {
                do {
                    let text = try await OCRService.shared.extractText(from: image)
                    if !text.isEmpty {
                        let activity = Activity(
                            title: "Text Extracted from Image",
                            description: "Found: \(text.prefix(100))...",
                            type: .learning
                        )
                        activityCallback?(activity)
                    }
                } catch {
                    print("OCR failed: \(error)")
                }
            }
        }
    }

    private func isURL(_ text: String) -> Bool {
        return text.starts(with: "http://") || text.starts(with: "https://")
    }

    private func isCode(_ text: String) -> Bool {
        let codeIndicators = ["func ", "class ", "def ", "import ", "const ", "{", "=>"]
        return codeIndicators.contains { text.contains($0) }
    }

    private func isJSON(_ text: String) -> Bool {
        return (text.trimmingCharacters(in: .whitespaces).starts(with: "{") ||
                text.trimmingCharacters(in: .whitespaces).starts(with: "[")) &&
               (try? JSONSerialization.jsonObject(with: text.data(using: .utf8)!)) != nil
    }

    private func isStackTrace(_ text: String) -> Bool {
        return text.contains("Error") || text.contains("Exception") || text.contains("at line")
    }

    private func isAPIKey(_ text: String) -> Bool {
        return text.contains("API") || text.contains("SECRET") || text.contains("TOKEN") ||
               (text.count > 30 && text.range(of: "[a-zA-Z0-9]{30,}", options: .regularExpression) != nil)
    }

    private func analyzeURL(_ url: String) {
        let activity = Activity(
            title: "URL Copied",
            description: "Copied: \(url)",
            type: .learning
        )
        activityCallback?(activity)
    }

    private func analyzeCode(_ code: String) {
        Task {
            do {
                let analysis = try await AIService.shared.analyzeCode(code)
                if !analysis.issues.isEmpty {
                    let activity = Activity(
                        title: "Code in Clipboard Analyzed",
                        description: "Found \(analysis.issues.count) issues in copied code",
                        type: .vsCodeFix
                    )
                    activityCallback?(activity)
                }
            } catch {}
        }
    }

    private func analyzeJSON(_ json: String) {
        let activity = Activity(
            title: "JSON Detected",
            description: "Copied JSON data - I can help format or validate it",
            type: .learning
        )
        activityCallback?(activity)
    }

    private func analyzeError(_ error: String) {
        Task {
            do {
                let solution = try await AIService.shared.callClaude(
                    prompt: "Explain this error and suggest a fix: \(error)"
                )

                let activity = Activity(
                    title: "Error Solution Found",
                    description: solution.prefix(100).description,
                    type: .vsCodeFix
                )
                activityCallback?(activity)
            } catch {}
        }
    }

    private func warnAboutSecret(_ text: String) {
        let activity = Activity(
            title: "⚠️ Possible Secret Detected",
            description: "Be careful! This looks like an API key or secret",
            type: .learning
        )
        activityCallback?(activity)
    }

    func getHistory() -> [ClipboardItem] {
        return clipboardHistory
    }
}

struct ClipboardItem: Identifiable {
    let id = UUID()
    let content: String
    let type: ClipboardType
    let timestamp: Date
}

enum ClipboardType {
    case text
    case image
    case url
    case code
}
