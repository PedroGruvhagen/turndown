import Foundation
import AppKit
import KeyboardShortcuts
import os.log

private let logger = Logger(subsystem: "se.demoskop.clipboard", category: "HotKeyService")

// MARK: - Keyboard Shortcut Names

extension KeyboardShortcuts.Name {
    /// Shows the clipboard history popover
    static let showClipboardHistory = Self("showClipboardHistory", default: .init(.v, modifiers: [.option, .shift]))

    /// Pastes the most recent item as rich text
    static let pasteAsRichText = Self("pasteAsRichText", default: .init(.v, modifiers: [.option, .command]))

    /// Pastes the most recent item as plain text
    static let pasteAsPlainText = Self("pasteAsPlainText", default: .init(.v, modifiers: [.option, .command, .shift]))
}

// MARK: - HotKey Service

/// Service that manages global keyboard shortcuts
final class HotKeyService: ObservableObject {
    static let shared = HotKeyService()

    @Published private(set) var isRegistered = false
    @Published private(set) var hasAccessibilityPermission = false

    private init() {
        checkAccessibilityPermission()
    }

    /// Checks if the app has Accessibility permission (required for CGEvent posting)
    /// - Parameter prompt: If true, shows system prompt if permission not granted
    /// - Returns: true if permission is granted
    @discardableResult
    func checkAccessibilityPermission(prompt: Bool = false) -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): prompt]
        let trusted = AXIsProcessTrustedWithOptions(options)
        hasAccessibilityPermission = trusted

        if !trusted {
            logger.warning("Accessibility permission not granted - paste simulation will not work")
        } else {
            logger.info("Accessibility permission granted")
        }

        return trusted
    }

    /// Prompts user for accessibility permission if not already granted
    func requestAccessibilityPermission() {
        if !hasAccessibilityPermission {
            logger.info("Requesting accessibility permission from user")
            checkAccessibilityPermission(prompt: true)
        }
    }

    /// Registers all default hotkeys
    func registerDefaultHotkey() {
        // Show clipboard history
        KeyboardShortcuts.onKeyUp(for: .showClipboardHistory) { [weak self] in
            self?.showClipboardHistory()
        }

        // Paste as rich text
        KeyboardShortcuts.onKeyUp(for: .pasteAsRichText) { [weak self] in
            self?.pasteAsRichText()
        }

        // Paste as plain text
        KeyboardShortcuts.onKeyUp(for: .pasteAsPlainText) { [weak self] in
            self?.pasteAsPlainText()
        }

        isRegistered = true
    }

    /// Unregisters all hotkeys
    func unregisterHotkeys() {
        KeyboardShortcuts.disable(.showClipboardHistory)
        KeyboardShortcuts.disable(.pasteAsRichText)
        KeyboardShortcuts.disable(.pasteAsPlainText)
        isRegistered = false
    }

    /// Shows the clipboard history window/popover
    private func showClipboardHistory() {
        logger.debug("Showing clipboard history via hotkey")
        // Post notification to toggle the menu bar popover
        // The app listens for this and toggles isMenuPresented via MenuBarExtraAccess
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .showClipboardHistory, object: nil)
        }
    }

    /// Pastes the most recent clipboard item as rich text
    private func pasteAsRichText() {
        guard let entry = HistoryStore.shared.entries.first else { return }

        // Copy to clipboard with rich text
        HistoryStore.shared.copyToClipboard(entry, asRichText: true)

        // Simulate Cmd+V paste
        simulatePaste()
    }

    /// Pastes the most recent clipboard item as plain text
    private func pasteAsPlainText() {
        guard let entry = HistoryStore.shared.entries.first else { return }

        // Copy to clipboard as plain text
        HistoryStore.shared.copyToClipboard(entry, asRichText: false)

        // Simulate Cmd+V paste
        simulatePaste()
    }

    /// Simulates a Cmd+V paste keystroke
    /// Requires Accessibility permission to work
    private func simulatePaste() {
        // Check for accessibility permission first
        guard checkAccessibilityPermission() else {
            logger.error("Cannot simulate paste: Accessibility permission not granted")
            // Prompt user for permission
            DispatchQueue.main.async { [weak self] in
                self?.requestAccessibilityPermission()
            }
            return
        }

        // Small delay to ensure clipboard is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let source = CGEventSource(stateID: .hidSystemState)

            // Create key down event for Cmd+V
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 0x09 is 'V'
            keyDown?.flags = .maskCommand

            // Create key up event
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            keyUp?.flags = .maskCommand

            // Post events
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)

            logger.debug("Paste keystroke simulated")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showClipboardHistory = Notification.Name("showClipboardHistory")
}
