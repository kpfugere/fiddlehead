import ScreenCaptureKit
import AVFoundation
import CoreMedia
import CoreGraphics

/// Captures system audio using ScreenCaptureKit.
/// Outputs 16kHz, 16-bit signed integer (linear16), mono PCM data.
final class SystemAudioCapture: NSObject, @unchecked Sendable {

    /// Check if screen recording permission is granted (required for system audio).
    static var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Request screen recording permission. Returns true if already granted.
    /// If not granted, macOS will show a prompt or the user must go to System Settings.
    @discardableResult
    static func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }
    private var stream: SCStream?
    private var isCapturing = false
    private let audioQueue = DispatchQueue(label: "com.fiddlehead.systemaudio", qos: .userInteractive)

    private var audioContinuation: AsyncStream<Data>.Continuation?
    private var _audioStream: AsyncStream<Data>?

    /// Stream of PCM audio data chunks (16kHz, mono, Int16).
    /// Must call `prepareStream()` before `start()` to avoid race conditions.
    var audioStream: AsyncStream<Data> {
        if let existing = _audioStream { return existing }
        return prepareStream()
    }

    /// Eagerly create and cache the stream + continuation.
    /// Call this BEFORE `start()` so the consumer is ready when data arrives.
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

    func start() async throws {
        guard !isCapturing else { return }

        // Get available content
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: false
        )

        guard let display = content.displays.first else {
            throw AudioCaptureError.captureNotSupported
        }

        // Filter: capture from the entire display
        let filter = SCContentFilter(display: display,
                                      excludingApplications: [],
                                      exceptingWindows: [])

        // Configure for audio only
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 16000
        config.channelCount = 1
        config.excludesCurrentProcessAudio = true

        // Minimal video settings (we don't need video)
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 fps minimum
        config.showsCursor = false

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)

        try await stream.startCapture()
        self.stream = stream
        isCapturing = true
    }

    func stop() async {
        guard isCapturing, let stream else { return }
        try? await stream.stopCapture()
        self.stream = nil
        isCapturing = false
        audioContinuation?.finish()
        audioContinuation = nil
        _audioStream = nil
    }
}

// MARK: - SCStreamDelegate

extension SystemAudioCapture: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        isCapturing = false
        audioContinuation?.finish()
        audioContinuation = nil
        _audioStream = nil
    }
}

// MARK: - SCStreamOutput

extension SystemAudioCapture: SCStreamOutput {
    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard sampleBuffer.isValid, sampleBuffer.numSamples > 0 else { return }

        // Extract audio data from CMSampleBuffer
        if let data = extractLinear16Data(from: sampleBuffer) {
            audioContinuation?.yield(data)
        }
    }

    private func extractLinear16Data(from sampleBuffer: CMSampleBuffer) -> Data? {
        guard let blockBuffer = sampleBuffer.dataBuffer else { return nil }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )

        guard status == kCMBlockBufferNoErr, let dataPointer, length > 0 else {
            return nil
        }

        // Check the audio format — ScreenCaptureKit may output Float32
        if let formatDescription = sampleBuffer.formatDescription {
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
            if let asbd, asbd.pointee.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
                // Convert Float32 to Int16
                return convertFloat32ToInt16(pointer: dataPointer, byteCount: length)
            }
        }

        // Already Int16 (or treat as such)
        return Data(bytes: dataPointer, count: length)
    }

    private func convertFloat32ToInt16(pointer: UnsafeMutablePointer<Int8>, byteCount: Int) -> Data {
        let floatCount = byteCount / MemoryLayout<Float32>.size
        let floatPointer = pointer.withMemoryRebound(to: Float32.self, capacity: floatCount) { $0 }

        var int16Data = Data(count: floatCount * MemoryLayout<Int16>.size)
        int16Data.withUnsafeMutableBytes { rawBuffer in
            guard let int16Pointer = rawBuffer.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
            for i in 0..<floatCount {
                let clamped = max(-1.0, min(1.0, floatPointer[i]))
                int16Pointer[i] = Int16(clamped * Float32(Int16.max))
            }
        }
        return int16Data
    }
}
