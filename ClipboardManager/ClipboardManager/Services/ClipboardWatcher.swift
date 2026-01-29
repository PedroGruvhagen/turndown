import Foundation
import AppKit
import Combine

/// Custom UTI used to mark clipboard items that have been processed by this app
/// Prevents infinite loops when writing back to clipboard
let kProcessedUTI = "com.clipboardmanager.processed"

/// Service that monitors the system clipboard for changes
/// Uses timer-based polling since macOS doesn't provide clipboard change notifications
final class ClipboardWatcher: ObservableObject {
    static let shared = ClipboardWatcher()

    @Published private(set) var isMonitoring = false
    @Published private(set) var lastChangeCount: Int = 0

    private var timer: Timer?
    private var lastProcessedChangeCount: Int = 0
    private var recentWriteTimestamp: Date?
    private let pollingIntervalKey = "pollingInterval"

    private var pollingInterval: TimeInterval {
        UserDefaults.standard.double(forKey: pollingIntervalKey).nonZeroOr(0.25)
    }

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
        lastProcessedChangeCount = lastChangeCount
    }

    /// Starts monitoring the clipboard for changes
    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        lastChangeCount = NSPasteboard.general.changeCount
        lastProcessedChangeCount = lastChangeCount

        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }

        // Add to common run loop modes to keep running during UI interactions
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    /// Stops monitoring the clipboard
    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }

    /// Checks the clipboard for new content
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        // No change since last check
        guard currentChangeCount != lastChangeCount else { return }

        lastChangeCount = currentChangeCount

        // Check if we just wrote to the clipboard (within last 500ms)
        if let recentWrite = recentWriteTimestamp,
           Date().timeIntervalSince(recentWrite) < 0.5 {
            return
        }

        // Check if this item was already processed by us (has our custom UTI)
        if hasProcessedMarker(pasteboard) {
            return
        }

        // Process the new clipboard content
        processClipboardContent(pasteboard)
    }

    /// Checks if the clipboard item has our processed marker
    private func hasProcessedMarker(_ pasteboard: NSPasteboard) -> Bool {
        let types = pasteboard.types ?? []
        return types.contains(NSPasteboard.PasteboardType(kProcessedUTI))
    }

    /// Processes new clipboard content
    private func processClipboardContent(_ pasteboard: NSPasteboard) {
        // Get the plain text content
        guard let plainText = pasteboard.string(forType: .string),
              !plainText.isEmpty else {
            return
        }

        // Limit processing to reasonable size (1MB)
        guard plainText.count < 1_000_000 else {
            print("Clipboard content too large, skipping processing")
            return
        }

        // Process on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.processText(plainText, originalPasteboard: pasteboard)
        }
    }

    /// Processes text content, converting markdown if detected
    private func processText(_ plainText: String, originalPasteboard: NSPasteboard) {
        let autoConvert = UserDefaults.standard.bool(forKey: "autoConvertMarkdown")

        // Detect if text contains markdown
        let hasMarkdown = autoConvert && MarkdownDetector.containsMarkdown(plainText)

        var rtfData: Data? = nil
        var htmlString: String? = nil

        if hasMarkdown {
            // Convert markdown to rich text
            if let converted = MarkdownConverter.shared.convert(plainText) {
                rtfData = converted.rtfData
                htmlString = converted.htmlString
            }
        }

        // Create clipboard entry
        let entry = ClipboardEntry(
            plainText: plainText,
            rtfData: rtfData,
            htmlString: htmlString,
            hasMarkdown: hasMarkdown
        )

        // Store in history on main queue
        DispatchQueue.main.async {
            HistoryStore.shared.addEntry(entry)
        }

        // Write back to clipboard with rich text (if we have it)
        if hasMarkdown && rtfData != nil {
            DispatchQueue.main.async { [weak self] in
                self?.writeEnrichedClipboard(entry, originalPasteboard: originalPasteboard)
            }
        }
    }

    /// Writes the enriched clipboard content back to the pasteboard
    /// Preserves all original types and adds RTF/HTML
    private func writeEnrichedClipboard(_ entry: ClipboardEntry, originalPasteboard: NSPasteboard) {
        let pasteboard = NSPasteboard.general

        // Mark that we're about to write
        recentWriteTimestamp = Date()

        // Collect all existing items and their data
        var preservedData: [(NSPasteboard.PasteboardType, Data)] = []

        if let items = originalPasteboard.pasteboardItems {
            for item in items {
                for type in item.types {
                    if let data = item.data(forType: type) {
                        preservedData.append((type, data))
                    }
                }
            }
        }

        // Clear and rewrite
        pasteboard.clearContents()

        // Create new item with all types
        let newItem = NSPasteboardItem()

        // Add preserved data
        for (type, data) in preservedData {
            newItem.setData(data, forType: type)
        }

        // Add our rich text conversions
        if let rtfData = entry.rtfData {
            newItem.setData(rtfData, forType: .rtf)
        }

        if let htmlString = entry.htmlString,
           let htmlData = htmlString.data(using: .utf8) {
            newItem.setData(htmlData, forType: .html)
        }

        // Add processed marker to prevent loop
        newItem.setData(Data(), forType: NSPasteboard.PasteboardType(kProcessedUTI))

        pasteboard.writeObjects([newItem])
    }

    /// Writes a specific entry to the clipboard
    func writeToClipboard(_ entry: ClipboardEntry, asRichText: Bool) {
        let pasteboard = NSPasteboard.general

        // Mark that we're about to write
        recentWriteTimestamp = Date()

        pasteboard.clearContents()

        let item = NSPasteboardItem()

        // Always include plain text
        item.setString(entry.plainText, forType: .string)

        if asRichText {
            // Add RTF if available
            if let rtfData = entry.rtfData {
                item.setData(rtfData, forType: .rtf)
            }

            // Add HTML if available
            if let htmlString = entry.htmlString,
               let htmlData = htmlString.data(using: .utf8) {
                item.setData(htmlData, forType: .html)
            }
        }

        // Add processed marker
        item.setData(Data(), forType: NSPasteboard.PasteboardType(kProcessedUTI))

        pasteboard.writeObjects([item])
    }
}

// MARK: - Helpers

private extension Double {
    func nonZeroOr(_ defaultValue: Double) -> Double {
        self != 0 ? self : defaultValue
    }
}
