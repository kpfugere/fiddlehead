import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "AudioCompressor")

/// A chunk of audio with its time offset relative to the original recording.
struct AudioChunk {
    let url: URL
    let timeOffset: Double // seconds from start of original recording
}

/// Compresses WAV audio to AAC/M4A for upload to OpenAI's transcription API (25MB limit).
enum AudioCompressor {

    // MARK: - Compress WAV → M4A

    /// Compresses a WAV file to AAC M4A at speech-quality bitrate (64kbps mono).
    /// Uses macOS built-in `afconvert` for reliable encoding.
    /// Returns the URL of the compressed M4A file (placed alongside the original).
    static func compress(wavURL: URL, channels: Int = 1) async throws -> URL {
        let outputURL = wavURL.deletingPathExtension().appendingPathExtension("m4a")

        let inputSize = try FileManager.default.attributesOfItem(atPath: wavURL.path)[.size] as? Int ?? 0
        logger.warning("Compressing \(wavURL.lastPathComponent) (\(inputSize) bytes) → M4A...")

        // Use macOS built-in afconvert for reliable WAV → AAC encoding.
        // AVAudioFile cannot encode to AAC directly (CoreAudio error 560226676).
        // Note: We omit -b (bitrate) because the default is optimal for the source sample rate.
        // Specifying 64kbps on a 16kHz source causes 'Couldn't set audio converter property'.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = [
            "-f", "m4af",       // M4A container format
            "-d", "aac",        // AAC codec
            "-c", "\(channels)", // channel count (1=mono, 2=stereo)
            wavURL.path,
            outputURL.path
        ]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "unknown error"
            logger.error("afconvert failed (exit \(process.terminationStatus)): \(errorMsg, privacy: .public)")
            throw AudioCompressorError.compressionFailed("afconvert failed: \(errorMsg)")
        }

        let outputSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int ?? 0
        let ratio = inputSize > 0 ? Double(outputSize) / Double(inputSize) * 100 : 0

        logger.warning("Compressed \(inputSize) → \(outputSize) bytes (\(String(format: "%.1f", ratio))%)")

        return outputURL
    }

    // MARK: - Split If Needed

    /// If the file exceeds `maxBytes` or `maxDuration`, splits it into multiple M4A chunks.
    /// Each chunk overlaps by 2 seconds to avoid cutting mid-sentence.
    /// Returns a single-element array if the file is small enough and short enough.
    ///
    /// When splitting is needed and `originalWAVURL` is provided, chunks are cut from the
    /// original WAV (which preserves full audio amplitude) rather than decoding from the M4A.
    /// This avoids the M4A→PCM→WAV→M4A round-trip that produces corrupt near-empty files
    /// due to lossy codec amplitude reduction.
    static func splitIfNeeded(
        fileURL: URL,
        maxBytes: Int = 25_000_000,
        maxDuration: Double? = nil,
        originalWAVURL: URL? = nil
    ) async throws -> [AudioChunk] {
        let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int ?? 0

        // Check both file size and duration constraints
        let needsSplitForSize = fileSize > maxBytes
        var needsSplitForDuration = false
        var probedDuration: Double?

        if let maxDur = maxDuration {
            let probeFile = try AVAudioFile(forReading: fileURL)
            let dur = Double(probeFile.length) / probeFile.processingFormat.sampleRate
            probedDuration = dur
            needsSplitForDuration = dur > maxDur
        }

        if !needsSplitForSize && !needsSplitForDuration {
            logger.warning("File \(fileSize) bytes, \(String(format: "%.0f", probedDuration ?? 0))s — no split needed")
            return [AudioChunk(url: fileURL, timeOffset: 0)]
        }

        logger.warning("File \(fileSize) bytes, \(String(format: "%.0f", probedDuration ?? 0))s — splitting (size: \(needsSplitForSize), duration: \(needsSplitForDuration))")

        // Use the original WAV for splitting when available — reading PCM from M4A and
        // re-compressing produces corrupt near-empty M4A files due to lossy amplitude loss.
        let sourceURL = originalWAVURL ?? fileURL
        let inputFile = try AVAudioFile(forReading: sourceURL)
        let format = inputFile.processingFormat
        let totalFrames = AVAudioFrameCount(inputFile.length)
        let totalDuration = Double(totalFrames) / format.sampleRate

        logger.warning("Splitting from \(sourceURL.lastPathComponent) (\(totalFrames) frames, \(String(format: "%.0f", totalDuration))s)")

        // Calculate how many chunks we need — use whichever constraint requires more
        let chunksBySize = needsSplitForSize ? Int(ceil(Double(fileSize) / Double(maxBytes))) : 1
        let chunksByDuration: Int
        if let maxDur = maxDuration, needsSplitForDuration {
            chunksByDuration = Int(ceil(totalDuration / maxDur))
        } else {
            chunksByDuration = 1
        }
        let chunkCount = max(chunksBySize, chunksByDuration)
        let chunkDuration = totalDuration / Double(chunkCount)
        let overlapSeconds: Double = 2.0
        let overlapFrames = AVAudioFrameCount(overlapSeconds * format.sampleRate)

        logger.warning("Splitting into \(chunkCount) chunks of ~\(String(format: "%.0f", chunkDuration))s each (2s overlap)")

        // WAV output settings — PCM writing works reliably with AVAudioFile
        let wavSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: Int(format.channelCount),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        // Float format for reading
        guard let floatFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: format.sampleRate,
            channels: format.channelCount,
            interleaved: false
        ) else {
            throw AudioCompressorError.splitFailed("Could not create float PCM format")
        }

        var chunks: [AudioChunk] = []
        let readChunkSize: AVAudioFrameCount = 16384

        for i in 0..<chunkCount {
            let startFrame = AVAudioFrameCount(Double(i) * chunkDuration * format.sampleRate)
            let endFrame: AVAudioFrameCount
            if i == chunkCount - 1 {
                endFrame = totalFrames
            } else {
                // Extend by overlap so the next chunk's start overlaps with this chunk's end
                endFrame = min(
                    AVAudioFrameCount(Double(i + 1) * chunkDuration * format.sampleRate) + overlapFrames,
                    totalFrames
                )
            }

            let chunkFrames = endFrame - startFrame
            let timeOffset = Double(startFrame) / format.sampleRate

            // Write as WAV first (PCM — AVAudioFile handles this correctly)
            let wavChunkURL = fileURL.deletingPathExtension()
                .appendingPathExtension("chunk\(i)")
                .appendingPathExtension("wav")

            // IMPORTANT: AVAudioFile only finalizes the WAV header (writes correct
            // data size) on deallocation. Without autoreleasepool, Swift's ARC may
            // not deallocate the file before afconvert reads it, producing a WAV with
            // 0 audio bytes → 572-byte corrupt M4A. autoreleasepool forces dealloc.
            try autoreleasepool {
                let outputFile = try AVAudioFile(
                    forWriting: wavChunkURL,
                    settings: wavSettings,
                    commonFormat: .pcmFormatFloat32,
                    interleaved: false
                )

                // Seek to start position
                inputFile.framePosition = AVAudioFramePosition(startFrame)

                guard let readBuffer = AVAudioPCMBuffer(pcmFormat: floatFormat, frameCapacity: readChunkSize) else {
                    throw AudioCompressorError.splitFailed("Failed to create buffer for chunk \(i)")
                }

                var framesRemaining = chunkFrames
                while framesRemaining > 0 {
                    let toRead = min(readChunkSize, framesRemaining)
                    readBuffer.frameLength = 0
                    try inputFile.read(into: readBuffer, frameCount: toRead)
                    try outputFile.write(from: readBuffer)
                    framesRemaining -= readBuffer.frameLength
                }
            }

            logger.warning("Split chunk \(i): \(chunkFrames) frames, offset \(String(format: "%.1f", timeOffset))s → \(wavChunkURL.lastPathComponent)")

            // Compress WAV chunk → M4A
            let m4aURL = try await compress(wavURL: wavChunkURL, channels: Int(format.channelCount))

            // Clean up the intermediate WAV chunk immediately
            try? FileManager.default.removeItem(at: wavChunkURL)

            chunks.append(AudioChunk(url: m4aURL, timeOffset: timeOffset))
        }

        return chunks
    }

    // MARK: - Cleanup

    /// Deletes temporary compressed/split files.
    static func cleanup(tempFiles: [URL]) {
        let fm = FileManager.default
        for url in tempFiles {
            do {
                try fm.removeItem(at: url)
                logger.debug("Cleaned up temp file: \(url.lastPathComponent)")
            } catch {
                logger.warning("Failed to clean up \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Errors

enum AudioCompressorError: Error, LocalizedError {
    case compressionFailed(String)
    case splitFailed(String)

    var errorDescription: String? {
        switch self {
        case .compressionFailed(let reason):
            "Audio compression failed: \(reason)"
        case .splitFailed(let reason):
            "Audio split failed: \(reason)"
        }
    }
}
