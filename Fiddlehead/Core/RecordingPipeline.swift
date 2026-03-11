import AVFoundation
import Foundation
import os.log
import ScreenCaptureKit

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "Pipeline")

/// Central orchestrator for the record → transcribe → structure → save pipeline.
/// Audio is always saved to a file during recording. When recording stops,
/// the audio file is sent to OpenAI's transcription API for diarized transcription,
/// then structured via OpenAI and saved as a markdown note.
@MainActor
final class RecordingPipeline: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var recordingDuration: TimeInterval = 0
    /// Incremented each time a note is saved, so views can refresh.
    @Published var savedNoteCount: Int = 0
    /// Background processing jobs — allows recording while previous notes are being processed.
    @Published var activeJobs: [ProcessingJob] = []
    /// Set by AppCoordinator when auto mode is active. Prevents manual recording.
    var autoModeActive = false

    let audioCaptureManager = AudioCaptureManager()

    private let calendarService = CalendarService()
    private var timer: Timer?
    private var settings: AppSettings?
    private var recordingStartDate: Date?
    private var actualChannelCount: Int = 1
    /// URL of the temp audio file when keepAudioEnabled is off
    private var tempAudioURL: URL?
    /// The meeting that triggered this recording, if any.
    private(set) var activeMeeting: MeetingEvent?
    private let silenceDetector = SilenceDetector()
    private var silenceMonitorTask: Task<Void, Never>?

    func configure(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Recording Control

    var isRecording: Bool { state.isRecording }
    var isProcessing: Bool { state.isProcessing }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording(for meeting: MeetingEvent? = nil) {
        guard !isRecording else { return }
        // Allow starting a new recording even if processing jobs are active.
        // Only block if already recording or if auto mode is handling things.
        guard !autoModeActive else {
            logger.info("Manual recording blocked — auto mode is active")
            return
        }
        guard let settings else { return }

        // Check microphone permission first
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard micStatus == .authorized else {
            if micStatus == .notDetermined {
                Task {
                    let granted = await AVCaptureDevice.requestAccess(for: .audio)
                    if granted { startRecording(for: meeting) }
                }
            } else {
                state = .error(message: "Microphone access denied — check System Settings > Privacy")
                resetAfterDelay()
            }
            return
        }

        settings.ensureSaveLocationExists()

        let now = Date()
        recordingStartDate = now
        tempAudioURL = nil
        activeMeeting = meeting

        // Always save audio to a file — either the user's chosen location or a temp file.
        // The batch transcription API needs a complete audio file after recording.
        let audioURL: URL
        if settings.keepAudioEnabled {
            audioURL = settings.saveLocation.appendingPathComponent(NoteStorage.audioFilename(for: now))
        } else {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("fiddlehead_\(UUID().uuidString).wav")
            tempAudioURL = tempURL
            audioURL = tempURL
        }

        // Prepare the audio stream (needed for AudioCaptureManager's internal routing + silence detection)
        let audioStream = audioCaptureManager.prepareStream()

        // Use stereo interleave when AssemblyAI multichannel is applicable
        let wantStereo = settings.systemAudioEnabled && settings.transcriptionProvider == .assemblyai

        do {
            try audioCaptureManager.startCapture(
                systemAudio: settings.systemAudioEnabled,
                stereo: wantStereo,
                saveAudioTo: audioURL,
                onReady: { [weak self] actualChannels in
                    guard let self else { return }
                    self.actualChannelCount = actualChannels
                    self.silenceDetector.channels = actualChannels
                    logger.info("Audio capture ready — actual channels: \(actualChannels)")
                }
            )
            state = .recording(startTime: now)
            recordingDuration = 0
            startTimer()
            startSilenceMonitor(stream: audioStream, settings: settings)

            logger.info("Recording started — requested system audio: \(settings.systemAudioEnabled), meeting: \(meeting?.title ?? "none")")
        } catch {
            state = .error(message: "Failed to start recording: \(error.localizedDescription)")
            logger.error("Recording failed: \(error)")
            cleanupTempAudio()
            resetAfterDelay()
        }
    }

    func stopRecording() {
        guard case .recording = state else { return }

        stopTimer()
        silenceMonitorTask?.cancel()
        silenceMonitorTask = nil
        audioCaptureManager.stopCapture()

        let duration = recordingDuration
        recordingDuration = 0

        if duration < 5 {
            state = .idle
            cleanupTempAudio()
            return
        }

        guard let settings else {
            state = .idle
            cleanupTempAudio()
            return
        }

        // Snapshot everything the job needs — then immediately go idle so a new recording can start.
        let audioURL = audioCaptureManager.savedAudioURL ?? tempAudioURL
        guard let audioURL else {
            state = .idle
            cleanupTempAudio()
            return
        }

        // Query all meetings that overlapped this recording for multi-meeting splitting
        let recordingStart = recordingStartDate ?? Date()
        let allMeetings = calendarService.meetingsDuring(from: recordingStart, to: Date())

        let job = ProcessingJob(
            audioURL: audioURL,
            openAIAPIKey: settings.openAIAPIKey,
            transcriptionProvider: settings.transcriptionProvider,
            assemblyAIAPIKey: settings.assemblyAIAPIKey,
            speakerName: settings.speakerName.isEmpty ? nil : settings.speakerName,
            saveLocation: settings.saveLocation,
            keepAudioEnabled: settings.keepAudioEnabled,
            recordingDate: recordingStart,
            activeMeeting: activeMeeting,
            isTempAudio: tempAudioURL != nil,
            channelCount: actualChannelCount,
            allMeetings: allMeetings
        )

        job.onComplete = { [weak self] noteURL, title in
            guard let self else { return }
            self.activeJobs.removeAll { $0.id == job.id }
            if noteURL != nil {
                self.savedNoteCount += 1
            }
            logger.info("Job finished — \(self.activeJobs.count) jobs remaining")
        }

        activeJobs.append(job)

        // Reset to idle immediately — the job runs in the background
        state = .idle
        tempAudioURL = nil
        activeMeeting = nil

        Task { await job.run() }
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Helpers

    /// Delete the temporary audio file if it exists (when keepAudioEnabled is off)
    private func cleanupTempAudio() {
        guard let url = tempAudioURL else { return }
        try? FileManager.default.removeItem(at: url)
        tempAudioURL = nil
    }

    private func startSilenceMonitor(stream: AsyncStream<Data>, settings: AppSettings) {
        let timeoutMinutes = settings.silenceTimeoutMinutes
        guard timeoutMinutes > 0 else { return }

        silenceDetector.reset()
        silenceDetector.silenceTimeoutSeconds = TimeInterval(timeoutMinutes * 60)
        silenceDetector.onSilenceTimeout = { [weak self] in
            guard let self, self.isRecording else { return }
            logger.info("Silence auto-stop triggered")
            self.stopRecording()
        }

        silenceMonitorTask = Task { [weak self] in
            for await chunk in stream {
                guard !Task.isCancelled else { break }
                self?.silenceDetector.processBuffer(chunk)
            }
        }
    }

    private func resetAfterDelay() {
        Task {
            try? await Task.sleep(for: .seconds(8))
            if case .error = state {
                state = .idle
            }
            activeMeeting = nil
        }
    }
}
