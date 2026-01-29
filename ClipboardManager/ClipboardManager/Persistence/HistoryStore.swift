import Foundation
import CoreData
import AppKit
import Combine

/// Observable store for clipboard history
/// Manages in-memory cache backed by Core Data persistence
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var entries: [ClipboardEntry] = []
    @Published private(set) var isLoading = false

    private let persistence = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()

    private var maxHistoryItems: Int {
        UserDefaults.standard.integer(forKey: "maxHistoryItems").nonZeroOr(1000)
    }

    private init() {
        loadEntries()
    }

    // MARK: - CRUD Operations

    /// Loads entries from Core Data
    func loadEntries() {
        isLoading = true

        let context = persistence.viewContext
        let request = NSFetchRequest<ClipboardEntryMO>(entityName: "ClipboardEntryMO")
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = maxHistoryItems

        do {
            let managedObjects = try context.fetch(request)
            entries = managedObjects.compactMap { ClipboardEntry(from: $0) }
        } catch {
            print("Failed to fetch clipboard entries: \(error)")
            entries = []
        }

        isLoading = false
    }

    /// Adds a new entry to the history
    func addEntry(_ entry: ClipboardEntry) {
        // Check for duplicate (same plain text within last 2 seconds)
        if let lastEntry = entries.first,
           lastEntry.plainText == entry.plainText,
           Date().timeIntervalSince(lastEntry.timestamp) < 2.0 {
            return
        }

        // Add to in-memory cache
        entries.insert(entry, at: 0)

        // Trim to max size (keeping favorites)
        trimHistory()

        // Persist to Core Data on background queue
        let context = persistence.newBackgroundContext()
        context.perform { [weak self] in
            guard let self = self else { return }

            let managedObject = ClipboardEntryMO(context: context)
            entry.populate(managedObject)

            self.persistence.save(context: context)
        }
    }

    /// Deletes an entry from history
    func deleteEntry(_ entry: ClipboardEntry) {
        // Remove from in-memory cache
        entries.removeAll { $0.id == entry.id }

        // Delete from Core Data
        let context = persistence.newBackgroundContext()
        context.perform { [weak self] in
            guard let self = self else { return }

            let request = NSFetchRequest<ClipboardEntryMO>(entityName: "ClipboardEntryMO")
            request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)

            do {
                let results = try context.fetch(request)
                for object in results {
                    context.delete(object)
                }
                self.persistence.save(context: context)
            } catch {
                print("Failed to delete entry: \(error)")
            }
        }
    }

    /// Toggles the favorite status of an entry
    func toggleFavorite(_ entry: ClipboardEntry) {
        // Update in-memory cache
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index].isFavorite.toggle()
        }

        // Update in Core Data
        let context = persistence.newBackgroundContext()
        let newFavoriteStatus = !(entry.isFavorite)

        context.perform { [weak self] in
            guard let self = self else { return }

            let request = NSFetchRequest<ClipboardEntryMO>(entityName: "ClipboardEntryMO")
            request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)

            do {
                let results = try context.fetch(request)
                for object in results {
                    object.isFavorite = newFavoriteStatus
                }
                self.persistence.save(context: context)
            } catch {
                print("Failed to update favorite status: \(error)")
            }
        }
    }

    /// Clears all non-favorite entries from history
    func clearHistory() {
        // Keep only favorites in memory
        entries = entries.filter { $0.isFavorite }

        // Delete non-favorites from Core Data
        let context = persistence.newBackgroundContext()
        context.perform { [weak self] in
            guard let self = self else { return }

            let request = NSFetchRequest<ClipboardEntryMO>(entityName: "ClipboardEntryMO")
            request.predicate = NSPredicate(format: "isFavorite == NO")

            do {
                let results = try context.fetch(request)
                for object in results {
                    context.delete(object)
                }
                self.persistence.save(context: context)
            } catch {
                print("Failed to clear history: \(error)")
            }
        }
    }

    // MARK: - Clipboard Operations

    /// Copies an entry to the clipboard
    func copyToClipboard(_ entry: ClipboardEntry, asRichText: Bool) {
        ClipboardWatcher.shared.writeToClipboard(entry, asRichText: asRichText)
    }

    /// Pastes an entry (copies to clipboard and simulates paste)
    func pasteEntry(_ entry: ClipboardEntry, asRichText: Bool) {
        copyToClipboard(entry, asRichText: asRichText)

        // Simulate Cmd+V after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePaste()
        }
    }

    /// Simulates a Cmd+V paste keystroke
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Export/Import

    /// Exports history to a JSON file
    func exportHistory(to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(entries)
            try data.write(to: url)
        } catch {
            print("Failed to export history: \(error)")
        }
    }

    /// Imports history from a JSON file
    func importHistory(from url: URL) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try Data(contentsOf: url)
            let importedEntries = try decoder.decode([ClipboardEntry].self, from: data)

            // Add imported entries
            for entry in importedEntries {
                addEntry(entry)
            }
        } catch {
            print("Failed to import history: \(error)")
        }
    }

    // MARK: - Private Helpers

    /// Trims history to maxHistoryItems, keeping favorites
    private func trimHistory() {
        guard entries.count > maxHistoryItems else { return }

        // Separate favorites and non-favorites
        let favorites = entries.filter { $0.isFavorite }
        var nonFavorites = entries.filter { !$0.isFavorite }

        // Calculate how many non-favorites to keep
        let nonFavoritesToKeep = max(0, maxHistoryItems - favorites.count)

        // Trim non-favorites
        if nonFavorites.count > nonFavoritesToKeep {
            let entriesToDelete = Array(nonFavorites.suffix(from: nonFavoritesToKeep))
            nonFavorites = Array(nonFavorites.prefix(nonFavoritesToKeep))

            // Delete from Core Data
            deleteEntries(entriesToDelete)
        }

        // Rebuild entries list
        entries = favorites + nonFavorites
        entries.sort { $0.timestamp > $1.timestamp }
    }

    /// Deletes multiple entries from Core Data
    private func deleteEntries(_ entriesToDelete: [ClipboardEntry]) {
        let context = persistence.newBackgroundContext()
        let ids = entriesToDelete.map { $0.id }

        context.perform { [weak self] in
            guard let self = self else { return }

            let request = NSFetchRequest<ClipboardEntryMO>(entityName: "ClipboardEntryMO")
            request.predicate = NSPredicate(format: "id IN %@", ids)

            do {
                let results = try context.fetch(request)
                for object in results {
                    context.delete(object)
                }
                self.persistence.save(context: context)
            } catch {
                print("Failed to delete entries: \(error)")
            }
        }
    }
}

// MARK: - Helpers

private extension Int {
    func nonZeroOr(_ defaultValue: Int) -> Int {
        self != 0 ? self : defaultValue
    }
}
