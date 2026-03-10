import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "AudioPreprocessor")

/// Result of audio preprocessing, containing the processed file URL and original duration.
struct PreprocessedAudio: Sendable {
    let url: URL
    let originalDuration: Double
}

/// Preprocesses audio to reduce transcription cost by stripping silence before upload.
enum AudioPreprocessor {

    /// RMS threshold below which a chunk is considered silent.
    /// Float32 equivalent of Int16 RMS threshold 100 (from SilenceDetector): 100/32768 ≈ 0.00305
    private static let silenceThreshold: Float = 0.00305

    /// Analysis chunk size in frames. At 16kHz, 512 frames = 32ms per chunk.
    private static let analysisFrameCount: AVAudioFrameCount = 512

    /// Padding in seconds added before and after each speech region.
    private static let paddingSeconds: Double = 0.200

    /// Minimum silence gap (seconds) between speech regions before they're merged.
    /// Gaps shorter than this are kept as-is to avoid cutting mid-sentence pauses.
    private static let minSilenceGap: Double = 0.300

    /// Minimum silence percentage to justify rewriting the file.
    private static let minSilencePercent: Double = 10

    // MARK: - Public API

    /// Removes silent regions from a WAV file, returning a trimmed WAV and the original duration.
    /// If the file has less than 10% silence, returns the original file unchanged.
    static func removeSilence(wavURL: URL) throws -> PreprocessedAudio {
        let inputFile = try AVAudioFile(forReading: wavURL)
        let totalFrames = AVAudioFrameCount(inputFile.length)
        let sampleRate = inputFile.processingFormat.sampleRate
        let originalDuration = Double(totalFrames) / sampleRate

        logger.info("Analyzing \(wavURL.lastPathComponent) for silence (\(String(format: "%.0f", originalDuration))s, \(Int(sampleRate))Hz)")

        let speechRegions = try findSpeechRegions(
            file: inputFile,
            totalFrames: totalFrames,
            sampleRate: sampleRate
        )

        let keptDuration = speechRegions.reduce(0.0) { $0 + ($1.end - $1.start) }
        let removedPercent = originalDuration > 0 ? (1.0 - keptDuration / originalDuration) * 100 : 0

        logger.info("Speech: \(speechRegions.count) regions, \(String(format: "%.0f", keptDuration))s kept, \(String(format: "%.0f", removedPercent))% silence")

        if removedPercent < minSilencePercent {
            logger.info("Below \(Int(minSilencePercent))% silence threshold — skipping trim")
            return PreprocessedAudio(url: wavURL, originalDuration: originalDuration)
        }

        let outputURL = wavURL.deletingPathExtension()
            .appendingPathExtension("trimmed")
            .appendingPathExtension("wav")

        try writeSpeechRegions(
            sourceURL: wavURL,
            outputURL: outputURL,
            regions: speechRegions,
            format: inputFile.processingFormat,
            sampleRate: sampleRate
        )

        let outputSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int) ?? 0
        logger.info("Trimmed: \(outputURL.lastPathComponent) (\(outputSize) bytes, \(String(format: "%.0f", keptDuration))s)")

        return PreprocessedAudio(url: outputURL, originalDuration: originalDuration)
    }

    /// Removes a preprocessed temp file if it differs from the original.
    static func cleanupIfNeeded(preprocessed: PreprocessedAudio, originalURL: URL) {
        guard preprocessed.url != originalURL else { return }
        try? FileManager.default.removeItem(at: preprocessed.url)
    }

    // MARK: - Speech Region Detection

    private struct TimeRange {
        var start: Double
        var end: Double
    }

    private static func findSpeechRegions(
        file: AVAudioFile,
        totalFrames: AVAudioFrameCount,
        sampleRate: Double
    ) throws -> [TimeRange] {
        let format = file.processingFormat

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: analysisFrameCount) else {
            throw AudioPreprocessorError.analysisFailed("Could not create analysis buffer")
        }

        file.framePosition = 0
        var speechChunks: [TimeRange] = []
        var framesRead: AVAudioFrameCount = 0

        while framesRead < totalFrames {
            let toRead = min(analysisFrameCount, totalFrames - framesRead)
            buffer.frameLength = 0
            try file.read(into: buffer, frameCount: toRead)

            if calculateRMS(buffer: buffer) >= silenceThreshold {
                let startTime = Double(framesRead) / sampleRate
                let endTime = Double(framesRead + buffer.frameLength) / sampleRate
                speechChunks.append(TimeRange(start: startTime, end: endTime))
            }

            framesRead += buffer.frameLength
        }

        guard !speechChunks.isEmpty else {
            logger.warning("No speech detected — returning full audio unchanged")
            return [TimeRange(start: 0, end: Double(totalFrames) / sampleRate)]
        }

        // Merge chunks separated by less than minSilenceGap
        var merged: [TimeRange] = [speechChunks[0]]
        for i in 1..<speechChunks.count {
            let gap = speechChunks[i].start - merged[merged.count - 1].end
            if gap < minSilenceGap {
                merged[merged.count - 1].end = speechChunks[i].end
            } else {
                merged.append(speechChunks[i])
            }
        }

        // Add padding and clamp to file bounds
        let totalDuration = Double(totalFrames) / sampleRate
        for i in 0..<merged.count {
            merged[i].start = max(0, merged[i].start - paddingSeconds)
            merged[i].end = min(totalDuration, merged[i].end + paddingSeconds)
        }

        // Merge any regions that now overlap after padding
        var padded: [TimeRange] = [merged[0]]
        for i in 1..<merged.count {
            if merged[i].start <= padded[padded.count - 1].end {
                padded[padded.count - 1].end = merged[i].end
            } else {
                padded.append(merged[i])
            }
        }

        return padded
    }

    /// Max RMS across all channels of a Float32 PCM buffer.
    /// For stereo, speech on either channel prevents the chunk from being trimmed.
    private static func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }

        let channelCount = Int(buffer.format.channelCount)
        var maxRMS: Float = 0
        for ch in 0..<channelCount {
            let samples = channelData[ch]
            var sumOfSquares: Float = 0
            for i in 0..<count {
                let s = samples[i]
                sumOfSquares += s * s
            }
            let rms = (sumOfSquares / Float(count)).squareRoot()
            maxRMS = max(maxRMS, rms)
        }
        return maxRMS
    }

    // MARK: - Write Speech Regions

    private static func writeSpeechRegions(
        sourceURL: URL,
        outputURL: URL,
        regions: [TimeRange],
        format: AVAudioFormat,
        sampleRate: Double
    ) throws {
        let readChunkSize: AVAudioFrameCount = 16384

        let wavSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: Int(format.channelCount),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        // autoreleasepool forces AVAudioFile dealloc → finalizes WAV header
        // before any downstream reader (afconvert) touches the file.
        try autoreleasepool {
            let inputFile = try AVAudioFile(forReading: sourceURL)
            let outputFile = try AVAudioFile(
                forWriting: outputURL,
                settings: wavSettings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )

            guard let readBuffer = AVAudioPCMBuffer(
                pcmFormat: inputFile.processingFormat,
                frameCapacity: readChunkSize
            ) else {
                throw AudioPreprocessorError.writeFailed("Could not create read buffer")
            }

            for region in regions {
                let startFrame = AVAudioFramePosition(region.start * sampleRate)
                let endFrame = AVAudioFramePosition(region.end * sampleRate)
                let totalRegionFrames = AVAudioFrameCount(endFrame - startFrame)

                inputFile.framePosition = startFrame
                var framesRemaining = totalRegionFrames

                while framesRemaining > 0 {
                    let toRead = min(readChunkSize, framesRemaining)
                    readBuffer.frameLength = 0
                    try inputFile.read(into: readBuffer, frameCount: toRead)
                    try outputFile.write(from: readBuffer)
                    framesRemaining -= readBuffer.frameLength
                }
            }
        }
    }
}

// MARK: - Errors

enum AudioPreprocessorError: Error, LocalizedError {
    case analysisFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .analysisFailed(let reason):
            "Audio analysis failed: \(reason)"
        case .writeFailed(let reason):
            "Audio write failed: \(reason)"
        }
    }
}
