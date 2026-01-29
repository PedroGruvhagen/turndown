import SwiftUI
import KeyboardShortcuts

struct PreferencesView: View {
    @EnvironmentObject var historyStore: HistoryStore
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 1000
    @AppStorage("pollingInterval") private var pollingInterval = 250.0
    @AppStorage("autoConvertMarkdown") private var autoConvertMarkdown = true
    @AppStorage("showNotifications") private var showNotifications = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            shortcutsTab
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            advancedTab
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        LaunchAtLoginService.shared.setEnabled(newValue)
                    }

                Toggle("Auto-convert Markdown to rich text", isOn: $autoConvertMarkdown)

                Toggle("Show notifications", isOn: $showNotifications)
            }

            Section {
                Stepper(value: $maxHistoryItems, in: 100...5000, step: 100) {
                    Text("Maximum history items: \(maxHistoryItems)")
                }

                Button("Clear All History") {
                    historyStore.clearHistory()
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var shortcutsTab: some View {
        Form {
            Section("Global Shortcuts") {
                KeyboardShortcuts.Recorder("Show clipboard history:", name: .showClipboardHistory)

                KeyboardShortcuts.Recorder("Paste as rich text:", name: .pasteAsRichText)

                KeyboardShortcuts.Recorder("Paste as plain text:", name: .pasteAsPlainText)
            }

            Section {
                Text("Note: Some shortcuts may conflict with other applications or system shortcuts.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var advancedTab: some View {
        Form {
            Section("Performance") {
                Slider(value: $pollingInterval, in: 100...1000, step: 50) {
                    Text("Polling interval: \(Int(pollingInterval))ms")
                }
                Text("Lower values = faster detection, higher CPU usage")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Data") {
                HStack {
                    Text("Database location:")
                    Spacer()
                    Button("Show in Finder") {
                        if let url = PersistenceController.shared.storeURL {
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                        }
                    }
                }

                Button("Export History...") {
                    exportHistory()
                }

                Button("Reset All Settings") {
                    resetSettings()
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Demoskop Clipboard")
                .font(.title)
                .fontWeight(.bold)

            Text("Version \(Bundle.main.appVersion)")
                .foregroundColor(.secondary)

            Text("Clipboard history manager with automatic Markdown to rich text conversion.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Spacer()

            HStack {
                Button("Check for Updates") {
                    UpdateService.shared.checkForUpdates()
                }
            }

            Text("© 2026 Demoskop. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private func exportHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "clipboard-history.json"

        if panel.runModal() == .OK, let url = panel.url {
            historyStore.exportHistory(to: url)
        }
    }

    private func resetSettings() {
        let alert = NSAlert()
        alert.messageText = "Reset All Settings?"
        alert.informativeText = "This will reset all preferences to their default values. Your clipboard history will not be affected."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        }
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }
}

#Preview {
    PreferencesView()
        .environmentObject(HistoryStore.shared)
}
