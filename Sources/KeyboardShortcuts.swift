import Foundation
import Carbon
import AppKit

class KeyboardShortcuts {
    static let shared = KeyboardShortcuts()

    private var eventHandler: EventHandlerRef?
    private var callbacks: [KeyCombo: () -> Void] = [:]

    private init() {
        setupGlobalKeyboardHandler()
    }

    func register(key: UInt16, modifiers: UInt32, action: @escaping () -> Void) {
        let combo = KeyCombo(key: key, modifiers: modifiers)
        callbacks[combo] = action

        // Register the hotkey
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(combo.hashValue), id: UInt32(combo.hashValue))

        RegisterEventHotKey(
            key,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        print("⌨️ Registered shortcut: \(combo.description)")
    }

    private func setupGlobalKeyboardHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                KeyboardShortcuts.shared.handleHotKey(event: theEvent)
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
    }

    private func handleHotKey(event: EventRef?) -> OSStatus {
        guard let event = event else { return OSStatus(eventNotHandledErr) }

        var hotKeyID = EventHotKeyID()
        let error = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard error == noErr else { return error }

        // Find and execute callback
        for (combo, callback) in callbacks {
            if combo.hashValue == Int(hotKeyID.signature) {
                DispatchQueue.main.async {
                    callback()
                }
                return noErr
            }
        }

        return OSStatus(eventNotHandledErr)
    }

    func registerDefaultShortcuts(delegate: AppDelegate) {
        // Cmd+Shift+A - Toggle Agent
        register(
            key: UInt16(kVK_ANSI_A),
            modifiers: UInt32(cmdKey | shiftKey)
        ) {
            delegate.isEnabled.toggle()
            print("🔄 Agent toggled: \(delegate.isEnabled ? "ON" : "OFF")")
        }

        // Cmd+Shift+S - Take Screenshot
        register(
            key: UInt16(kVK_ANSI_S),
            modifiers: UInt32(cmdKey | shiftKey)
        ) {
            delegate.agentEngine?.captureScreenshotManually()
        }

        // Cmd+Shift+M - Open Memory
        register(
            key: UInt16(kVK_ANSI_M),
            modifiers: UInt32(cmdKey | shiftKey)
        ) {
            let memoryPath = AppConfig.baseDirectory.appendingPathComponent("memory.md")
            NSWorkspace.shared.open(memoryPath)
        }

        // Cmd+Shift+D - Open Dashboard
        register(
            key: UInt16(kVK_ANSI_D),
            modifiers: UInt32(cmdKey | shiftKey)
        ) {
            delegate.togglePopover()
        }

        print("⌨️ Default keyboard shortcuts registered")
    }

    deinit {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}

struct KeyCombo: Hashable {
    let key: UInt16
    let modifiers: UInt32

    var description: String {
        var parts: [String] = []

        if modifiers & UInt32(cmdKey) != 0 { parts.append("Cmd") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("Shift") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("Option") }
        if modifiers & UInt32(controlKey) != 0 { parts.append("Control") }

        parts.append(keyToString(key))

        return parts.joined(separator: "+")
    }

    private func keyToString(_ key: UInt16) -> String {
        switch Int(key) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_M: return "M"
        default: return String(key)
        }
    }
}
