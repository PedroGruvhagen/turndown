import Foundation
import AppKit
import Combine
import os.log

/// Custom UTI used to mark clipboard items that have been processed by this app
/// Prevents infinite loops when writing back to clipboard
let kProcessedUTI = "se.demoskop.clipboard.processed"

/// Logging subsystem for clipboard operations
private let logger = Logger(subsystem: "se.demoskop.clipboard", category: "ClipboardWatcher")

/// Service that monitors the system clipboard for changes
/// Uses timer-based polling since macOS doesn't provide clipboard change notifications
final class ClipboardWatcher: ObservableObject {
    static let shared = ClipboardWatcher()

    @Published private(set) var isMonitoring = false
    @Published private(set) var lastChangeCount: Int = 0
    @Published private(set) var isPaused = false

    private var timer: Timer?
    private var lastProcessedChangeCount: Int = 0
    private var recentWriteTimestamp: Date?
    private let pollingIntervalKey = "pollingInterval"

    // Circuit breaker: track processing attempts per changeCount
    private var processingAttempts: [Int: Int] = [:]
    private let maxProcessingAttempts = 3
    private var circuitBreakerTriggered = false

    private var pollingInterval: TimeInterval {
        // UserDefaults stores in milliseconds (e.g., 250), convert to seconds
        let ms = UserDefaults.standard.double(forKey: pollingIntervalKey).nonZeroOr(250.0)
        return ms / 1000.0
    }

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
        lastProcessedChangeCount = lastChangeCount
        logger.info("ClipboardWatcher initialized with changeCount: \(self.lastChangeCount)")
    }

    /// Starts monitoring the clipboard for changes
    func startMonitoring() {
        guard !isMonitoring else {
            logger.debug("Monitoring already active, ignoring start request")
            return
        }

        isMonitoring = true
        isPaused = false
        circuitBreakerTriggered = false
        lastChangeCount = NSPasteboard.general.changeCount
        lastProcessedChangeCount = lastChangeCount
        processingAttempts.removeAll()

        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }

        // Add to common run loop modes to keep running during UI interactions
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }

        logger.info("Clipboard monitoring started with interval: \(self.pollingInterval)s")
    }

    /// Stops monitoring the clipboard
    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
        logger.info("Clipboard monitoring stopped")
    }

    /// Pauses monitoring temporarily (emergency stop)
    func pauseMonitoring() {
        isPaused = true
        logger.warning("Clipboard monitoring PAUSED (emergency)")

        // Auto-resume after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.resumeMonitoring()
        }
    }

    /// Resumes monitoring after pause
    func resumeMonitoring() {
        guard isPaused else { return }
        isPaused = false
        circuitBreakerTriggered = false
        processingAttempts.removeAll()
        logger.info("Clipboard monitoring RESUMED")
    }

    /// Checks the clipboard for new content
    private func checkClipboard() {
        // Skip if paused or circuit breaker triggered
        guard !isPaused && !circuitBreakerTriggered else { return }

        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        // No change since last check
        guard currentChangeCount != lastChangeCount else { return }

        logger.debug("Clipboard change detected: \(self.lastChangeCount) → \(currentChangeCount)")
        lastChangeCount = currentChangeCount

        // Check if we just wrote to the clipboard (within last 500ms)
        if let recentWrite = recentWriteTimestamp,
           Date().timeIntervalSince(recentWrite) < 0.5 {
            logger.debug("Skipping - recent write detected")
            return
        }

        // Check if this item was already processed by us (has our custom UTI)
        if hasProcessedMarker(pasteboard) {
            logger.debug("Skipping - item has processed marker")
            return
        }

        // Circuit breaker: check processing attempts for this changeCount
        let attempts = processingAttempts[currentChangeCount, default: 0] + 1
        processingAttempts[currentChangeCount] = attempts

        if attempts > maxProcessingAttempts {
            logger.error("Circuit breaker triggered: \(attempts) attempts for changeCount \(currentChangeCount)")
            circuitBreakerTriggered = true
            pauseMonitoring()
            return
        }

        // Clean up old entries (keep only last 10)
        if processingAttempts.count > 10 {
            let sortedKeys = processingAttempts.keys.sorted()
            for key in sortedKeys.prefix(processingAttempts.count - 10) {
                processingAttempts.removeValue(forKey: key)
            }
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
        // Log available types
        let types = pasteboard.types?.map { $0.rawValue } ?? []
        logger.debug("Clipboard types: \(types.joined(separator: ", "))")

        // Get the plain text content
        guard let plainText = pasteboard.string(forType: .string),
              !plainText.isEmpty else {
            logger.debug("No plain text content found")
            return
        }

        // Limit processing to reasonable size (1MB)
        guard plainText.count < 1_000_000 else {
            logger.warning("Clipboard content too large (\(plainText.count) chars), skipping")
            return
        }

        logger.info("Processing clipboard content: \(plainText.prefix(50))... (\(plainText.count) chars)")

        // Process on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.processText(plainText, originalPasteboard: pasteboard)
        }
    }

    /// Processes text content, converting markdown if detected
    private func processText(_ plainText: String, originalPasteboard: NSPasteboard) {
        // Default to true if not set
        let autoConvertKey = "autoConvertMarkdown"
        let autoConvert: Bool
        if UserDefaults.standard.object(forKey: autoConvertKey) == nil {
            autoConvert = true // Default enabled
        } else {
            autoConvert = UserDefaults.standard.bool(forKey: autoConvertKey)
        }

        // Detect if text contains markdown
        let containsMarkdown = MarkdownDetector.containsMarkdown(plainText)
        let hasMarkdown = autoConvert && containsMarkdown

        logger.debug("Markdown detection: contains=\(containsMarkdown), autoConvert=\(autoConvert), willConvert=\(hasMarkdown)")

        var rtfData: Data? = nil
        var htmlString: String? = nil

        if hasMarkdown {
            // Convert markdown to rich text
            logger.info("Converting markdown to rich text...")
            if let converted = MarkdownConverter.shared.convert(plainText) {
                rtfData = converted.rtfData
                htmlString = converted.htmlString
                logger.info("Conversion successful: RTF=\(rtfData?.count ?? 0) bytes, HTML=\(htmlString?.count ?? 0) chars")
            } else {
                logger.error("Markdown conversion failed")
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
            logger.debug("Entry added to history store")
        }

        // Write back to clipboard with rich text (if we have it)
        if hasMarkdown && rtfData != nil {
            DispatchQueue.main.async { [weak self] in
                self?.writeEnrichedClipboard(entry, originalPasteboard: originalPasteboard)
                logger.info("Enriched clipboard written with RTF/HTML")
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
