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
        let wantStereo = settings.systemAudioEnabled

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
        let assemblyAIAPIKey = settings?.assemblyAIAPIKey ?? ""
        let speechModels = settings?.assemblyAISpeechModels ?? ["universal-2"]
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
                assemblyAIAPIKey: assemblyAIAPIKey,
                speechModels: speechModels,
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
        assemblyAIAPIKey: String,
        speechModels: [String],
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
        if assemblyAIAPIKey.isEmpty {
            logger.warning("No AssemblyAI API key — discarding auto recording")
            if let audioToCleanup { try? FileManager.default.removeItem(at: audioToCleanup) }
            return
        }

        let service: TranscriptionService = AssemblyAITranscriptionService(apiKey: assemblyAIAPIKey, speechModels: speechModels)
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

        // --- Single-topic: append to daily document ---
        if topicResults.count <= 1 {
            let result = topicResults[0]

            if let content = result.structuredContent {
                let structuringStatus = result.truncated ? "partial" : "complete"
                DailyNoteManager.appendSection(
                    content: content,
                    title: result.title,
                    transcript: result.transcript,
                    tags: result.tags,
                    structuringStatus: structuringStatus,
                    meeting: currentMeeting,
                    recordingDate: date,
                    speakerName: speakerName,
                    saveLocation: saveLocation,
                    isAutoMode: true
                )
            } else {
                DailyNoteManager.appendFallbackSection(
                    transcript: result.transcript,
                    recordingDate: date,
                    speakerName: speakerName,
                    saveLocation: saveLocation,
                    meeting: currentMeeting,
                    isAutoMode: true
                )
            }

            logger.info("Auto note saved (single topic): \(result.title ?? "untitled")")
            return
        }

        // --- Multi-topic: append as a single session section to daily document ---

        // Build full session transcript from all topic segments
        let allSegments = topics.flatMap(\.segments)
        let totalDuration = topics.reduce(0.0) { $0 + $1.duration }
        let fullTranscript = AssembledTranscript(segments: allSegments, duration: totalDuration)
        let fullTranscriptText = fullTranscript.formatted(speakerName: speakerName)

        // Generate session-level summary from per-topic summaries
        let topicSummaries = topicResults.compactMap { result -> String? in
            guard let content = result.structuredContent else { return nil }
            return DailyNoteManager.extractSummaryLine(from: content)
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

        // Merge and deduplicate tags from all topics
        let allTags = Array(Set(topicResults.flatMap(\.tags))).sorted()

        // Build per-topic sections as ### headings
        var topicSectionsText = ""
        for result in topicResults {
            let topicHeading = result.title ?? "Untitled Topic"
            topicSectionsText += "### Topic: \(topicHeading)\n"

            if let content = result.structuredContent {
                // Transform structured content: strip title, bump headings for sub-topic level
                let transformed = DailyNoteManager.transformForDaily(content: content)
                topicSectionsText += transformed
            } else {
                topicSectionsText += result.transcript.formatted(speakerName: speakerName)
            }

            topicSectionsText += "\n\n"
        }

        // Determine structuring status
        let anyTruncated = topicResults.contains { $0.truncated }
        let anyFailed = topicResults.contains { $0.structuredContent == nil }
        let structuringPartial = anyTruncated || anyFailed

        DailyNoteManager.appendMultiTopicSession(
            sessionTitle: sessionTitle,
            sessionSummary: sessionSummary,
            topicSections: topicSectionsText.trimmingCharacters(in: .whitespacesAndNewlines),
            fullTranscriptText: fullTranscriptText,
            totalDuration: totalDuration,
            speakerCount: fullTranscript.speakerCount,
            tags: allTags,
            meeting: currentMeeting,
            recordingDate: date,
            saveLocation: saveLocation,
            structuringPartial: structuringPartial
        )

        logger.info("Auto session note saved (\(topicResults.count) topics): \(sessionTitle)")
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

            if structuredContent != nil {
                DailyNoteManager.appendSection(
                    content: content,
                    title: title,
                    transcript: subTranscript,
                    tags: tags,
                    structuringStatus: structuringStatus,
                    meeting: segment.meeting,
                    recordingDate: date,
                    speakerName: speakerName,
                    saveLocation: saveLocation,
                    isAutoMode: true
                )
            } else {
                DailyNoteManager.appendFallbackSection(
                    transcript: subTranscript,
                    recordingDate: date,
                    speakerName: speakerName,
                    saveLocation: saveLocation,
                    meeting: segment.meeting,
                    isAutoMode: true
                )
            }

            logger.info("Auto meeting note saved: \(title ?? segment.meeting.title)")
        }
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
