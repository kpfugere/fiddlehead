import Foundation
import os.log

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "DailyNoteManager")

/// Manages the daily document + index architecture for notes.
///
/// Instead of one file per recording/meeting, all notes for a day are appended
/// to a single daily document (`2026-03-11.md`). A running index (`index.md`)
/// provides a lightweight table of contents across all days.
///
/// This architecture optimizes for AI-powered search: the index enables fast
/// cross-day topic scanning, while daily docs keep full context within a
/// single day easily accessible.
@MainActor
enum DailyNoteManager {

    // MARK: - Public API

    /// Append a structured meeting section to the daily document and update the index.
    ///
    /// - Parameters:
    ///   - content: Structured note content (as returned from structuring, post-processed).
    ///              Expected to contain `# Title`, `## Summary`, etc.
    ///   - title: Meeting/note title (extracted from content or meeting event).
    ///   - transcript: The assembled transcript for duration/speaker metadata.
    ///   - tags: Topic tags extracted from the structuring output.
    ///   - structuringStatus: "complete" or "partial" (nil if unstructured).
    ///   - meeting: Optional calendar meeting event for attendee metadata.
    ///   - recordingDate: When the recording started.
    ///   - speakerName: User's configured speaker name (for transcript formatting).
    ///   - saveLocation: The notes directory URL.
    ///   - isAutoMode: Whether this came from auto mode recording.
    /// - Returns: The URL of the daily document.
    @discardableResult
    static func appendSection(
        content: String,
        title: String?,
        transcript: AssembledTranscript,
        tags: [String] = [],
        structuringStatus: String? = nil,
        meeting: MeetingEvent? = nil,
        recordingDate: Date,
        speakerName: String? = nil,
        saveLocation: URL,
        isAutoMode: Bool = false
    ) -> URL? {
        let dailyURL = dailyDocURL(for: recordingDate, in: saveLocation)
        let resolvedTitle = title ?? fallbackTitle(for: recordingDate)

        // Build the section
        let section = buildSection(
            content: content,
            title: resolvedTitle,
            transcript: transcript,
            tags: tags,
            structuringStatus: structuringStatus,
            meeting: meeting,
            recordingDate: recordingDate,
            isAutoMode: isAutoMode
        )

        // Ensure daily doc exists with header, then append
        ensureDailyDoc(at: dailyURL, date: recordingDate)
        appendToFile(at: dailyURL, text: "\n\n\(section)")

        // Update the index
        let summaryLine = extractSummaryLine(from: content)
        updateIndex(
            title: resolvedTitle,
            summary: summaryLine,
            date: recordingDate,
            duration: transcript.duration,
            saveLocation: saveLocation
        )

        logger.info("Appended section '\(resolvedTitle)' to daily doc \(dailyURL.lastPathComponent)")
        return dailyURL
    }

    /// Append a multi-topic auto mode session as a single section with sub-topics.
    ///
    /// Used when auto mode detects multiple topics in one recording session.
    /// Each topic becomes a `###`-level section under the session's `##` heading.
    @discardableResult
    static func appendMultiTopicSession(
        sessionTitle: String,
        sessionSummary: String?,
        topicSections: String,
        fullTranscriptText: String,
        totalDuration: TimeInterval,
        speakerCount: Int,
        tags: [String],
        meeting: MeetingEvent?,
        recordingDate: Date,
        saveLocation: URL,
        structuringPartial: Bool
    ) -> URL? {
        let dailyURL = dailyDocURL(for: recordingDate, in: saveLocation)

        // Build metadata line
        let metaLine = buildMetadataLine(
            date: recordingDate,
            duration: totalDuration,
            speakerCount: speakerCount,
            meeting: meeting,
            tags: tags,
            structuringStatus: structuringPartial ? "partial" : nil,
            isAutoMode: true
        )

        var section = "## \(sessionTitle)\n\(metaLine)\n"

        if let summary = sessionSummary {
            section += "\n### Session Summary\n\(summary)\n"
        }

        section += "\n\(topicSections)\n"
        section += "\n### Full Transcript\n\(fullTranscriptText)"

        ensureDailyDoc(at: dailyURL, date: recordingDate)
        appendToFile(at: dailyURL, text: "\n\n\(section)")

        // Update index with session summary
        let summaryLine = sessionSummary.flatMap { firstSentence(of: $0) }
        updateIndex(
            title: sessionTitle,
            summary: summaryLine,
            date: recordingDate,
            duration: totalDuration,
            saveLocation: saveLocation
        )

        logger.info("Appended multi-topic session '\(sessionTitle)' to \(dailyURL.lastPathComponent)")
        return dailyURL
    }

    /// Append a fallback (unstructured transcript) section to the daily document.
    @discardableResult
    static func appendFallbackSection(
        transcript: AssembledTranscript,
        recordingDate: Date,
        speakerName: String?,
        saveLocation: URL,
        meeting: MeetingEvent? = nil,
        isAutoMode: Bool = false
    ) -> URL? {
        guard !transcript.isEmpty else { return nil }

        let dailyURL = dailyDocURL(for: recordingDate, in: saveLocation)
        let title = meeting?.title ?? fallbackTitle(for: recordingDate)

        let metaLine = buildMetadataLine(
            date: recordingDate,
            duration: transcript.duration,
            speakerCount: transcript.speakerCount,
            meeting: meeting,
            tags: [],
            structuringStatus: "unstructured",
            isAutoMode: isAutoMode
        )

        let section = """
        ## \(title)
        \(metaLine)

        > Note: This transcript could not be structured automatically.

        ### Transcript
        \(transcript.formatted(speakerName: speakerName))
        """

        ensureDailyDoc(at: dailyURL, date: recordingDate)
        appendToFile(at: dailyURL, text: "\n\n\(section)")

        updateIndex(
            title: title,
            summary: nil,
            date: recordingDate,
            duration: transcript.duration,
            saveLocation: saveLocation
        )

        logger.info("Appended fallback section '\(title)' to \(dailyURL.lastPathComponent)")
        return dailyURL
    }

    // MARK: - Daily Document Helpers

    /// URL for the daily document for a given date.
    static func dailyDocURL(for date: Date, in directory: URL) -> URL {
        directory.appendingPathComponent(dailyFilename(for: date))
    }

    /// Filename for a daily document: `2026-03-11.md`
    static func dailyFilename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: date)).md"
    }

    /// Create the daily doc if it doesn't exist, with a date header.
    private static func ensureDailyDoc(at url: URL, date: Date) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: url.path) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"

        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"

        let header = """
        ---
        date: \(isoFormatter.string(from: date))
        ---

        # \(formatter.string(from: date))
        """

        do {
            try header.write(to: url, atomically: true, encoding: .utf8)
            logger.info("Created daily doc: \(url.lastPathComponent)")
        } catch {
            logger.error("Failed to create daily doc: \(error.localizedDescription)")
        }
    }

    // MARK: - Section Building

    /// Build a `## Meeting Title` section for the daily document from structured content.
    private static func buildSection(
        content: String,
        title: String,
        transcript: AssembledTranscript,
        tags: [String],
        structuringStatus: String?,
        meeting: MeetingEvent?,
        recordingDate: Date,
        isAutoMode: Bool
    ) -> String {
        let metaLine = buildMetadataLine(
            date: recordingDate,
            duration: transcript.duration,
            speakerCount: transcript.speakerCount,
            meeting: meeting,
            tags: tags,
            structuringStatus: structuringStatus,
            isAutoMode: isAutoMode
        )

        let transformedContent = transformForDaily(content: content)

        return "## \(title)\n\(metaLine)\n\n\(transformedContent)"
    }

    /// Build the italic metadata line that appears under each `## Section` heading.
    ///
    /// Example: `*10:00 AM · 15m 32s · 3 speakers · attendees: a@co.com, b@co.com · tags: strategy, hiring*`
    static func buildMetadataLine(
        date: Date,
        duration: TimeInterval,
        speakerCount: Int,
        meeting: MeetingEvent?,
        tags: [String],
        structuringStatus: String?,
        isAutoMode: Bool
    ) -> String {
        var parts: [String] = []

        // Time
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        parts.append(timeFormatter.string(from: date))

        // Duration
        let durationMin = Int(duration) / 60
        let durationSec = Int(duration) % 60
        parts.append("\(durationMin)m \(durationSec)s")

        // Speakers
        if speakerCount > 0 {
            parts.append("\(speakerCount) speaker\(speakerCount == 1 ? "" : "s")")
        }

        // Attendees
        if let meeting, !meeting.attendees.isEmpty {
            parts.append("attendees: \(meeting.attendees.joined(separator: ", "))")
        }

        // Tags
        if !tags.isEmpty {
            parts.append("tags: \(tags.joined(separator: ", "))")
        }

        // Status markers
        if let status = structuringStatus, status != "complete" {
            parts.append(status)
        }
        if isAutoMode {
            parts.append("auto")
        }

        return "*\(parts.joined(separator: " · "))*"
    }

    /// Transform structured content for inclusion in a daily document.
    ///
    /// - Strips the top-level `# Title` heading (we use `## Title` at section level).
    /// - Bumps all `##` headings to `###` and `###` to `####`.
    static func transformForDaily(content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        var result: [String] = []
        var skippedTitle = false

        for line in lines {
            // Strip the first `# Title` line (but not `##` or deeper)
            if !skippedTitle && line.hasPrefix("# ") && !line.hasPrefix("## ") {
                skippedTitle = true
                continue
            }

            // Bump heading levels: ### → ####, ## → ###
            // Process deeper headings first to avoid double-bumping
            if line.hasPrefix("### ") {
                result.append("#\(line)")  // ### → ####
            } else if line.hasPrefix("## ") {
                result.append("#\(line)")  // ## → ###
            } else {
                result.append(line)
            }
        }

        // Trim leading/trailing blank lines that result from stripping the title
        let joined = result.joined(separator: "\n")
        return joined.trimmingCharacters(in: .newlines)
    }

    // MARK: - Index Management

    /// Update the master index file with a new entry.
    static func updateIndex(
        title: String,
        summary: String?,
        date: Date,
        duration: TimeInterval,
        saveLocation: URL
    ) {
        let indexURL = saveLocation.appendingPathComponent("index.md")
        let fm = FileManager.default

        let durationMin = Int(duration) / 60
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeStr = timeFormatter.string(from: date)

        var bulletParts = "**\(title)** (\(timeStr), \(durationMin)m)"
        if let summary {
            bulletParts += " — \(summary)"
        }
        let bullet = "- \(bulletParts)"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: date)
        let dateHeading = "## \(dateStr)"

        if fm.fileExists(atPath: indexURL.path) {
            // Read existing index and insert the bullet
            guard var content = try? String(contentsOf: indexURL, encoding: .utf8) else {
                logger.error("Failed to read index.md")
                return
            }

            if let range = content.range(of: dateHeading) {
                // Date heading exists — append bullet after it
                let afterHeading = content.index(range.upperBound, offsetBy: 0)
                // Find the end of this date section (next ## or end of file)
                let remaining = content[afterHeading...]
                if let nextSection = remaining.range(of: "\n## ", range: remaining.startIndex..<remaining.endIndex) {
                    content.insert(contentsOf: "\n\(bullet)", at: nextSection.lowerBound)
                } else {
                    content += "\n\(bullet)"
                }
            } else {
                // New date — insert at the top (after the title line)
                let newDateSection = "\n\n\(dateHeading)\n\(bullet)"
                if let titleEnd = content.range(of: "\n", range: content.index(content.startIndex, offsetBy: 1)..<content.endIndex) {
                    content.insert(contentsOf: newDateSection, at: titleEnd.upperBound)
                } else {
                    content += newDateSection
                }
            }

            do {
                try content.write(to: indexURL, atomically: true, encoding: .utf8)
            } catch {
                logger.error("Failed to update index.md: \(error.localizedDescription)")
            }
        } else {
            // Create new index
            let content = """
            # Meeting Notes Index

            \(dateHeading)
            \(bullet)
            """

            do {
                try content.write(to: indexURL, atomically: true, encoding: .utf8)
                logger.info("Created index.md")
            } catch {
                logger.error("Failed to create index.md: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Summary Extraction

    /// Extract a brief summary line from structured content for the index.
    /// Takes the first sentence of the `## Summary` or `## Session Summary` section.
    static func extractSummaryLine(from content: String) -> String? {
        // Try both heading styles
        if let summary = extractSectionText(named: "Summary", from: content) {
            return firstSentence(of: summary)
        }
        if let summary = extractSectionText(named: "Session Summary", from: content) {
            return firstSentence(of: summary)
        }
        return nil
    }

    /// Extract the text body of a named `## Section` from markdown.
    private static func extractSectionText(named section: String, from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        var capturing = false
        var result: [String] = []

        for line in lines {
            if line.hasPrefix("## \(section)") {
                capturing = true
                continue
            }
            if capturing && line.hasPrefix("## ") {
                break
            }
            if capturing {
                result.append(line)
            }
        }

        let text = result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// Return the first sentence from a block of text.
    static func firstSentence(of text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Find the first sentence-ending punctuation followed by a space or end
        let patterns: [String] = [". ", ".\n", ".\r"]
        var earliest = trimmed.endIndex

        for pattern in patterns {
            if let range = trimmed.range(of: pattern) {
                if range.lowerBound < earliest {
                    earliest = range.lowerBound
                }
            }
        }

        // Include the period
        if earliest < trimmed.endIndex {
            let sentence = String(trimmed[trimmed.startIndex...earliest])
            return sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // No period found — use the whole text if it's short enough
        if trimmed.count <= 200 {
            return trimmed
        }

        // Truncate at word boundary
        let truncated = String(trimmed.prefix(200))
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[truncated.startIndex..<lastSpace]) + "..."
        }
        return truncated + "..."
    }

    // MARK: - Private Helpers

    private static func fallbackTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "Recording — \(formatter.string(from: date))"
    }

    private static func appendToFile(at url: URL, text: String) {
        do {
            let handle = try FileHandle(forWritingTo: url)
            handle.seekToEndOfFile()
            if let data = text.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        } catch {
            logger.error("Failed to append to \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
