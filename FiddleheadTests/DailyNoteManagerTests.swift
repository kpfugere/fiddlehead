import XCTest
@testable import Fiddlehead

@MainActor
final class DailyNoteManagerTests: XCTestCase {

    private nonisolated(unsafe) var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FiddleheadTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - dailyFilename

    func testDailyFilename() {
        let date = makeDate(year: 2026, month: 3, day: 11)
        let filename = DailyNoteManager.dailyFilename(for: date)
        XCTAssertEqual(filename, "2026-03-11.md")
    }

    func testDailyDocURL() {
        let date = makeDate(year: 2026, month: 1, day: 5)
        let url = DailyNoteManager.dailyDocURL(for: date, in: tempDir)
        XCTAssertEqual(url.lastPathComponent, "2026-01-05.md")
        XCTAssertEqual(url.deletingLastPathComponent().path, tempDir.path)
    }

    // MARK: - transformForDaily

    func testTransformForDailyStripsTitle() {
        let content = """
        # Meeting Title

        ## Summary
        Something happened.
        """
        let result = DailyNoteManager.transformForDaily(content: content)
        XCTAssertFalse(result.contains("# Meeting Title"))
        XCTAssertTrue(result.contains("### Summary"))
    }

    func testTransformForDailyBumpsHeadings() {
        let content = """
        # Title

        ## Summary
        Text here.

        ### Sub-heading
        More text.
        """
        let result = DailyNoteManager.transformForDaily(content: content)
        XCTAssertTrue(result.contains("### Summary"), "## should become ###")
        XCTAssertTrue(result.contains("#### Sub-heading"), "### should become ####")
        // Check no line starts with "## " (can't use .contains because "### Summary" contains "## Summary" as substring)
        let hasLevel2 = result.components(separatedBy: "\n").contains { $0.hasPrefix("## ") }
        XCTAssertFalse(hasLevel2, "Original ## should not remain")
    }

    func testTransformForDailyPreservesBodyText() {
        let content = """
        # Title

        ## Summary
        Important decisions were made today.

        ## Action Items
        - Do the thing
        """
        let result = DailyNoteManager.transformForDaily(content: content)
        XCTAssertTrue(result.contains("Important decisions were made today."))
        XCTAssertTrue(result.contains("- Do the thing"))
    }

    // MARK: - buildMetadataLine

    func testBuildMetadataLineBasic() {
        let date = makeDate(year: 2026, month: 3, day: 11, hour: 10, minute: 0)
        let line = DailyNoteManager.buildMetadataLine(
            date: date,
            duration: 932,  // 15m 32s
            speakerCount: 3,
            meeting: nil,
            tags: ["strategy", "hiring"],
            structuringStatus: nil,
            isAutoMode: false
        )

        XCTAssertTrue(line.hasPrefix("*"))
        XCTAssertTrue(line.hasSuffix("*"))
        XCTAssertTrue(line.contains("15m 32s"))
        XCTAssertTrue(line.contains("3 speakers"))
        XCTAssertTrue(line.contains("tags: strategy, hiring"))
    }

    func testBuildMetadataLineWithMeeting() {
        let date = makeDate(year: 2026, month: 3, day: 11, hour: 14, minute: 30)
        let meeting = MeetingEvent(
            id: "evt-1",
            title: "Sprint Planning",
            startDate: date,
            endDate: date.addingTimeInterval(3600),
            attendees: ["a@co.com", "b@co.com"],
            videoURL: nil
        )

        let line = DailyNoteManager.buildMetadataLine(
            date: date,
            duration: 600,
            speakerCount: 2,
            meeting: meeting,
            tags: [],
            structuringStatus: nil,
            isAutoMode: false
        )

        XCTAssertTrue(line.contains("attendees: a@co.com, b@co.com"))
    }

    func testBuildMetadataLineAutoMode() {
        let date = makeDate(year: 2026, month: 3, day: 11)
        let line = DailyNoteManager.buildMetadataLine(
            date: date,
            duration: 300,
            speakerCount: 1,
            meeting: nil,
            tags: [],
            structuringStatus: "partial",
            isAutoMode: true
        )

        XCTAssertTrue(line.contains("partial"))
        XCTAssertTrue(line.contains("auto"))
    }

    func testBuildMetadataLineSingleSpeaker() {
        let date = makeDate(year: 2026, month: 3, day: 11)
        let line = DailyNoteManager.buildMetadataLine(
            date: date,
            duration: 60,
            speakerCount: 1,
            meeting: nil,
            tags: [],
            structuringStatus: nil,
            isAutoMode: false
        )

        XCTAssertTrue(line.contains("1 speaker"))
        XCTAssertFalse(line.contains("1 speakers"))
    }

    // MARK: - extractSummaryLine / firstSentence

    func testExtractSummaryLineFromContent() {
        let content = """
        # Meeting Title

        ## Summary
        The team decided to move forward with option B. Additional details were discussed.

        ## Action Items
        - Kyle to follow up
        """

        let summary = DailyNoteManager.extractSummaryLine(from: content)
        XCTAssertEqual(summary, "The team decided to move forward with option B.")
    }

    func testExtractSummaryLineFromSessionSummary() {
        let content = """
        # Session

        ## Session Summary
        We covered three topics in this session. First was budget.

        ## Topic: Budget
        Details...
        """

        let summary = DailyNoteManager.extractSummaryLine(from: content)
        XCTAssertEqual(summary, "We covered three topics in this session.")
    }

    func testExtractSummaryLineReturnsNilWhenMissing() {
        let content = """
        # Meeting Title

        ## Action Items
        - Do stuff
        """

        let summary = DailyNoteManager.extractSummaryLine(from: content)
        XCTAssertNil(summary)
    }

    func testFirstSentenceBasic() {
        XCTAssertEqual(
            DailyNoteManager.firstSentence(of: "Hello world. More text."),
            "Hello world."
        )
    }

    func testFirstSentenceNoPeriodsShortText() {
        XCTAssertEqual(
            DailyNoteManager.firstSentence(of: "No period here"),
            "No period here"
        )
    }

    func testFirstSentenceTruncatesLongText() {
        let longText = String(repeating: "word ", count: 100)
        let result = DailyNoteManager.firstSentence(of: longText)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.count <= 205)  // 200 + "..."
    }

    func testFirstSentenceEmptyReturnsNil() {
        XCTAssertNil(DailyNoteManager.firstSentence(of: ""))
        XCTAssertNil(DailyNoteManager.firstSentence(of: "   "))
    }

    // MARK: - appendSection (Daily Doc Creation & Appending)

    func testAppendSectionCreatesDailyDoc() {
        let date = makeDate(year: 2026, month: 3, day: 11, hour: 10, minute: 0)
        let transcript = makeTranscript(duration: 600, speakerCount: 2)

        let url = DailyNoteManager.appendSection(
            content: "# Budget Review\n\n## Summary\nWe reviewed the budget.\n\n## Action Items\n- Finalize numbers",
            title: "Budget Review",
            transcript: transcript,
            tags: ["budget", "finance"],
            structuringStatus: "complete",
            recordingDate: date,
            saveLocation: tempDir
        )

        XCTAssertNotNil(url)
        XCTAssertEqual(url?.lastPathComponent, "2026-03-11.md")

        let content = try! String(contentsOf: url!, encoding: .utf8)

        // Should have the daily doc header
        XCTAssertTrue(content.contains("date: 2026-03-11"))

        // Should have the section heading at ## level
        XCTAssertTrue(content.contains("## Budget Review"))

        // Should have bumped headings
        XCTAssertTrue(content.contains("### Summary"))
        XCTAssertTrue(content.contains("### Action Items"))

        // Should have metadata line
        XCTAssertTrue(content.contains("10m 0s"))
        XCTAssertTrue(content.contains("tags: budget, finance"))
    }

    func testAppendSectionAppendsToExistingDoc() {
        let date = makeDate(year: 2026, month: 3, day: 11, hour: 10, minute: 0)
        let transcript1 = makeTranscript(duration: 600, speakerCount: 2)
        let transcript2 = makeTranscript(duration: 300, speakerCount: 1)

        // First section
        DailyNoteManager.appendSection(
            content: "# Morning Standup\n\n## Summary\nQuick sync.",
            title: "Morning Standup",
            transcript: transcript1,
            recordingDate: date,
            saveLocation: tempDir
        )

        // Second section — same day, different time
        let laterDate = makeDate(year: 2026, month: 3, day: 11, hour: 14, minute: 30)
        let url = DailyNoteManager.appendSection(
            content: "# Budget Review\n\n## Summary\nReviewed numbers.",
            title: "Budget Review",
            transcript: transcript2,
            recordingDate: laterDate,
            saveLocation: tempDir
        )

        XCTAssertNotNil(url)

        let content = try! String(contentsOf: url!, encoding: .utf8)

        // Should contain both sections
        XCTAssertTrue(content.contains("## Morning Standup"))
        XCTAssertTrue(content.contains("## Budget Review"))

        // The daily doc header should only appear once
        let headerCount = content.components(separatedBy: "# ").count { $0.starts(with: "Wednesday") || $0.starts(with: "Monday") || $0.starts(with: "Tuesday") || $0.starts(with: "Thursday") || $0.starts(with: "Friday") || $0.starts(with: "Saturday") || $0.starts(with: "Sunday") }
        // Simpler: count the frontmatter blocks
        let frontmatterCount = content.components(separatedBy: "---").count
        XCTAssertEqual(frontmatterCount, 3)  // opening ---, value, closing ---
    }

    // MARK: - appendFallbackSection

    func testAppendFallbackSection() {
        let date = makeDate(year: 2026, month: 3, day: 11, hour: 9, minute: 0)
        let transcript = makeTranscript(duration: 120, speakerCount: 1)

        let url = DailyNoteManager.appendFallbackSection(
            transcript: transcript,
            recordingDate: date,
            speakerName: "Kyle",
            saveLocation: tempDir
        )

        XCTAssertNotNil(url)

        let content = try! String(contentsOf: url!, encoding: .utf8)
        XCTAssertTrue(content.contains("could not be structured automatically"))
        XCTAssertTrue(content.contains("### Transcript"))
        XCTAssertTrue(content.contains("unstructured"))
    }

    func testAppendFallbackSectionReturnsNilForEmpty() {
        let date = makeDate(year: 2026, month: 3, day: 11)
        let empty = AssembledTranscript(segments: [], duration: 0)

        let url = DailyNoteManager.appendFallbackSection(
            transcript: empty,
            recordingDate: date,
            speakerName: nil,
            saveLocation: tempDir
        )

        XCTAssertNil(url)
    }

    // MARK: - appendMultiTopicSession

    func testAppendMultiTopicSession() {
        let date = makeDate(year: 2026, month: 3, day: 11, hour: 10, minute: 0)

        let topicSections = """
        ### Topic: Budget

        #### Summary
        Reviewed Q2 projections.

        ### Topic: Hiring

        #### Summary
        Need two engineers.
        """

        let url = DailyNoteManager.appendMultiTopicSession(
            sessionTitle: "Leadership Sync",
            sessionSummary: "Covered budget and hiring topics.",
            topicSections: topicSections,
            fullTranscriptText: "**Kyle:** Let's start...",
            totalDuration: 1800,
            speakerCount: 3,
            tags: ["budget", "hiring"],
            meeting: nil,
            recordingDate: date,
            saveLocation: tempDir,
            structuringPartial: false
        )

        XCTAssertNotNil(url)

        let content = try! String(contentsOf: url!, encoding: .utf8)
        XCTAssertTrue(content.contains("## Leadership Sync"))
        XCTAssertTrue(content.contains("### Session Summary"))
        XCTAssertTrue(content.contains("### Topic: Budget"))
        XCTAssertTrue(content.contains("### Full Transcript"))
    }

    // MARK: - Index Management

    func testUpdateIndexCreatesNewFile() {
        let date = makeDate(year: 2026, month: 3, day: 11)
        DailyNoteManager.updateIndex(
            title: "Morning Standup",
            summary: "Quick sync on sprint progress.",
            date: date,
            duration: 600,
            saveLocation: tempDir
        )

        let indexURL = tempDir.appendingPathComponent("index.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: indexURL.path))

        let content = try! String(contentsOf: indexURL, encoding: .utf8)
        XCTAssertTrue(content.contains("# Meeting Notes Index"))
        XCTAssertTrue(content.contains("## 2026-03-11"))
        XCTAssertTrue(content.contains("**Morning Standup**"))
        XCTAssertTrue(content.contains("10m"))
        XCTAssertTrue(content.contains("Quick sync on sprint progress."))
    }

    func testUpdateIndexAppendsToExistingDate() {
        let date1 = makeDate(year: 2026, month: 3, day: 11, hour: 9, minute: 0)
        let date2 = makeDate(year: 2026, month: 3, day: 11, hour: 14, minute: 0)

        DailyNoteManager.updateIndex(
            title: "Standup",
            summary: "Sprint sync.",
            date: date1,
            duration: 300,
            saveLocation: tempDir
        )

        DailyNoteManager.updateIndex(
            title: "Budget Review",
            summary: "Q2 numbers.",
            date: date2,
            duration: 1800,
            saveLocation: tempDir
        )

        let content = try! String(contentsOf: tempDir.appendingPathComponent("index.md"), encoding: .utf8)

        // Should have one date heading
        let dateHeadingCount = content.components(separatedBy: "## 2026-03-11").count - 1
        XCTAssertEqual(dateHeadingCount, 1)

        // Both entries should exist
        XCTAssertTrue(content.contains("**Standup**"))
        XCTAssertTrue(content.contains("**Budget Review**"))
    }

    func testUpdateIndexAddsNewDateAtTop() {
        let day1 = makeDate(year: 2026, month: 3, day: 10)
        let day2 = makeDate(year: 2026, month: 3, day: 11)

        // Add older date first
        DailyNoteManager.updateIndex(
            title: "Yesterday Meeting",
            summary: nil,
            date: day1,
            duration: 600,
            saveLocation: tempDir
        )

        // Add newer date
        DailyNoteManager.updateIndex(
            title: "Today Meeting",
            summary: nil,
            date: day2,
            duration: 900,
            saveLocation: tempDir
        )

        let content = try! String(contentsOf: tempDir.appendingPathComponent("index.md"), encoding: .utf8)

        // Newer date should appear before older date
        let range10 = content.range(of: "## 2026-03-10")!
        let range11 = content.range(of: "## 2026-03-11")!
        XCTAssertTrue(range11.lowerBound < range10.lowerBound, "Newer date should appear first in the index")
    }

    func testUpdateIndexWithNilSummary() {
        let date = makeDate(year: 2026, month: 3, day: 11)
        DailyNoteManager.updateIndex(
            title: "Quick Chat",
            summary: nil,
            date: date,
            duration: 120,
            saveLocation: tempDir
        )

        let content = try! String(contentsOf: tempDir.appendingPathComponent("index.md"), encoding: .utf8)
        XCTAssertTrue(content.contains("**Quick Chat**"))
        XCTAssertFalse(content.contains("—"))  // No summary separator
    }

    // MARK: - Integration: Full Pipeline

    func testFullPipelineMultipleSectionsAndIndex() {
        let date1 = makeDate(year: 2026, month: 3, day: 11, hour: 9, minute: 0)
        let date2 = makeDate(year: 2026, month: 3, day: 11, hour: 10, minute: 30)
        let date3 = makeDate(year: 2026, month: 3, day: 11, hour: 14, minute: 0)

        // Morning standup
        DailyNoteManager.appendSection(
            content: "# Standup\n\n## Summary\nTeam synced on sprint.",
            title: "Standup",
            transcript: makeTranscript(duration: 300, speakerCount: 4),
            tags: ["agile"],
            structuringStatus: "complete",
            recordingDate: date1,
            saveLocation: tempDir
        )

        // Design review
        DailyNoteManager.appendSection(
            content: "# Design Review\n\n## Summary\nReviewed new mockups.\n\n## Action Items\n- Update Figma",
            title: "Design Review",
            transcript: makeTranscript(duration: 1800, speakerCount: 3),
            tags: ["design", "ux"],
            structuringStatus: "complete",
            recordingDate: date2,
            saveLocation: tempDir
        )

        // Fallback (failed structuring)
        DailyNoteManager.appendFallbackSection(
            transcript: makeTranscript(duration: 600, speakerCount: 2),
            recordingDate: date3,
            speakerName: "Kyle",
            saveLocation: tempDir
        )

        // Verify the daily doc
        let dailyURL = DailyNoteManager.dailyDocURL(for: date1, in: tempDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dailyURL.path))

        let dailyContent = try! String(contentsOf: dailyURL, encoding: .utf8)

        // All three sections should be present
        XCTAssertTrue(dailyContent.contains("## Standup"))
        XCTAssertTrue(dailyContent.contains("## Design Review"))
        XCTAssertTrue(dailyContent.contains("could not be structured automatically"))

        // Headings should be bumped
        XCTAssertTrue(dailyContent.contains("### Summary"))
        XCTAssertTrue(dailyContent.contains("### Action Items"))

        // Verify the index
        let indexURL = tempDir.appendingPathComponent("index.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: indexURL.path))

        let indexContent = try! String(contentsOf: indexURL, encoding: .utf8)

        // All three entries should be in the index
        XCTAssertTrue(indexContent.contains("**Standup**"))
        XCTAssertTrue(indexContent.contains("**Design Review**"))
        XCTAssertTrue(indexContent.contains("Recording"))  // Fallback title pattern

        // Summaries should be first-sentence-only
        XCTAssertTrue(indexContent.contains("Team synced on sprint."))
        XCTAssertTrue(indexContent.contains("Reviewed new mockups."))
    }

    // MARK: - Test Helpers

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    private func makeTranscript(duration: TimeInterval, speakerCount: Int) -> AssembledTranscript {
        var segments: [TranscriptSegment] = []
        for i in 0..<max(speakerCount, 1) {
            segments.append(TranscriptSegment(
                speaker: i,
                text: "Test content from speaker \(i).",
                startTime: Double(i) * 10.0,
                endTime: Double(i) * 10.0 + 9.0
            ))
        }
        return AssembledTranscript(segments: segments, duration: duration)
    }
}
