import Foundation

enum NotePostProcessor {
    /// Extract topic tags from `<!-- tags: tag1, tag2, tag3 -->` comment.
    static func extractTags(from content: String) -> [String] {
        guard let range = content.range(of: #"<!-- tags: (.+?) -->"#, options: .regularExpression) else {
            return []
        }

        let match = String(content[range])
        let inner = match
            .replacingOccurrences(of: "<!-- tags: ", with: "")
            .replacingOccurrences(of: " -->", with: "")

        return inner.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Remove the tags comment from content so it doesn't appear in the saved note.
    static func stripTagsComment(from content: String) -> String {
        content.replacingOccurrences(
            of: #"\n?<!-- tags: .+? -->\n?"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .newlines)
    }

    /// Remove sections that only contain "None identified", "None", "N/A", or similar.
    /// Targets Decisions and Action Items sections that the LLM sometimes outputs despite
    /// being instructed to omit them.
    static func stripEmptySections(from content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        var result: [String] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Check if this is a ## heading for Decisions or Action Items
            if line.hasPrefix("## Decisions") || line.hasPrefix("## Action Items") {
                // Collect all lines under this heading until next ## or end
                var sectionBody: [String] = []
                var j = i + 1
                while j < lines.count && !lines[j].hasPrefix("## ") {
                    sectionBody.append(lines[j])
                    j += 1
                }

                let bodyText = sectionBody.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()

                let emptyPatterns = [
                    "none identified", "none", "n/a", "no decisions were made",
                    "no action items", "- none identified", "- none", "- n/a",
                    "no decisions", "no action items identified"
                ]

                if emptyPatterns.contains(bodyText) || bodyText.isEmpty {
                    // Skip this entire section
                    i = j
                    continue
                }
            }

            result.append(line)
            i += 1
        }

        return result.joined(separator: "\n")
    }
}
