import SwiftUI
import AppKit

@main
struct ClipboardManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var historyStore = HistoryStore.shared
    @StateObject private var clipboardWatcher = ClipboardWatcher.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(historyStore)
                .environmentObject(clipboardWatcher)
        } label: {
            Image(systemName: "doc.on.clipboard")
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView()
                .environmentObject(historyStore)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start clipboard monitoring
        ClipboardWatcher.shared.startMonitoring()

        // Register global hotkey
        HotKeyService.shared.registerDefaultHotkey()

        // Hide dock icon (configured via LSUIElement, but ensure it)
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop monitoring
        ClipboardWatcher.shared.stopMonitoring()
    }
}
