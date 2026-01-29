import Foundation
import AppKit
import Down

/// Result of markdown conversion containing both RTF data and HTML string
struct ConversionResult {
    let rtfData: Data
    let htmlString: String
    let attributedString: NSAttributedString
}

/// Service that converts Markdown text to rich text formats
/// Uses Down library for Markdown → HTML, then native APIs for HTML → RTF
final class MarkdownConverter {
    static let shared = MarkdownConverter()

    /// CSS styles embedded in HTML for consistent rendering
    private let cssStyles = """
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
            font-size: 13px;
            line-height: 1.5;
            color: #1d1d1f;
        }
        h1, h2, h3, h4, h5, h6 {
            margin-top: 1em;
            margin-bottom: 0.5em;
            font-weight: 600;
            line-height: 1.25;
        }
        h1 { font-size: 2em; }
        h2 { font-size: 1.5em; }
        h3 { font-size: 1.25em; }
        h4 { font-size: 1em; }
        h5 { font-size: 0.875em; }
        h6 { font-size: 0.85em; color: #57606a; }
        p {
            margin-top: 0;
            margin-bottom: 1em;
        }
        a {
            color: #0969da;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        code {
            font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
            font-size: 0.9em;
            padding: 0.2em 0.4em;
            margin: 0;
            background-color: #f6f8fa;
            border-radius: 3px;
        }
        pre {
            font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
            font-size: 0.9em;
            padding: 16px;
            overflow: auto;
            line-height: 1.45;
            background-color: #f6f8fa;
            border-radius: 6px;
            margin: 1em 0;
        }
        pre code {
            background-color: transparent;
            padding: 0;
            border-radius: 0;
        }
        blockquote {
            margin: 1em 0;
            padding: 0 1em;
            color: #57606a;
            border-left: 0.25em solid #d0d7de;
        }
        ul, ol {
            margin-top: 0;
            margin-bottom: 1em;
            padding-left: 2em;
        }
        li {
            margin-top: 0.25em;
        }
        hr {
            height: 0.25em;
            padding: 0;
            margin: 1.5em 0;
            background-color: #d0d7de;
            border: 0;
        }
        table {
            border-spacing: 0;
            border-collapse: collapse;
            margin: 1em 0;
        }
        table th, table td {
            padding: 6px 13px;
            border: 1px solid #d0d7de;
        }
        table th {
            font-weight: 600;
            background-color: #f6f8fa;
        }
        table tr:nth-child(2n) {
            background-color: #f6f8fa;
        }
        img {
            max-width: 100%;
            box-sizing: content-box;
        }
        strong, b {
            font-weight: 600;
        }
        em, i {
            font-style: italic;
        }
        del, s, strike {
            text-decoration: line-through;
        }
    </style>
    """

    private init() {}

    /// Converts Markdown text to rich text formats
    /// - Parameter markdown: The markdown string to convert
    /// - Returns: ConversionResult containing RTF data, HTML, and attributed string, or nil if conversion fails
    func convert(_ markdown: String) -> ConversionResult? {
        do {
            // Step 0: Pre-process markdown tables (Down doesn't support GFM tables)
            let preprocessedMarkdown = preprocessMarkdownTables(markdown)

            // Step 1: Convert Markdown to HTML using Down
            // Use .unsafe to allow our preprocessed HTML tables to pass through
            // (cmark's default mode strips raw HTML since v0.29.0)
            let down = Down(markdownString: preprocessedMarkdown)
            let html = try down.toHTML(.unsafe)

            // Step 2: Wrap HTML with styles and proper structure
            let styledHTML = wrapWithStyles(html)

            // Step 3: Convert HTML to NSAttributedString
            guard let attributedString = htmlToAttributedString(styledHTML) else {
                print("Failed to convert HTML to attributed string")
                return nil
            }

            // Step 4: Convert NSAttributedString to RTF data
            guard let rtfData = attributedStringToRTF(attributedString) else {
                print("Failed to convert attributed string to RTF")
                return nil
            }

            return ConversionResult(
                rtfData: rtfData,
                htmlString: styledHTML,
                attributedString: attributedString
            )
        } catch {
            print("Markdown conversion error: \(error)")
            return nil
        }
    }

    /// Wraps HTML content with DOCTYPE, head, and styles
    private func wrapWithStyles(_ html: String) -> String {
        // Post-process tables to add HTML attributes for better RTF compatibility
        let processedHtml = enhanceTablesForRTF(html)

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            \(cssStyles)
        </head>
        <body>
        \(processedHtml)
        </body>
        </html>
        """
    }

    /// Enhances HTML tables with attributes for better RTF/NSAttributedString compatibility
    /// NSAttributedString's HTML parser works better with old-school HTML attributes than CSS
    private func enhanceTablesForRTF(_ html: String) -> String {
        var result = html

        // Replace <table> with styled version using HTML attributes
        result = result.replacingOccurrences(
            of: "<table>",
            with: "<table border=\"1\" cellpadding=\"8\" cellspacing=\"0\" style=\"border-collapse:collapse; width:100%;\">"
        )

        // Enhance table headers with background color
        result = result.replacingOccurrences(
            of: "<th>",
            with: "<th style=\"background-color:#e8e8e8; font-weight:bold; text-align:left; padding:8px; border:1px solid #999;\">"
        )

        // Enhance table cells with padding and borders
        result = result.replacingOccurrences(
            of: "<td>",
            with: "<td style=\"padding:8px; border:1px solid #ccc; text-align:left;\">"
        )

        // Enhance table rows
        result = result.replacingOccurrences(
            of: "<tr>",
            with: "<tr style=\"border-bottom:1px solid #ccc;\">"
        )

        return result
    }

    /// Pre-processes markdown to convert GFM tables to HTML
    /// Down library uses cmark (not cmark-gfm) and doesn't support tables
    /// This method converts markdown tables to HTML before Down processes the rest
    private func preprocessMarkdownTables(_ markdown: String) -> String {
        return convertAllTables(markdown)
    }

    /// Converts all markdown tables in the text to HTML
    private func convertAllTables(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        var result: [String] = []
        var i = 0

        while i < lines.count {
            // Check if this line starts a table
            if isTableRow(lines[i]) && i + 1 < lines.count && isTableSeparator(lines[i + 1]) {
                // Found a table
                let headerLine = lines[i]
                let separatorLine = lines[i + 1]
                var dataLines: [String] = []

                i += 2 // Skip header and separator

                // Collect data rows
                while i < lines.count && isTableRow(lines[i]) {
                    dataLines.append(lines[i])
                    i += 1
                }

                // Parse alignment from separator
                let alignments = parseAlignments(separatorLine)

                // Convert to HTML
                let html = buildTableHTML(headerLine: headerLine, dataLines: dataLines, alignments: alignments)
                result.append(html)
            } else {
                result.append(lines[i])
                i += 1
            }
        }

        return result.joined(separator: "\n")
    }

    /// Checks if a line looks like a table row (contains pipes)
    private func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Must contain at least one pipe and have content
        return trimmed.contains("|") && trimmed.count > 1
    }

    /// Checks if a line is a table separator (|---|---|)
    private func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Must contain pipes and dashes, and mostly consist of |, -, :, and spaces
        guard trimmed.contains("|") && trimmed.contains("-") else { return false }

        // Check that the line is primarily separator characters
        let separatorChars = CharacterSet(charactersIn: "|-: ")
        let nonSeparatorChars = trimmed.unicodeScalars.filter { !separatorChars.contains($0) }
        return nonSeparatorChars.isEmpty
    }

    /// Parses alignment from separator line
    private func parseAlignments(_ separator: String) -> [String] {
        let cells = parseCells(separator)
        return cells.map { cell -> String in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            let startsColon = trimmed.hasPrefix(":")
            let endsColon = trimmed.hasSuffix(":")

            if startsColon && endsColon {
                return "center"
            } else if endsColon {
                return "right"
            } else {
                return "left"
            }
        }
    }

    /// Parses cells from a table row
    private func parseCells(_ row: String) -> [String] {
        var trimmed = row.trimmingCharacters(in: .whitespaces)

        // Remove leading and trailing pipes if present
        if trimmed.hasPrefix("|") {
            trimmed = String(trimmed.dropFirst())
        }
        if trimmed.hasSuffix("|") {
            trimmed = String(trimmed.dropLast())
        }

        // Split by pipe
        return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Builds HTML table from parsed data
    private func buildTableHTML(headerLine: String, dataLines: [String], alignments: [String]) -> String {
        var html = "<table>\n"

        // Header row
        let headerCells = parseCells(headerLine)
        html += "<thead><tr>\n"
        for (index, cell) in headerCells.enumerated() {
            let align = index < alignments.count ? alignments[index] : "left"
            // Process inline markdown in cell content
            let processedCell = processInlineMarkdown(cell)
            html += "<th style=\"text-align:\(align)\">\(processedCell)</th>\n"
        }
        html += "</tr></thead>\n"

        // Data rows
        html += "<tbody>\n"
        for dataLine in dataLines {
            let dataCells = parseCells(dataLine)
            html += "<tr>\n"
            for (index, cell) in dataCells.enumerated() {
                let align = index < alignments.count ? alignments[index] : "left"
                let processedCell = processInlineMarkdown(cell)
                html += "<td style=\"text-align:\(align)\">\(processedCell)</td>\n"
            }
            html += "</tr>\n"
        }
        html += "</tbody>\n"

        html += "</table>\n"
        return html
    }

    /// Converts a table (array of lines) to HTML
    private func convertTableToHTML(_ lines: [String]) -> String {
        guard !lines.isEmpty else { return "" }

        // First line is header
        let headerCells = parseCells(lines[0])

        var html = "<table>\n<thead><tr>\n"
        for cell in headerCells {
            let processedCell = processInlineMarkdown(cell)
            html += "<th>\(processedCell)</th>\n"
        }
        html += "</tr></thead>\n<tbody>\n"

        // Rest are data rows
        for i in 1..<lines.count {
            let cells = parseCells(lines[i])
            html += "<tr>\n"
            for cell in cells {
                let processedCell = processInlineMarkdown(cell)
                html += "<td>\(processedCell)</td>\n"
            }
            html += "</tr>\n"
        }

        html += "</tbody>\n</table>\n"
        return html
    }

    /// Process inline markdown (bold, italic, code) within table cells
    private func processInlineMarkdown(_ text: String) -> String {
        var result = text

        // Escape HTML special characters first
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")

        // Bold: **text** or __text__
        result = result.replacingOccurrences(
            of: "\\*\\*(.+?)\\*\\*",
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "__(.+?)__",
            with: "<strong>$1</strong>",
            options: .regularExpression
        )

        // Italic: *text* or _text_
        result = result.replacingOccurrences(
            of: "\\*(.+?)\\*",
            with: "<em>$1</em>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "(?<![\\w])_(.+?)_(?![\\w])",
            with: "<em>$1</em>",
            options: .regularExpression
        )

        // Inline code: `code`
        result = result.replacingOccurrences(
            of: "`([^`]+)`",
            with: "<code>$1</code>",
            options: .regularExpression
        )

        // Links: [text](url)
        result = result.replacingOccurrences(
            of: "\\[([^\\]]+)\\]\\(([^)]+)\\)",
            with: "<a href=\"$2\">$1</a>",
            options: .regularExpression
        )

        return result
    }

    /// Converts HTML string to NSAttributedString using native macOS APIs
    /// IMPORTANT: This method MUST be called from the main thread or will dispatch to it
    /// because NSAttributedString with HTML document type uses WebKit internally
    private func htmlToAttributedString(_ html: String) -> NSAttributedString? {
        guard let data = html.data(using: .utf8) else {
            return nil
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        // NSAttributedString with HTML uses WebKit and MUST run on main thread
        if Thread.isMainThread {
            return createAttributedString(from: data, options: options)
        } else {
            var result: NSAttributedString?
            DispatchQueue.main.sync {
                result = self.createAttributedString(from: data, options: options)
            }
            return result
        }
    }

    /// Helper to create attributed string (called on main thread)
    private func createAttributedString(
        from data: Data,
        options: [NSAttributedString.DocumentReadingOptionKey: Any]
    ) -> NSAttributedString? {
        do {
            let attributedString = try NSAttributedString(
                data: data,
                options: options,
                documentAttributes: nil
            )
            return attributedString
        } catch {
            print("HTML to NSAttributedString error: \(error)")
            return nil
        }
    }

    /// Converts NSAttributedString to RTF data
    private func attributedStringToRTF(_ attributedString: NSAttributedString) -> Data? {
        let range = NSRange(location: 0, length: attributedString.length)
        let documentAttributes: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf
        ]

        do {
            let rtfData = try attributedString.data(
                from: range,
                documentAttributes: documentAttributes
            )
            return rtfData
        } catch {
            print("NSAttributedString to RTF error: \(error)")
            return nil
        }
    }

    /// Converts NSAttributedString to RTFD data (includes images)
    func attributedStringToRTFD(_ attributedString: NSAttributedString) -> Data? {
        let range = NSRange(location: 0, length: attributedString.length)
        let documentAttributes: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtfd
        ]

        do {
            let rtfdData = try attributedString.data(
                from: range,
                documentAttributes: documentAttributes
            )
            return rtfdData
        } catch {
            print("NSAttributedString to RTFD error: \(error)")
            return nil
        }
    }
}

// MARK: - Markdown Detection

/// Utility to detect if text contains Markdown formatting
enum MarkdownDetector {
    /// Patterns that indicate Markdown content
    private static let markdownPatterns: [String] = [
        // Headers
        "^#{1,6}\\s",                    // ATX headers: # Header
        "^[=-]{3,}\\s*$",                // Setext headers: underlines

        // Emphasis
        "\\*\\*[^*]+\\*\\*",             // Bold: **text**
        "__[^_]+__",                      // Bold: __text__
        "(?<![*_])\\*[^*\\s][^*]*\\*(?![*_])", // Italic: *text*
        "(?<![*_])_[^_\\s][^_]*_(?![*_])",     // Italic: _text_

        // Code
        "```[\\s\\S]*?```",               // Fenced code blocks
        "`[^`]+`",                        // Inline code

        // Lists
        "^\\s*[-*+]\\s+",                 // Unordered list items
        "^\\s*\\d+\\.\\s+",               // Ordered list items

        // Links and images
        "\\[.+?\\]\\(.+?\\)",             // Links: [text](url)
        "!\\[.+?\\]\\(.+?\\)",            // Images: ![alt](url)
        "\\[.+?\\]\\[.+?\\]",             // Reference links

        // Blockquotes
        "^>\\s+",                          // Blockquote: > text

        // Horizontal rules
        "^[-*_]{3,}\\s*$",                // HR: ---, ***, ___

        // Tables (GFM)
        "\\|[^|]+\\|",                    // Table cells
    ]

    /// Checks if the text contains Markdown formatting
    /// - Parameter text: The text to check
    /// - Returns: true if Markdown patterns are detected
    static func containsMarkdown(_ text: String) -> Bool {
        // Quick checks first
        guard !text.isEmpty else { return false }

        // Must have at least some formatting indicators
        let hasFormatChars = text.contains("*") ||
                            text.contains("_") ||
                            text.contains("#") ||
                            text.contains("`") ||
                            text.contains("[") ||
                            text.contains(">") ||
                            text.contains("-") ||
                            text.contains("|")

        guard hasFormatChars else { return false }

        // Check against patterns
        for pattern in markdownPatterns {
            do {
                let regex = try NSRegularExpression(
                    pattern: pattern,
                    options: [.anchorsMatchLines]
                )
                let range = NSRange(text.startIndex..., in: text)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    return true
                }
            } catch {
                continue
            }
        }

        return false
    }

    /// Estimates how much of the text is Markdown
    /// - Parameter text: The text to analyze
    /// - Returns: A score from 0.0 to 1.0 indicating Markdown density
    static func markdownDensity(_ text: String) -> Double {
        guard !text.isEmpty else { return 0.0 }

        var matches = 0
        let totalPatterns = markdownPatterns.count

        for pattern in markdownPatterns {
            do {
                let regex = try NSRegularExpression(
                    pattern: pattern,
                    options: [.anchorsMatchLines]
                )
                let range = NSRange(text.startIndex..., in: text)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    matches += 1
                }
            } catch {
                continue
            }
        }

        return Double(matches) / Double(totalPatterns)
    }
}
