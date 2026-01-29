import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var historyStore: HistoryStore
    @EnvironmentObject var clipboardWatcher: ClipboardWatcher
    @State private var searchText = ""
    @State private var showingPreferences = false

    var filteredEntries: [ClipboardEntry] {
        if searchText.isEmpty {
            return historyStore.entries
        }
        return historyStore.entries.filter { entry in
            entry.plainText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Search
            searchField

            Divider()

            // History list
            if filteredEntries.isEmpty {
                emptyStateView
            } else {
                historyListView
            }

            Divider()

            // Footer
            footerView
        }
        .frame(width: 350, height: 450)
    }

    private var headerView: some View {
        HStack {
            Text("Clipboard History")
                .font(.headline)
            Spacer()
            Button(action: { historyStore.clearHistory() }) {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear History")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No clipboard history")
                .foregroundColor(.secondary)
            Text("Copy something to get started")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(filteredEntries) { entry in
                    ClipboardEntryRow(entry: entry)
                        .environmentObject(historyStore)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var footerView: some View {
        HStack {
            Text("\(filteredEntries.count) items")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: {
                if let url = URL(string: "x-apple.systempreferences:") {
                    NSWorkspace.shared.open(url)
                }
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }) {
                Image(systemName: "gear")
            }
            .buttonStyle(.plain)
            .help("Preferences")

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .help("Quit")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct ClipboardEntryRow: View {
    let entry: ClipboardEntry
    @EnvironmentObject var historyStore: HistoryStore
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Type indicator
            typeIndicator

            // Content preview
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.preview)
                    .lineLimit(2)
                    .font(.system(size: 12))

                Text(entry.formattedTimestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Actions
            if isHovering {
                actionButtons
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            pasteEntry()
        }
    }

    private var typeIndicator: some View {
        Group {
            if entry.hasMarkdown {
                Image(systemName: "text.badge.checkmark")
                    .foregroundColor(.blue)
                    .help("Rich text available")
            } else {
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
            }
        }
        .font(.system(size: 14))
    }

    private var actionButtons: some View {
        HStack(spacing: 4) {
            Button(action: { copyPlainText() }) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .help("Copy as plain text")

            if entry.hasMarkdown {
                Button(action: { copyRichText() }) {
                    Image(systemName: "doc.richtext")
                }
                .buttonStyle(.plain)
                .help("Copy as rich text")
            }

            Button(action: { toggleFavorite() }) {
                Image(systemName: entry.isFavorite ? "star.fill" : "star")
                    .foregroundColor(entry.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .help(entry.isFavorite ? "Remove from favorites" : "Add to favorites")

            Button(action: { deleteEntry() }) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
    }

    private func pasteEntry() {
        historyStore.pasteEntry(entry, asRichText: entry.hasMarkdown)
    }

    private func copyPlainText() {
        historyStore.copyToClipboard(entry, asRichText: false)
    }

    private func copyRichText() {
        historyStore.copyToClipboard(entry, asRichText: true)
    }

    private func toggleFavorite() {
        historyStore.toggleFavorite(entry)
    }

    private func deleteEntry() {
        historyStore.deleteEntry(entry)
    }
}

#Preview {
    MenuBarView()
        .environmentObject(HistoryStore.shared)
        .environmentObject(ClipboardWatcher.shared)
}
