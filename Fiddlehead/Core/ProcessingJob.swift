import Foundation
import os.log

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "ProcessingJob")

/// A self-contained, observable unit of work that processes a recorded audio file
/// through the compress → transcribe → structure → save pipeline.
///
/// Designed to run independently from the recording pipeline so that new recordings
/// can start while previous recordings are still being processed.
@MainActor
final class ProcessingJob: ObservableObject, Identifiable {
    let id = UUID()
    @Published var stage: ProcessingStage = .transcribing
    @Published var errorMessage: String?

    // Snapshotted inputs — everything needed to process without touching AppSettings
    private let audioURL: URL
    private let openAIAPIKey: String
    private let assemblyAIAPIKey: String
    private let speechModels: [String]
    private let speakerName: String?
    private let saveLocation: URL
    private let keepAudioEnabled: Bool
    private let recordingDate: Date
    private let activeMeeting: MeetingEvent?
    private let isTempAudio: Bool
    private let channelCount: Int
    private let allMeetings: [MeetingEvent]

    /// Result callback: (noteURL, title?) on success, nil on failure
    var onComplete: ((URL?, String?) -> Void)?

    init(
        audioURL: URL,
        openAIAPIKey: String,
        assemblyAIAPIKey: String,
        speechModels: [String] = ["universal-2"],
        speakerName: String?,
        saveLocation: URL,
        keepAudioEnabled: Bool,
        recordingDate: Date,
        activeMeeting: MeetingEvent?,
        isTempAudio: Bool,
        channelCount: Int = 1,
        allMeetings: [MeetingEvent] = []
    ) {
        self.audioURL = audioURL
        self.openAIAPIKey = openAIAPIKey
        self.assemblyAIAPIKey = assemblyAIAPIKey
        self.speechModels = speechModels
        self.speakerName = speakerName
        self.saveLocation = saveLocation
        self.keepAudioEnabled = keepAudioEnabled
        self.recordingDate = recordingDate
        self.activeMeeting = activeMeeting
        self.isTempAudio = isTempAudio
        self.channelCount = channelCount
        self.allMeetings = allMeetings
    }

    // MARK: - Run

    func run() async {
        logger.info("ProcessingJob started — audio: \(self.audioURL.lastPathComponent)")

        // Step 1: Transcribe
        stage = .transcribing

        var transcript: AssembledTranscript?

        guard !openAIAPIKey.isEmpty else {
            logger.warning("OpenAI API key empty — cannot process")
            errorMessage = "No OpenAI API key"
            cleanupTempAudio()
            onComplete?(nil, nil)
            return
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            logger.error("Audio file not found: \(self.audioURL.path)")
            errorMessage = "Audio file not found"
            cleanupTempAudio()
            onComplete?(nil, nil)
            return
        }

        guard !assemblyAIAPIKey.isEmpty else {
            logger.warning("AssemblyAI API key empty — cannot process")
            errorMessage = "No AssemblyAI API key"
            cleanupTempAudio()
            onComplete?(nil, nil)
            return
        }

        logger.info("Using AssemblyAI transcription")

        let service: TranscriptionService = AssemblyAITranscriptionService(apiKey: assemblyAIAPIKey, speechModels: speechModels)

        do {
            transcript = try await service.transcribe(
                fileURL: audioURL,
                channels: channelCount
            )
            logger.info("Transcript received — segments: \(transcript!.segments.count), duration: \(transcript!.duration)s")
        } catch {
            logger.error("Transcription failed: \(error.localizedDescription, privacy: .public)")

            let userMessage: String
            if let apiError = error as? AssemblyAITranscriptionError {
                switch apiError {
                case .uploadFailed(let code, _), .apiError(let code, _):
                    switch code {
                    case 401: userMessage = "Invalid AssemblyAI API key"
                    case 429: userMessage = "AssemblyAI rate limited — try again"
                    default: userMessage = "AssemblyAI error (\(code))"
                    }
                case .timeout:
                    userMessage = "AssemblyAI transcription timed out"
                case .transcriptionFailed(let msg):
                    userMessage = "AssemblyAI failed: \(msg)"
                case .invalidResponse:
                    userMessage = "Invalid response from AssemblyAI"
                }
            } else {
                userMessage = "Transcription failed"
            }

            errorMessage = userMessage
            cleanupTempAudio()
            onComplete?(nil, nil)
            return
        }

        if transcript == nil || transcript!.isEmpty {
            if keepAudioEnabled {
                onComplete?(audioURL, nil)
            } else {
                errorMessage = "No speech detected"
                cleanupTempAudio()
                onComplete?(nil, nil)
            }
            return
        }

        let confirmedTranscript = transcript!

        // Step 2: Check for multi-meeting splitting
        if let meetingSegments = MeetingSplitter.split(
            transcript: confirmedTranscript,
            meetings: allMeetings,
            recordingStart: recordingDate
        ) {
            logger.info("Multi-meeting split: \(meetingSegments.count) meetings detected")
            await structureAndSaveMeetingSegments(meetingSegments)
            return
        }

        // Single-meeting path (original behavior)
        await structureAndSaveSingle(transcript: confirmedTranscript, meeting: activeMeeting)
    }

    // MARK: - Multi-Meeting Pipeline

    private func structureAndSaveMeetingSegments(_ segments: [MeetingSegment]) async {
        let structurer = OpenAIStructuringService(apiKey: openAIAPIKey)
        var firstNoteURL: URL?
        var firstTitle: String?

        for (i, segment) in segments.enumerated() {
            stage = .structuring
            logger.info("Structuring meeting \(i + 1)/\(segments.count): \(segment.meeting.title)")

            let subTranscript = AssembledTranscript(
                segments: segment.segments,
                duration: segment.duration,
                multichannelLabeled: false
            )

            var structuredContent: String?
            var structuringTruncated = false

            do {
                let result = try await structurer.structure(
                    transcript: subTranscript.formatted(speakerName: speakerName),
                    duration: subTranscript.duration,
                    meetingTitle: segment.meeting.title
                )
                structuredContent = result.content
                structuringTruncated = result.truncated
            } catch {
                logger.error("Structuring failed for '\(segment.meeting.title)': \(error.localizedDescription, privacy: .public)")
            }

            stage = .saving

            if let structured = structuredContent {
                let tags = NotePostProcessor.extractTags(from: structured)
                var cleanedContent = NotePostProcessor.stripTagsComment(from: structured)
                cleanedContent = NotePostProcessor.stripEmptySections(from: cleanedContent)
                let title = NoteStorage.extractTitleFromContent(cleanedContent)
                let structuringStatus = structuringTruncated ? "partial" : "complete"
                let noteURL = saveStructuredNote(
                    content: cleanedContent,
                    title: title,
                    transcript: subTranscript,
                    tags: tags,
                    structuringStatus: structuringStatus,
                    meeting: segment.meeting
                )
                if firstNoteURL == nil {
                    firstNoteURL = noteURL
                    firstTitle = title
                }
            } else {
                let fallbackURL = saveFallback(transcript: subTranscript)
                if firstNoteURL == nil { firstNoteURL = fallbackURL }
            }
        }

        cleanupTempAudio()
        onComplete?(firstNoteURL, firstTitle)
    }

    // MARK: - Single-Note Pipeline

    private func structureAndSaveSingle(transcript: AssembledTranscript, meeting: MeetingEvent?) async {
        stage = .structuring

        var structuredContent: String?
        var structuringTruncated = false

        let structurer = OpenAIStructuringService(apiKey: openAIAPIKey)
        do {
            let result = try await structurer.structure(
                transcript: transcript.formatted(speakerName: speakerName),
                duration: transcript.duration,
                meetingTitle: meeting?.title
            )
            structuredContent = result.content
            structuringTruncated = result.truncated
        } catch {
            logger.error("Structuring failed: \(error.localizedDescription, privacy: .public)")
        }

        stage = .saving

        if let structured = structuredContent {
            let tags = NotePostProcessor.extractTags(from: structured)
            var cleanedContent = NotePostProcessor.stripTagsComment(from: structured)
            cleanedContent = NotePostProcessor.stripEmptySections(from: cleanedContent)
            let title = NoteStorage.extractTitleFromContent(cleanedContent)
            let structuringStatus = structuringTruncated ? "partial" : "complete"
            let noteURL = saveStructuredNote(
                content: cleanedContent,
                title: title,
                transcript: transcript,
                tags: tags,
                structuringStatus: structuringStatus,
                meeting: meeting
            )
            cleanupTempAudio()
            onComplete?(noteURL, title)
        } else {
            let fallbackURL = saveFallback(transcript: transcript)
            cleanupTempAudio()
            onComplete?(fallbackURL, nil)
        }
    }

    // MARK: - Save Helpers

    private func saveStructuredNote(
        content: String,
        title: String?,
        transcript: AssembledTranscript,
        tags: [String] = [],
        structuringStatus: String? = nil,
        meeting: MeetingEvent? = nil
    ) -> URL? {
        DailyNoteManager.appendSection(
            content: content,
            title: title,
            transcript: transcript,
            tags: tags,
            structuringStatus: structuringStatus,
            meeting: meeting ?? activeMeeting,
            recordingDate: recordingDate,
            speakerName: speakerName,
            saveLocation: saveLocation
        )
    }

    private func saveFallback(transcript: AssembledTranscript?) -> URL? {
        guard let transcript, !transcript.isEmpty else { return nil }

        return DailyNoteManager.appendFallbackSection(
            transcript: transcript,
            recordingDate: recordingDate,
            speakerName: speakerName,
            saveLocation: saveLocation,
            meeting: activeMeeting
        )
    }

    // MARK: - Cleanup

    private func cleanupTempAudio() {
        guard isTempAudio else { return }
        try? FileManager.default.removeItem(at: audioURL)
    }
}
