import Foundation

/// Represents a single clipboard history entry
struct ClipboardEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let plainText: String
    let rtfData: Data?
    let htmlString: String?
    let hasMarkdown: Bool
    var isFavorite: Bool
    var tags: [String]

    /// Creates a new clipboard entry
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        plainText: String,
        rtfData: Data? = nil,
        htmlString: String? = nil,
        hasMarkdown: Bool = false,
        isFavorite: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.plainText = plainText
        self.rtfData = rtfData
        self.htmlString = htmlString
        self.hasMarkdown = hasMarkdown
        self.isFavorite = isFavorite
        self.tags = tags
    }

    /// Returns a preview of the clipboard content (first 100 chars)
    var preview: String {
        let trimmed = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 100 {
            return trimmed
        }
        return String(trimmed.prefix(100)) + "..."
    }

    /// Returns a formatted timestamp string
    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    /// Returns the size of the entry in bytes
    var sizeInBytes: Int {
        var size = plainText.utf8.count
        if let rtf = rtfData {
            size += rtf.count
        }
        if let html = htmlString {
            size += html.utf8.count
        }
        return size
    }

    /// Returns a human-readable size string
    var formattedSize: String {
        let bytes = sizeInBytes
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }

    // MARK: - Equatable

    static func == (lhs: ClipboardEntry, rhs: ClipboardEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Core Data Extension

import CoreData

extension ClipboardEntry {
    /// Creates a ClipboardEntry from a Core Data managed object
    init?(from managedObject: ClipboardEntryMO) {
        guard let id = managedObject.id,
              let timestamp = managedObject.timestamp,
              let plainText = managedObject.plainText else {
            return nil
        }

        self.id = id
        self.timestamp = timestamp
        self.plainText = plainText
        self.rtfData = managedObject.rtfData
        self.htmlString = managedObject.htmlString
        self.hasMarkdown = managedObject.hasMarkdown
        self.isFavorite = managedObject.isFavorite

        if let tagsString = managedObject.tags {
            self.tags = tagsString.split(separator: ",").map(String.init)
        } else {
            self.tags = []
        }
    }

    /// Populates a Core Data managed object with this entry's data
    func populate(_ managedObject: ClipboardEntryMO) {
        managedObject.id = id
        managedObject.timestamp = timestamp
        managedObject.plainText = plainText
        managedObject.rtfData = rtfData
        managedObject.htmlString = htmlString
        managedObject.hasMarkdown = hasMarkdown
        managedObject.isFavorite = isFavorite
        managedObject.tags = tags.joined(separator: ",")
    }
}
