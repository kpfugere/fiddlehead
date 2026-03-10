import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "MicCapture")

/// Captures microphone audio using AVAudioEngine.
/// Outputs 16kHz, 16-bit signed integer (linear16), mono PCM data.
final class MicrophoneCapture: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var isCapturing = false

    /// Target format: 16kHz, mono, Int16
    private let targetSampleRate: Double = 16000
    private let targetChannels: AVAudioChannelCount = 1

    private var audioContinuation: AsyncStream<Data>.Continuation?
    private var _audioStream: AsyncStream<Data>?
    private var chunkCount = 0

    /// Cached converter — created once when the tap is installed, reused per buffer
    private var cachedConverter: AVAudioConverter?
    private var cachedTargetFormat: AVAudioFormat?

    /// Stream of PCM audio data chunks (16kHz, mono, Int16).
    /// Must call prepareStream() first to ensure continuation is ready.
    var audioStream: AsyncStream<Data> {
        if let existing = _audioStream { return existing }
        return prepareStream()
    }

    /// Prepare the stream before starting capture.
    /// Returns the stream that will receive audio data.
    @discardableResult
    func prepareStream() -> AsyncStream<Data> {
        _audioStream = nil
        audioContinuation = nil
        let stream = AsyncStream<Data> { continuation in
            self.audioContinuation = continuation
        }
        _audioStream = stream
        return stream
    }

    func start() throws {
        guard !isCapturing else { return }

        // Ensure continuation is ready before installing tap
        if audioContinuation == nil {
            prepareStream()
        }

        chunkCount = 0
        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        logger.info("Mic hardware format: \(hardwareFormat.sampleRate)Hz, \(hardwareFormat.channelCount)ch")

        guard hardwareFormat.sampleRate > 0 else {
            logger.error("No input device — sampleRate is 0")
            throw AudioCaptureError.noInputDevice
        }

        // Create converter once, reuse for every buffer
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: true
        )!
        cachedTargetFormat = targetFormat

        let needsConversion = hardwareFormat.sampleRate != targetSampleRate
            || hardwareFormat.channelCount != targetChannels
            || hardwareFormat.commonFormat != .pcmFormatInt16

        if needsConversion {
            cachedConverter = AVAudioConverter(from: hardwareFormat, to: targetFormat)
            if cachedConverter == nil {
                logger.error("Failed to create audio converter")
            }
        } else {
            cachedConverter = nil // Direct extraction, no conversion needed
        }

        // Install tap at hardware format, then convert in the callback
        let bufferSize: AVAudioFrameCount = 4096

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: hardwareFormat) { [weak self] buffer, _ in
            guard let self else { return }
            if let converted = self.convertToLinear16(buffer: buffer) {
                self.audioContinuation?.yield(converted)
                self.chunkCount += 1
                if self.chunkCount == 1 {
                    logger.info("First mic chunk: \(converted.count) bytes")
                }
            }
        }

        engine.prepare()
        try engine.start()
        isCapturing = true
        logger.info("Mic capture started")
    }

    func stop() {
        guard isCapturing else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isCapturing = false
        cachedConverter = nil
        cachedTargetFormat = nil
        logger.info("Mic capture stopped — \(self.chunkCount) chunks produced")
        audioContinuation?.finish()
        audioContinuation = nil
        _audioStream = nil
    }

    /// Convert an AVAudioPCMBuffer to 16kHz mono Int16 data using cached converter
    private func convertToLinear16(buffer: AVAudioPCMBuffer) -> Data? {
        guard let targetFormat = cachedTargetFormat else { return nil }

        // No converter means formats already match — extract directly
        guard let converter = cachedConverter else {
            return extractData(from: buffer)
        }

        let ratio = targetSampleRate / buffer.format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCount
        ) else { return nil }

        var error: NSError?
        var consumed = false

        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        if error != nil { return nil }
        return extractData(from: outputBuffer)
    }

    private func extractData(from buffer: AVAudioPCMBuffer) -> Data? {
        guard buffer.frameLength > 0 else { return nil }
        let byteCount = Int(buffer.frameLength) * MemoryLayout<Int16>.size * Int(buffer.format.channelCount)
        guard let channelData = buffer.int16ChannelData else { return nil }
        return Data(bytes: channelData[0], count: byteCount)
    }
}

enum AudioCaptureError: Error, LocalizedError {
    case noInputDevice
    case captureNotSupported
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noInputDevice: "No microphone found"
        case .captureNotSupported: "Audio capture is not supported"
        case .permissionDenied: "Microphone permission was denied"
        }
    }
}
