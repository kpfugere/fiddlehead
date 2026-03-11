import Foundation
import os.log

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "AutoMode")

/// Orchestrates the auto mode lifecycle: listen → record → transcribe → split → structure → save.
/// Owns its own AudioCaptureManager instance, separate from RecordingPipeline's.
@MainActor
final class AutoModeController: ObservableObject {
    enum State: Equatable {
        case disabled
        case listening
        case recording
        case processing
        case cooldown
        case error(String)

        var isActive: Bool {
            switch self {
            case .disabled: return false
            default: return true
            }
        }
    }

    @Published var state: State = .disabled
    @Published var currentRecordingDuration: TimeInterval = 0

    private let vad = VADSampler()
    private let audioCaptureManager = AudioCaptureManager()
    private let silenceDetector = SilenceDetector()
    private let calendarService = CalendarService()

    private var settings: AppSettings?
    private var timer: Timer?
    private var recordingStartDate: Date?
    private var silenceMonitorTask: Task<Void, Never>?
    private var maxDurationTask: Task<Void, Never>?
    private var tempAudioURL: URL?
    private var actualChannelCount: Int = 1

    func configure(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Enable / Disable

    func enable() {
        guard case .disabled = state else { return }
        guard let settings, settings.hasAPIKeys else {
            logger.warning("Cannot enable auto mode — no API key")
            return
        }

        vad.onVoiceDetected = { [weak self] in
            self?.onVoiceDetected()
        }

        startListening()
        logger.info("Auto mode enabled")
    }

    func disable() {
        guard state != .disabled else { return }

        // Stop whatever is running
        vad.stop()
        stopTimer()
        silenceMonitorTask?.cancel()
        silenceMonitorTask = nil
        maxDurationTask?.cancel()
        maxDurationTask = nil

        if case .recording = state {
            audioCaptureManager.stopCapture()
            cleanupTempAudio()
        }

        state = .disabled
        currentRecordingDuration = 0
        logger.info("Auto mode disabled")
    }

    // MARK: - State Transitions

    private func startListening() {
        state = .listening
        vad.start()
    }

    private func onVoiceDetected() {
        guard case .listening = state else { return }
        guard let settings else { return }

        logger.info("Voice detected — starting auto recording")

        settings.ensureSaveLocationExists()

        let now = Date()
        recordingStartDate = now

        // Create temp audio file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fiddlehead_auto_\(UUID().uuidString).wav")
        tempAudioURL = tempURL

        let audioStream = audioCaptureManager.prepareStream()

        // Use stereo interleave when AssemblyAI multichannel is applicable
        let wantStereo = settings.systemAudioEnabled && settings.transcriptionProvider == .assemblyai

        do {
            try audioCaptureManager.startCapture(
                systemAudio: settings.systemAudioEnabled,
                stereo: wantStereo,
                saveAudioTo: tempURL,
                onReady: { [weak self] actualChannels in
                    guard let self else { return }
                    self.actualChannelCount = actualChannels
                    self.silenceDetector.channels = actualChannels
                    logger.info("Auto capture ready — actual channels: \(actualChannels)")
                }
            )
            state = .recording
            currentRecordingDuration = 0
            startTimer()
            startSilenceMonitor(stream: audioStream)
            startMaxDurationGuard(settings: settings)

            logger.info("Auto recording started — stereo: \(wantStereo)")
        } catch {
            logger.error("Auto recording failed to start: \(error.localizedDescription, privacy: .public)")
            cleanupTempAudio()
            startListening()
        }
    }

    private func stopRecordingAndProcess() {
        guard case .recording = state else { return }

        stopTimer()
        silenceMonitorTask?.cancel()
        silenceMonitorTask = nil
        maxDurationTask?.cancel()
        maxDurationTask = nil
        audioCaptureManager.stopCapture()

        let duration = currentRecordingDuration
        currentRecordingDuration = 0

        // Discard very short recordings without API call
        if duration < 30 {
            logger.info("Auto recording too short (\(duration, format: .fixed(precision: 0))s) — discarding")
            cleanupTempAudio()
            startCooldown()
            return
        }

        // Snapshot everything we need for processing
        let audioURL = audioCaptureManager.savedAudioURL
        let recordingDate = recordingStartDate ?? Date()
        let apiKey = settings?.openAIAPIKey ?? ""
        let transcriptionProvider = settings?.transcriptionProvider ?? .openai
        let assemblyAIAPIKey = settings?.assemblyAIAPIKey ?? ""
        let speakerName = settings?.speakerName ?? ""
        let saveLocation = settings?.saveLocation
        let audioToCleanup = tempAudioURL
        let channelCount = actualChannelCount

        // Clear temp reference so it doesn't get cleaned up by a new recording cycle
        tempAudioURL = nil
        actualChannelCount = 1

        // Return to listening immediately — processing runs in background
        startCooldown()

        Task {
            await self.processRecordingSnapshot(
                audioURL: audioURL,
                recordingDate: recordingDate,
                apiKey: apiKey,
                transcriptionProvider: transcriptionProvider,
                assemblyAIAPIKey: assemblyAIAPIKey,
                speakerName: speakerName,
                saveLocation: saveLocation,
                audioToCleanup: audioToCleanup,
                channelCount: channelCount
            )
        }
    }

    private func startCooldown() {
        state = .cooldown
        Task {
            try? await Task.sleep(for: .seconds(5))
            guard case .cooldown = self.state else { return }
            self.startListening()
        }
    }

    // MARK: - Processing Pipeline (runs in background, uses only snapshotted values)

    private func processRecordingSnapshot(
        audioURL: URL?,
        recordingDate: Date,
        apiKey: String,
        transcriptionProvider: TranscriptionProvider,
        assemblyAIAPIKey: String,
        speakerName: String,
        saveLocation: URL?,
        audioToCleanup: URL?,
        channelCount: Int
    ) async {
        guard let audioURL, FileManager.default.fileExists(atPath: audioURL.path) else {
            logger.error("No audio file found for auto mode processing")
            if let audioToCleanup { try? FileManager.default.removeItem(at: audioToCleanup) }
            return
        }

        guard !apiKey.isEmpty else {
            logger.warning("No API key — discarding auto recording")
            if let audioToCleanup { try? FileManager.default.removeItem(at: audioToCleanup) }
            return
        }

        guard let saveLocation else {
            logger.error("No save location for auto mode")
            if let audioToCleanup { try? FileManager.default.removeItem(at: audioToCleanup) }
            return
        }

        let resolvedSpeakerName = speakerName.isEmpty ? nil : speakerName

        // Step 1: Transcribe
        if transcriptionProvider == .assemblyai && assemblyAIAPIKey.isEmpty {
            logger.warning("AssemblyAI selected but no API key — discarding auto recording")
            if let audioToCleanup { try? FileManager.default.removeItem(at: audioToCleanup) }
            return
        }

        let service: TranscriptionService = switch transcriptionProvider {
        case .openai:
            OpenAITranscriptionService(apiKey: apiKey)
        case .assemblyai:
            AssemblyAITranscriptionService(apiKey: assemblyAIAPIKey)
        }
        let transcript: AssembledTranscript

        do {
            transcript = try await service.transcribe(fileURL: audioURL, channels: channelCount)
            logger.info("Auto transcript — segments: \(transcript.segments.count), duration: \(transcript.duration, format: .fixed(precision: 0))s")
        } catch {
            logger.error("Auto transcription failed: \(error.localizedDescription, privacy: .public)")
            if let audioToCleanup { try? FileManager.default.removeItem(at: audioToCleanup) }
            return
        }

        // Discard near-empty transcripts (< 20 words)
        let wordCount = transcript.segments.reduce(0) { $0 + $1.text.split(separator: " ").count }
        if transcript.isEmpty || wordCount < 20 {
            logger.info("Auto transcript too short (\(wordCount) words) — discarding")
            if let audioToCleanup { try? FileManager.default.removeItem(at: audioToCleanup) }
            return
        }

        // Step 2a: Check for multi-meeting splitting (takes priority over topic splitting)
        let recordingEnd = recordingDate.addingTimeInterval(transcript.duration)
        let overlappingMeetings = calendarService.meetingsDuring(from: recordingDate, to: recordingEnd)

        if let meetingSegments = MeetingSplitter.split(
            transcript: transcript,
            meetings: overlappingMeetings,
            recordingStart: recordingDate
        ) {
            logger.info("Auto mode: calendar split into \(meetingSegments.count) meetings — skipping topic split")
            await structureAndSaveMeetingSegmentsAuto(
                segments: meetingSegments, date: recordingDate,
                apiKey: apiKey, speakerName: resolvedSpeakerName, saveLocation: saveLocation
            )
            if let audioToCleanup { try? FileManager.default.removeItem(at: audioToCleanup) }
            return
        }

        // Step 2b: Split by topic (single or no meeting)
        let splitter = TopicSplitter(apiKey: apiKey)
        let topics: [TopicSplitter.TopicSegment]

        do {
            topics = try await splitter.split(transcript: transcript, speakerName: resolvedSpeakerName)
            logger.info("Auto mode split into \(topics.count) topic(s)")
        } catch {
            logger.error("Topic splitting failed: \(error.localizedDescription, privacy: .public)")
            // Fallback: treat entire transcript as one topic
            let fallbackTopics = [TopicSplitter.TopicSegment(
                title: "",
                segments: transcript.segments,
                duration: transcript.duration
            )]
            await structureAndSaveSnapshot(
                topics: fallbackTopics, date: recordingDate,
                apiKey: apiKey, speakerName: resolvedSpeakerName, saveLocation: saveLocation
            )
            if let audioToCleanup { try? FileManager.default.removeItem(at: audioToCleanup) }
            return
        }

        // Step 3: Structure each topic and save
        await structureAndSaveSnapshot(
            topics: topics, date: recordingDate,
            apiKey: apiKey, speakerName: resolvedSpeakerName, saveLocation: saveLocation
        )
        if let audioToCleanup { try? FileManager.default.removeItem(at: audioToCleanup) }
    }

    private func structureAndSaveSnapshot(
        topics: [TopicSplitter.TopicSegment],
        date: Date,
        apiKey: String,
        speakerName: String?,
        saveLocation: URL
    ) async {
        let structurer = OpenAIStructuringService(apiKey: apiKey)

        // Check if there's a meeting happening right now
        let currentMeeting = calendarService.currentMeeting()
        if let meeting = currentMeeting {
            logger.info("Auto mode detected active meeting: \(meeting.title, privacy: .public) with \(meeting.attendees.count) attendees")
        }

        // Structure each topic and collect results
        struct TopicResult {
            let title: String?
            let structuredContent: String?  // cleaned, no tag comments
            let tags: [String]
            let transcript: AssembledTranscript
            let topicDuration: TimeInterval
            let truncated: Bool
        }

        var topicResults: [TopicResult] = []

        for (index, topic) in topics.enumerated() {
            let topicTranscript = AssembledTranscript(
                segments: topic.segments,
                duration: topic.duration
            )

            // Structure via OpenAI
            var structuredContent: String?
            var topicTruncated = false
            do {
                let result = try await structurer.structure(
                    transcript: topicTranscript.formatted(speakerName: speakerName),
                    duration: topic.duration,
                    meetingTitle: currentMeeting?.title
                )
                structuredContent = result.content
                topicTruncated = result.truncated
            } catch {
                logger.error("Auto structuring failed for topic \(index + 1): \(error.localizedDescription, privacy: .public)")
            }

            // Extract tags, strip comments, clean empty sections
            let topicTags: [String]
            let cleanedContent: String?
            if let structured = structuredContent {
                topicTags = NotePostProcessor.extractTags(from: structured)
                var cleaned = NotePostProcessor.stripTagsComment(from: structured)
                cleaned = NotePostProcessor.stripEmptySections(from: cleaned)
                cleanedContent = cleaned
            } else {
                topicTags = []
                cleanedContent = nil
            }

            let title: String?
            if let cleaned = cleanedContent {
                title = NoteStorage.extractTitleFromContent(cleaned) ?? topic.title
            } else {
                title = topic.title.isEmpty ? nil : topic.title
            }

            topicResults.append(TopicResult(
                title: title,
                structuredContent: cleanedContent,
                tags: topicTags,
                transcript: topicTranscript,
                topicDuration: topic.duration,
                truncated: topicTruncated
            ))

            logger.info("Structured topic \(index + 1)/\(topics.count): \(title ?? "untitled")")
        }

        // --- Single-topic: save using the existing per-note format ---
        if topicResults.count <= 1 {
            let result = topicResults[0]
            let content = result.structuredContent ?? result.transcript.formatted(speakerName: speakerName)
            let structuringStatus: String? = result.structuredContent == nil ? nil : (result.truncated ? "partial" : "complete")

            saveAutoNoteSnapshot(
                content: content,
                isStructured: result.structuredContent != nil,
                title: result.title,
                transcript: result.transcript,
                date: date,
                saveLocation: saveLocation,
                tags: result.tags,
                meeting: currentMeeting,
                structuringStatus: structuringStatus
            )

            logger.info("Auto note saved (single topic): \(result.title ?? "untitled")")
            return
        }

        // --- Multi-topic: assemble into one session document ---

        // Build full session transcript from all topic segments
        let allSegments = topics.flatMap(\.segments)
        let totalDuration = topics.reduce(0.0) { $0 + $1.duration }
        let fullTranscript = AssembledTranscript(segments: allSegments, duration: totalDuration)
        let fullTranscriptText = fullTranscript.formatted(speakerName: speakerName)

        // Generate session-level summary from per-topic summaries
        let topicSummaries = topicResults.compactMap { result -> String? in
            guard let content = result.structuredContent else { return nil }
            return extractSection(named: "Summary", from: content)
        }

        var sessionSummary: String?
        if topicSummaries.count > 1 {
            do {
                sessionSummary = try await structurer.summarizeSession(topicSummaries: topicSummaries)
            } catch {
                logger.warning("Session summary generation failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Derive session title
        let sessionTitle: String
        if let meeting = currentMeeting {
            sessionTitle = meeting.title
        } else if let firstTitle = topicResults.first(where: { $0.title != nil })?.title {
            sessionTitle = firstTitle
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            sessionTitle = "Session — \(formatter.string(from: date))"
        }

        // Build frontmatter
        let durationMin = Int(totalDuration) / 60
        let durationSec = Int(totalDuration) % 60
        let topicTitles = topicResults.compactMap(\.title)

        var frontmatter = """
        ---
        date: \(ISO8601DateFormatter().string(from: date))
        duration: \(durationMin)m \(durationSec)s
        speakers: \(fullTranscript.speakerCount)
        """

        // Merge and deduplicate tags from all topics
        let allTags = Array(Set(topicResults.flatMap(\.tags))).sorted()
        if !allTags.isEmpty {
            frontmatter += "\ntags: [\(allTags.joined(separator: ", "))]"
        }

        if !topicTitles.isEmpty {
            frontmatter += "\ntopics: \(topicTitles.joined(separator: "; "))"
        }

        if let meeting = currentMeeting {
            frontmatter += "\nmeeting: \(meeting.title)"
            frontmatter += "\nattendees: \(meeting.attendees.joined(separator: ", "))"
            frontmatter += "\ncalendar_event_id: \(meeting.id)"
        }

        // Determine structuring status: partial if any topic was truncated or unstructured
        let anyTruncated = topicResults.contains { $0.truncated }
        let anyFailed = topicResults.contains { $0.structuredContent == nil }
        if anyTruncated || anyFailed {
            frontmatter += "\nstructuring_status: partial"
        }

        frontmatter += "\nsource: auto\n---"

        // Build body
        var body = "# \(sessionTitle)\n\n"

        if let summary = sessionSummary {
            body += "## Session Summary\n\(summary)\n\n"
        }

        for result in topicResults {
            let topicHeading = result.title ?? "Untitled Topic"
            body += "## Topic: \(topicHeading)\n"

            if let content = result.structuredContent {
                // Extract sections (Summary, Action Items, Key Points, Decisions)
                // but skip the title heading and transcript — we have our own full transcript
                body += extractTopicSections(from: content)
            } else {
                body += result.transcript.formatted(speakerName: speakerName)
            }

            body += "\n\n"
        }

        body += "## Full Transcript\n\(fullTranscriptText)"

        // Save as single file
        let fullContent = "\(frontmatter)\n\n\(body)"
        let baseFilename = NoteStorage.noteFilename(for: date, title: sessionTitle)
        let filename = NoteStorage.uniqueFilename(base: baseFilename, in: saveLocation)
        let url = saveLocation.appendingPathComponent(filename)

        do {
            try fullContent.write(to: url, atomically: true, encoding: .utf8)
            logger.info("Auto session note saved (\(topicResults.count) topics): \(sessionTitle)")
        } catch {
            logger.error("Failed to save auto session note: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Calendar-Aware Meeting Splitting (Auto Mode)

    /// Structures and saves each meeting segment as a separate note.
    /// Used when MeetingSplitter detects multiple calendar meetings during a recording.
    private func structureAndSaveMeetingSegmentsAuto(
        segments: [MeetingSegment],
        date: Date,
        apiKey: String,
        speakerName: String?,
        saveLocation: URL
    ) async {
        let structurer = OpenAIStructuringService(apiKey: apiKey)

        for (i, segment) in segments.enumerated() {
            logger.info("Auto mode structuring meeting \(i + 1)/\(segments.count): \(segment.meeting.title)")

            let subTranscript = AssembledTranscript(
                segments: segment.segments,
                duration: segment.duration,
                multichannelLabeled: false
            )

            var structuredContent: String?
            var truncated = false

            do {
                let result = try await structurer.structure(
                    transcript: subTranscript.formatted(speakerName: speakerName),
                    duration: subTranscript.duration,
                    meetingTitle: segment.meeting.title
                )
                structuredContent = result.content
                truncated = result.truncated
            } catch {
                logger.error("Auto structuring failed for '\(segment.meeting.title)': \(error.localizedDescription, privacy: .public)")
            }

            let content: String
            let title: String?
            let tags: [String]
            let structuringStatus: String?

            if let structured = structuredContent {
                tags = NotePostProcessor.extractTags(from: structured)
                var cleaned = NotePostProcessor.stripTagsComment(from: structured)
                cleaned = NotePostProcessor.stripEmptySections(from: cleaned)
                content = cleaned
                title = NoteStorage.extractTitleFromContent(cleaned)
                structuringStatus = truncated ? "partial" : "complete"
            } else {
                content = subTranscript.formatted(speakerName: speakerName)
                title = segment.meeting.title
                tags = []
                structuringStatus = nil
            }

            saveAutoNoteSnapshot(
                content: content,
                isStructured: structuredContent != nil,
                title: title,
                transcript: subTranscript,
                date: date,
                saveLocation: saveLocation,
                tags: tags,
                meeting: segment.meeting,
                structuringStatus: structuringStatus
            )

            logger.info("Auto meeting note saved: \(title ?? segment.meeting.title)")
        }
    }

    private func saveAutoNoteSnapshot(
        content: String,
        isStructured: Bool,
        title: String?,
        transcript: AssembledTranscript,
        date: Date,
        saveLocation: URL,
        tags: [String] = [],
        meeting: MeetingEvent? = nil,
        structuringStatus: String? = nil
    ) {
        let baseFilename = NoteStorage.noteFilename(for: date, title: title)
        let filename = NoteStorage.uniqueFilename(base: baseFilename, in: saveLocation)
        let url = saveLocation.appendingPathComponent(filename)

        let durationMin = Int(transcript.duration) / 60
        let durationSec = Int(transcript.duration) % 60

        var frontmatter = """
        ---
        date: \(ISO8601DateFormatter().string(from: date))
        duration: \(durationMin)m \(durationSec)s
        speakers: \(transcript.speakerCount)
        """

        if !tags.isEmpty {
            frontmatter += "\ntags: [\(tags.joined(separator: ", "))]"
        }

        if let meeting {
            frontmatter += "\nmeeting: \(meeting.title)"
            frontmatter += "\nattendees: \(meeting.attendees.joined(separator: ", "))"
            frontmatter += "\ncalendar_event_id: \(meeting.id)"
        }

        if let structuringStatus {
            frontmatter += "\nstructuring_status: \(structuringStatus)"
        }

        frontmatter += "\nsource: auto\n---"

        let body: String
        if isStructured {
            body = content
        } else {
            // Fallback: wrap plain transcript in minimal markdown
            let heading = title.map { "# \($0)\n\n" } ?? ""
            body = "\(heading)\(content)"
        }

        let fullContent = "\(frontmatter)\n\n\(body)"

        do {
            try fullContent.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            logger.error("Failed to save auto note: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Content Extraction Helpers

    /// Extract the text content of a named `## Section` from structured markdown.
    private func extractSection(named section: String, from content: String) -> String? {
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

    /// Extract topic-level sections from structured content, bumping `##` to `###`.
    /// Strips the `# Title` heading and `## Transcript` section (we use the full session transcript instead).
    private func extractTopicSections(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var result: [String] = []
        var inTranscript = false

        for line in lines {
            // Skip the top-level title
            if line.hasPrefix("# ") && !line.hasPrefix("## ") {
                continue
            }

            // Skip the Transcript section entirely
            if line.hasPrefix("## Transcript") {
                inTranscript = true
                continue
            }
            if inTranscript {
                // Stop skipping if we hit another ## section (shouldn't happen, but be safe)
                if line.hasPrefix("## ") {
                    inTranscript = false
                } else {
                    continue
                }
            }

            // Bump ## headings to ###
            if line.hasPrefix("## ") {
                result.append("#\(line)")  // "## X" becomes "### X"
            } else {
                result.append(line)
            }
        }

        return result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Silence & Duration Monitors

    private func startSilenceMonitor(stream: AsyncStream<Data>) {
        silenceDetector.reset()
        silenceDetector.silenceTimeoutSeconds = 60 // 1 minute for auto mode

        silenceDetector.onSilenceTimeout = { [weak self] in
            guard let self, case .recording = self.state else { return }
            logger.info("Auto mode silence timeout — stopping recording")
            self.stopRecordingAndProcess()
        }

        silenceMonitorTask = Task { [weak self] in
            for await chunk in stream {
                guard !Task.isCancelled else { break }
                self?.silenceDetector.processBuffer(chunk)
            }
        }
    }

    private func startMaxDurationGuard(settings: AppSettings) {
        let maxMinutes = settings.autoModeMaxRecordingMinutes
        guard maxMinutes > 0 else { return }

        maxDurationTask = Task {
            try? await Task.sleep(for: .seconds(maxMinutes * 60))
            guard !Task.isCancelled, case .recording = self.state else { return }
            logger.info("Auto mode max duration (\(maxMinutes)min) reached — stopping")
            self.stopRecordingAndProcess()
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentRecordingDuration += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Helpers

    private func cleanupTempAudio() {
        guard let url = tempAudioURL else { return }
        try? FileManager.default.removeItem(at: url)
        tempAudioURL = nil
    }

}
