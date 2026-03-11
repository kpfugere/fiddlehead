import Foundation

/// Manages saving and listing notes in the save directory.
@MainActor
final class NoteStorage {
    /// List recent notes from the save directory
    static func recentNotes(from directory: URL, limit: Int = 20) -> [NoteFile] {
        let fm = FileManager.default

        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let mdFiles = contents.filter { $0.pathExtension == "md" }

        let notes: [NoteFile] = mdFiles.compactMap { url in
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            let date = (attrs?[.creationDate] as? Date) ?? Date.distantPast

            // Try to extract title from the file content
            let title = extractTitle(from: url) ?? titleFromFilename(url)
            let isStructured = checkIfStructured(url)

            return NoteFile(
                id: url,
                url: url,
                title: title,
                date: date,
                isStructured: isStructured
            )
        }

        return notes.sorted().prefix(limit).map { $0 }
    }

    /// Generate a filename for a new note, optionally including a slugified title.
    /// e.g. "2026-02-08_q3-budget-review.md" or "2026-02-08_1430_note.md" (fallback)
    static func noteFilename(for date: Date, title: String? = nil) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)

        if let title, !title.isEmpty {
            let slug = slugify(title)
            if !slug.isEmpty {
                return "\(dateStr)_\(slug).md"
            }
        }

        // Fallback: timestamp-based
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmm"
        return "\(dateStr)_\(timeFormatter.string(from: date))_note.md"
    }

    /// Returns a unique filename in the given directory, appending -2, -3 etc. if needed.
    static func uniqueFilename(base: String, in directory: URL) -> String {
        let fm = FileManager.default
        let ext = (base as NSString).pathExtension
        let stem = (base as NSString).deletingPathExtension

        // First, try the original
        if !fm.fileExists(atPath: directory.appendingPathComponent(base).path) {
            return base
        }

        // Append -2, -3, etc.
        var counter = 2
        while true {
            let candidate = "\(stem)-\(counter).\(ext)"
            if !fm.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
                return candidate
            }
            counter += 1
            if counter > 99 { break } // Safety valve
        }

        // Ultimate fallback: append timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss"
        return "\(stem)-\(formatter.string(from: Date())).\(ext)"
    }

    /// Generate a filename for a raw transcript fallback
    static func transcriptFilename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return "\(formatter.string(from: date))_transcript.md"
    }

    /// Generate a filename for audio
    static func audioFilename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return "\(formatter.string(from: date))_recording.wav"
    }

    // MARK: - Claude Skill

    /// Ensures a CLAUDE.md file exists in the notes directory so Claude Code / Cowork
    /// can understand the note format and search effectively.
    static func ensureClaudeSkill(in directory: URL) {
        let destination = directory.appendingPathComponent("CLAUDE.md")
        let fm = FileManager.default

        guard let bundled = Bundle.main.url(forResource: "NotesFolderCLAUDE", withExtension: "md"),
              let bundledContent = try? String(contentsOf: bundled, encoding: .utf8) else {
            return
        }

        // Write if missing; update if the bundled version changed
        if let existing = try? String(contentsOf: destination, encoding: .utf8), existing == bundledContent {
            return
        }

        try? bundledContent.write(to: destination, atomically: true, encoding: .utf8)
    }

    // MARK: - Private

    /// Extract a title from the structured markdown content (first `# ` heading).
    /// Used to generate the filename before saving.
    static func extractTitleFromContent(_ content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                let title = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                return title.isEmpty ? nil : title
            }
        }
        return nil
    }

    /// Convert a title into a URL-safe, filesystem-friendly slug.
    /// "Q3 Budget Review & Planning" → "q3-budget-review-and-planning"
    private static func slugify(_ title: String) -> String {
        var slug = title.lowercased()
        // Replace & with "and"
        slug = slug.replacingOccurrences(of: "&", with: "and")
        // Keep only alphanumerics and spaces/hyphens
        slug = slug.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" }
            .map { String($0) }.joined()
        // Replace spaces with hyphens, collapse multiples
        slug = slug.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: "-")
        // Collapse multiple hyphens
        while slug.contains("--") {
            slug = slug.replacingOccurrences(of: "--", with: "-")
        }
        // Trim hyphens from edges
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        // Cap length to keep filenames reasonable
        if slug.count > 60 {
            // Trim to last complete word boundary within 60 chars
            let truncated = String(slug.prefix(60))
            if let lastHyphen = truncated.lastIndex(of: "-") {
                slug = String(truncated[truncated.startIndex..<lastHyphen])
            } else {
                slug = truncated
            }
        }
        return slug
    }

    private static func extractTitle(from url: URL) -> String? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        // Look for first markdown heading
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func titleFromFilename(_ url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        // "2025-02-07_1430_note" → "Feb 7, 2025 2:30 PM"
        let parts = name.split(separator: "_")
        guard parts.count >= 2 else { return name }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: String(parts[0])) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .none

            // Try to parse time
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HHmm"
            if let time = timeFormatter.date(from: String(parts[1])) {
                let timeDisplay = DateFormatter()
                timeDisplay.timeStyle = .short
                return "\(display.string(from: date)) \(timeDisplay.string(from: time))"
            }
            return display.string(from: date)
        }
        return name
    }

    private static func checkIfStructured(_ url: URL) -> Bool {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
        // Structured notes have Summary, Key Points, or Action Items sections
        return content.contains("## Summary") || content.contains("## Key Points") || content.contains("## Action Items")
    }
}
