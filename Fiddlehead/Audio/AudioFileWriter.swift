import AVFoundation

/// Writes PCM audio data to an .m4a file (AAC encoding) or .wav fallback.
final class AudioFileWriter: @unchecked Sendable {
    private var audioFile: AVAudioFile?
    private let outputURL: URL
    private let sampleRate: Double
    private let channels: AVAudioChannelCount

    init(outputURL: URL, sampleRate: Double = 16000, channels: AVAudioChannelCount = 1) {
        self.outputURL = outputURL
        self.sampleRate = sampleRate
        self.channels = channels
    }

    /// Start writing — creates the output file
    func start() throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: true
        ) else {
            throw AudioFileWriterError.invalidFormat
        }

        // Write as WAV for reliability (AAC requires more setup)
        let wavURL = outputURL.deletingPathExtension().appendingPathExtension("wav")
        audioFile = try AVAudioFile(
            forWriting: wavURL,
            settings: format.settings,
            commonFormat: .pcmFormatInt16,
            interleaved: true
        )
    }

    /// Write a chunk of Int16 PCM data
    func write(data: Data) throws {
        guard let audioFile else { return }

        let frameCount = UInt32(data.count / (MemoryLayout<Int16>.size * Int(channels)))
        guard frameCount > 0 else { return }

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: true
        ) else { return }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        data.withUnsafeBytes { rawBuffer in
            guard let src = rawBuffer.baseAddress else { return }
            if let dest = buffer.int16ChannelData?[0] {
                memcpy(dest, src, data.count)
            }
        }

        try audioFile.write(from: buffer)
    }

    /// Finish writing and close the file
    func finish() {
        audioFile = nil
    }

    var fileURL: URL {
        outputURL.deletingPathExtension().appendingPathExtension("wav")
    }
}

enum AudioFileWriterError: Error, LocalizedError {
    case invalidFormat
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .invalidFormat: "Invalid audio format"
        case .writeFailed: "Failed to write audio data"
        }
    }
}
