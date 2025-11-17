import Foundation
import Vision
import AppKit

class OCRService {
    static let shared = OCRService()

    private init() {}

    func extractText(from image: NSImage) async throws -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: recognizedText)
            }

            // Configure for better accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func detectCode(from image: NSImage) async throws -> DetectedCode? {
        let text = try await extractText(from: image)

        // Heuristics to detect if text contains code
        let codeIndicators = [
            "func ", "class ", "def ", "import ", "const ", "let ", "var ",
            "public ", "private ", "return ", "if ", "for ", "while ",
            "{", "}", "=>", "->", "==", "!=", "||", "&&"
        ]

        var codeScore = 0
        for indicator in codeIndicators {
            if text.contains(indicator) {
                codeScore += 1
            }
        }

        // If we detect significant code patterns
        if codeScore >= 3 {
            let language = detectLanguage(from: text)
            return DetectedCode(text: text, language: language, confidence: Double(codeScore) / Double(codeIndicators.count))
        }

        return nil
    }

    func detectFormFields(from image: NSImage) async throws -> [FormField] {
        let text = try await extractText(from: image)

        var fields: [FormField] = []

        // Common form field patterns
        let patterns = [
            ("Email|E-mail|Email Address", FormFieldType.email),
            ("Password|Pass|Pwd", FormFieldType.password),
            ("Name|Full Name|First Name|Last Name", FormFieldType.name),
            ("Phone|Telephone|Mobile", FormFieldType.phone),
            ("Address|Street|City|ZIP|Postal", FormFieldType.address),
            ("Username|User name|Login", FormFieldType.username),
            ("Company|Organization", FormFieldType.text),
            ("Message|Comment|Description", FormFieldType.textarea)
        ]

        for (pattern, type) in patterns {
            if let _ = text.range(of: pattern, options: .regularExpression) {
                fields.append(FormField(label: pattern, type: type))
            }
        }

        return fields
    }

    private func detectLanguage(from code: String) -> String {
        if code.contains("func ") && code.contains("->") {
            return "swift"
        } else if code.contains("def ") && code.contains("self.") {
            return "python"
        } else if code.contains("function") || code.contains("const ") || code.contains("let ") {
            return "javascript"
        } else if code.contains("public class") || code.contains("private class") {
            return "java"
        } else if code.contains("fn ") && code.contains("->") {
            return "rust"
        }

        return "unknown"
    }
}

struct DetectedCode {
    let text: String
    let language: String
    let confidence: Double
}

struct FormField {
    let label: String
    let type: FormFieldType
}

enum FormFieldType {
    case text
    case email
    case password
    case name
    case phone
    case address
    case username
    case textarea
}

enum OCRError: Error {
    case invalidImage
    case noTextFound
    case processingFailed
}
