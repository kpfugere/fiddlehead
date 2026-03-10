import Foundation
import os.log
import ScreenCaptureKit

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "AudioCapture")

/// Manages audio capture from microphone and system audio.
/// When stereo mode is off (default), mic and system are summed into mono for voice-based diarization.
/// When stereo mode is on, outputs interleaved stereo (mic=left, system=right) for channel-based identification.
@MainActor
final class AudioCaptureManager: ObservableObject {
    private let micCapture = MicrophoneCapture()
    private let systemCapture = SystemAudioCapture()
    private let mixer = AudioMixer()

    private var audioFileWriter: AudioFileWriter?
    private var micStreamTask: Task<Void, Never>?
    private var sysStreamTask: Task<Void, Never>?
    private var outputStreamTask: Task<Void, Never>?

    @Published var isCapturing = false
    /// True when system audio is actively being mixed in (not just requested).
    @Published var systemAudioActive = false

    private var externalContinuation: AsyncStream<Data>.Continuation?
    private var _audioStream: AsyncStream<Data>?
    private var captureSystemAudio = false
    private var pendingSaveURL: URL?
    private var _savedAudioURL: URL?

    // Diagnostic counters for stream health
    private var micChunksReceived = 0
    private var sysChunksReceived = 0
    private var mixedChunksOutput = 0

    /// Number of channels in the saved audio file (1=mono, 2=stereo interleaved).
    private(set) var channelCount: Int = 1

    /// Stream of audio data. Must be accessed *after* calling prepareStream()
    /// and *before* calling startCapture().
    var audioStream: AsyncStream<Data> {
        if let existing = _audioStream {
            return existing
        }
        let stream = AsyncStream<Data> { continuation in
            self.externalContinuation = continuation
        }
        _audioStream = stream
        return stream
    }

    /// Prepare the output stream before starting capture.
    /// This ensures the continuation is ready before any audio arrives.
    func prepareStream() -> AsyncStream<Data> {
        // Tear down any leftover stream
        _audioStream = nil
        externalContinuation = nil

        let stream = AsyncStream<Data> { continuation in
            self.externalContinuation = continuation
        }
        _audioStream = stream
        logger.info("Audio stream prepared")
        return stream
    }

    /// Start capturing audio.
    /// The completion handler is called once the actual capture mode is determined
    /// (system audio may fail and fall back to mic-only, changing the channel count).
    func startCapture(
        systemAudio: Bool,
        stereo: Bool = false,
        saveAudioTo url: URL? = nil,
        onReady: ((Int) -> Void)? = nil
    ) throws {
        guard !isCapturing else { return }
        captureSystemAudio = systemAudio
        pendingSaveURL = url
        _savedAudioURL = nil
        systemAudioActive = false
        channelCount = 1
        micChunksReceived = 0
        sysChunksReceived = 0
        mixedChunksOutput = 0

        // Prepare mic stream before starting
        micCapture.prepareStream()

        // Start mic
        try micCapture.start()
        isCapturing = true

        if systemAudio {
            // Check permission before attempting system audio capture
            if !SystemAudioCapture.hasPermission {
                logger.warning("Screen Recording permission not granted — system audio unavailable")
                captureSystemAudio = false
                setupFileWriter(url: url, channels: 1)
                startMicOnlyCapture()
                onReady?(1)
                return
            }
            startDualCapture(saveURL: url, stereo: stereo, onReady: onReady)
        } else {
            setupFileWriter(url: url, channels: 1)
            logger.info("Capture started — mic only, 1 channel")
            startMicOnlyCapture()
            onReady?(1)
        }
    }

    /// Stop all capture
    func stopCapture() {
        // Log stream health diagnostics
        if captureSystemAudio {
            logger.info("Stream diagnostics — mic chunks: \(self.micChunksReceived), system chunks: \(self.sysChunksReceived), mixed output: \(self.mixedChunksOutput)")
            if sysChunksReceived == 0 {
                logger.warning("System audio produced ZERO chunks — system audio was not captured")
            }
        } else {
            logger.info("Stream diagnostics — mic chunks: \(self.micChunksReceived) (mic-only mode)")
        }

        micCapture.stop()
        micStreamTask?.cancel()
        sysStreamTask?.cancel()
        outputStreamTask?.cancel()
        micStreamTask = nil
        sysStreamTask = nil
        outputStreamTask = nil

        if captureSystemAudio {
            mixer.flush()
            Task {
                await systemCapture.stop()
            }
        }

        // Capture the audio file URL BEFORE nilling the writer
        _savedAudioURL = audioFileWriter?.fileURL
        audioFileWriter?.finish()
        audioFileWriter = nil
        externalContinuation?.finish()
        externalContinuation = nil
        _audioStream = nil
        isCapturing = false
        systemAudioActive = false
        logger.info("Capture stopped — audio saved to: \(self._savedAudioURL?.lastPathComponent ?? "none")")
    }

    /// URL of the saved audio file. Valid after stopCapture() is called.
    var savedAudioURL: URL? {
        // Return cached URL if writer has been stopped, otherwise query live writer
        _savedAudioURL ?? audioFileWriter?.fileURL
    }

    // MARK: - Private

    private func startMicOnlyCapture() {
        micStreamTask = Task { [weak self] in
            guard let self else { return }
            for await chunk in self.micCapture.audioStream {
                try? self.audioFileWriter?.write(data: chunk)
                self.externalContinuation?.yield(chunk)
            }
        }
    }

    private func setupFileWriter(url: URL?, channels: Int) {
        guard let url else { return }
        let writer = AudioFileWriter(
            outputURL: url,
            sampleRate: 16000,
            channels: UInt32(channels)
        )
        do {
            try writer.start()
            audioFileWriter = writer
        } catch {
            logger.error("Failed to create audio file writer: \(error)")
        }
    }

    private func startDualCapture(saveURL: URL?, stereo: Bool, onReady: ((Int) -> Void)?) {
        // Prepare streams BEFORE starting capture (avoids race condition)
        systemCapture.prepareStream()
        mixer.prepareStream()
        mixer.stereo = stereo

        logger.info("Starting dual capture — requesting system audio via ScreenCaptureKit")

        // Start system audio capture
        Task {
            do {
                try await systemCapture.start()
                logger.info("System audio capture started successfully")
            } catch {
                logger.error("System audio failed, falling back to mic only: \(error.localizedDescription, privacy: .public)")
                captureSystemAudio = false
                systemAudioActive = false
                mixer.stereo = false
                channelCount = 1
                setupFileWriter(url: saveURL, channels: 1)
                logger.info("Capture started — mic only (fallback), 1 channel")
                startMicOnlyCapture()
                onReady?(1)
                return
            }

            systemAudioActive = true
            let channels = stereo ? 2 : 1
            channelCount = channels
            setupFileWriter(url: saveURL, channels: channels)
            logger.info("Capture started — dual capture, \(stereo ? "stereo interleaved" : "mono mixdown"), \(channels) channel(s)")
            onReady?(channels)

            // Feed mic audio into mixer
            micStreamTask = Task { [weak self] in
                guard let self else { return }
                for await chunk in self.micCapture.audioStream {
                    self.micChunksReceived += 1
                    if self.micChunksReceived == 1 {
                        logger.info("First mic chunk received in mixer path — \(chunk.count) bytes")
                    }
                    self.mixer.addMicAudio(chunk)
                }
                logger.info("Mic stream ended")
            }

            // Feed system audio into mixer
            sysStreamTask = Task { [weak self] in
                guard let self else { return }
                for await chunk in self.systemCapture.audioStream {
                    self.sysChunksReceived += 1
                    if self.sysChunksReceived == 1 {
                        logger.info("First system audio chunk received — \(chunk.count) bytes")
                    }
                    self.mixer.addSystemAudio(chunk)
                }
                logger.info("System audio stream ended")
            }

            // Read mixed output and forward
            outputStreamTask = Task { [weak self] in
                guard let self else { return }
                for await chunk in self.mixer.outputStream {
                    self.mixedChunksOutput += 1
                    try? self.audioFileWriter?.write(data: chunk)
                    self.externalContinuation?.yield(chunk)
                }
                logger.info("Mixed output stream ended")
            }
        }
    }
}
