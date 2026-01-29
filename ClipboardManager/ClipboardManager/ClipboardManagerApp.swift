import SwiftUI
import AppKit
import MenuBarExtraAccess

/// Shared state for menu bar visibility
class MenuBarState: ObservableObject {
    static let shared = MenuBarState()
    @Published var isPresented = false
}

@main
struct ClipboardManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var historyStore = HistoryStore.shared
    @StateObject private var clipboardWatcher = ClipboardWatcher.shared
    @StateObject private var menuBarState = MenuBarState.shared

    var body: some Scene {
        MenuBarExtra(isInserted: .constant(true)) {
            MenuBarView()
                .environmentObject(historyStore)
                .environmentObject(clipboardWatcher)
        } label: {
            Image(systemName: "doc.on.clipboard")
        }
        .menuBarExtraStyle(.window)
        .menuBarExtraAccess(isPresented: $menuBarState.isPresented)

        Settings {
            PreferencesView()
                .environmentObject(historyStore)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var showHistoryObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start clipboard monitoring
        ClipboardWatcher.shared.startMonitoring()

        // Register global hotkey
        HotKeyService.shared.registerDefaultHotkey()

        // Listen for show clipboard history notification
        showHistoryObserver = NotificationCenter.default.addObserver(
            forName: .showClipboardHistory,
            object: nil,
            queue: .main
        ) { _ in
            MenuBarState.shared.isPresented.toggle()
        }

        // Check accessibility permission (required for paste simulation)
        // Prompt user if not granted - this is needed for CGEvent to work
        if !HotKeyService.shared.checkAccessibilityPermission() {
            // Delay prompt slightly so app fully launches first
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                HotKeyService.shared.requestAccessibilityPermission()
            }
        }

        // Hide dock icon (configured via LSUIElement, but ensure it)
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop monitoring
        ClipboardWatcher.shared.stopMonitoring()

        // Remove observer
        if let observer = showHistoryObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
