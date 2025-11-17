import Foundation
import ApplicationServices
import AppKit

class FormAutomation {
    static let shared = FormAutomation()

    private init() {}

    func fillForm(fields: [String: String], in appBundleId: String) async throws {
        guard AXIsProcessTrusted() else {
            throw FormError.accessibilityNotGranted
        }

        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == appBundleId
        }

        guard let app = apps.first else {
            throw FormError.appNotFound
        }

        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Get all windows
        var value: AnyObject?
        var error = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)

        guard error == .success, let windows = value as? [AXUIElement] else {
            throw FormError.noWindowsFound
        }

        // Try to find and fill form fields
        for window in windows {
            try await fillFieldsInElement(window, fields: fields)
        }

        print("✅ Form automation complete")
    }

    private func fillFieldsInElement(_ element: AXUIElement, fields: [String: String]) async throws {
        // Get all children
        var value: AnyObject?
        var error = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)

        guard error == .success, let children = value as? [AXUIElement] else {
            return
        }

        for child in children {
            // Get role
            var roleValue: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)

            guard let role = roleValue as? String else {
                // Recurse into children
                try await fillFieldsInElement(child, fields: fields)
                continue
            }

            // Handle text fields
            if role == kAXTextFieldRole as String || role == kAXTextAreaRole as String {
                try fillTextField(child, fields: fields)
            }

            // Recurse
            try await fillFieldsInElement(child, fields: fields)
        }
    }

    private func fillTextField(_ element: AXUIElement, fields: [String: String]) throws {
        // Get field description or title
        var descValue: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descValue)

        var titleValue: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)

        let description = (descValue as? String ?? "").lowercased()
        let title = (titleValue as? String ?? "").lowercased()

        // Match against our field data
        for (fieldName, value) in fields {
            let fieldNameLower = fieldName.lowercased()

            if description.contains(fieldNameLower) || title.contains(fieldNameLower) {
                // Set the value
                let cfValue = value as CFTypeRef
                let error = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, cfValue)

                if error == .success {
                    print("✅ Filled field: \(fieldName) = \(value)")
                } else {
                    print("❌ Failed to fill field: \(fieldName)")
                }

                break
            }
        }
    }

    func detectFormInFrontmostApp() async throws -> DetectedForm? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var value: AnyObject?
        var error = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)

        guard error == .success, let windows = value as? [AXUIElement], !windows.isEmpty else {
            return nil
        }

        var textFieldCount = 0
        var fieldTypes: Set<String> = []

        for window in windows {
            let fields = try await findTextFields(in: window)
            textFieldCount += fields.count

            for field in fields {
                fieldTypes.insert(field.type)
            }
        }

        if textFieldCount >= 2 {
            return DetectedForm(
                appName: app.localizedName ?? "Unknown",
                fieldCount: textFieldCount,
                fieldTypes: Array(fieldTypes)
            )
        }

        return nil
    }

    private func findTextFields(in element: AXUIElement) async throws -> [FormFieldInfo] {
        var fields: [FormFieldInfo] = []

        var value: AnyObject?
        var error = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)

        guard error == .success, let children = value as? [AXUIElement] else {
            return fields
        }

        for child in children {
            var roleValue: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)

            guard let role = roleValue as? String else {
                fields.append(contentsOf: try await findTextFields(in: child))
                continue
            }

            if role == kAXTextFieldRole as String || role == kAXTextAreaRole as String {
                var descValue: AnyObject?
                AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &descValue)

                let description = descValue as? String ?? "text"
                fields.append(FormFieldInfo(type: description))
            }

            fields.append(contentsOf: try await findTextFields(in: child))
        }

        return fields
    }

    func generateSmartFormData(for form: DetectedForm) async -> [String: String] {
        var data: [String: String] = [:]

        // Smart defaults based on field types
        for fieldType in form.fieldTypes {
            let lower = fieldType.lowercased()

            if lower.contains("email") {
                data["email"] = "user@example.com"
            } else if lower.contains("name") {
                data["name"] = "John Doe"
            } else if lower.contains("first") {
                data["first"] = "John"
            } else if lower.contains("last") {
                data["last"] = "Doe"
            } else if lower.contains("phone") {
                data["phone"] = "+1-555-123-4567"
            } else if lower.contains("address") {
                data["address"] = "123 Main St"
            } else if lower.contains("city") {
                data["city"] = "San Francisco"
            } else if lower.contains("zip") || lower.contains("postal") {
                data["zip"] = "94102"
            } else if lower.contains("company") {
                data["company"] = "Acme Corp"
            }
        }

        // Use AI to generate more contextual data if API is available
        if !Settings.shared.claudeAPIKey.isEmpty {
            do {
                let aiData = try await AIService.shared.generateFormData(fields: form.fieldTypes)
                data.merge(aiData) { _, new in new }
            } catch {
                print("⚠️ AI form generation failed, using defaults")
            }
        }

        return data
    }
}

struct DetectedForm {
    let appName: String
    let fieldCount: Int
    let fieldTypes: [String]
}

struct FormFieldInfo {
    let type: String
}

enum FormError: Error {
    case accessibilityNotGranted
    case appNotFound
    case noWindowsFound
    case fillFailed
}
