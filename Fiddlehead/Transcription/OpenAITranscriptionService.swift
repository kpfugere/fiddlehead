import Foundation
import os.log

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "OpenAITranscription")

/// Transcribes a saved audio file using OpenAI's gpt-4o-transcribe-diarize model.
/// Compresses WAV → AAC/M4A before upload. Splits into chunks if still > 25MB.
final class OpenAITranscriptionService: TranscriptionService, Sendable {
    private let apiKey: String
    private let maxRetries: Int
    private static let maxFileSize = 25 * 1_000_000 // 25 MB

    init(apiKey: String, maxRetries: Int = 3) {
        self.apiKey = apiKey
        self.maxRetries = maxRetries
    }

    func transcribe(fileURL: URL, channels: Int) async throws -> AssembledTranscript {
        // Step 0: Strip silence to reduce upload duration (and per-minute billing)
        let preprocessed = try AudioPreprocessor.removeSilence(wavURL: fileURL)
        let activeWAV = preprocessed.url

        // Step 1: Compress WAV → M4A (AAC 64kbps)
        logger.info("Compressing WAV before OpenAI upload...")
        let m4aURL = try await AudioCompressor.compress(wavURL: activeWAV)

        // Track temp files for cleanup
        var tempFiles: [URL] = [m4aURL]
        if activeWAV != fileURL { tempFiles.append(activeWAV) }
        defer { AudioCompressor.cleanup(tempFiles: tempFiles) }

        // Step 2: Split if compressed file exceeds 25MB or 600s (10 min) per chunk.
        // OpenAI processes at ~21s per minute of audio, so 10-min chunks take ~200s
        // (well under the 300s request timeout). Pass trimmed WAV for full-quality splits.
        let chunks = try await AudioCompressor.splitIfNeeded(
            fileURL: m4aURL,
            maxBytes: Self.maxFileSize,
            maxDuration: 600,
            originalWAVURL: activeWAV
        )

        // Add chunk files to cleanup list (but not the main m4a if it's the same as the single chunk)
        for chunk in chunks where chunk.url != m4aURL {
            tempFiles.append(chunk.url)
        }

        // Step 3: Transcribe each chunk
        var transcript: AssembledTranscript
        if chunks.count == 1 {
            transcript = try await transcribeSingleFile(fileURL: chunks[0].url)
        } else {
            logger.info("Transcribing \(chunks.count) chunks...")
            transcript = try await transcribeChunks(chunks)
        }

        // Use original recording duration for frontmatter (not trimmed duration)
        return AssembledTranscript(
            segments: transcript.segments,
            duration: preprocessed.originalDuration
        )
    }

    // MARK: - Single File Upload

    private func transcribeSingleFile(fileURL: URL) async throws -> AssembledTranscript {
        let audioData = try Data(contentsOf: fileURL)

        logger.warning("Sending \(audioData.count) bytes to OpenAI transcription API")

        let boundary = UUID().uuidString
        var body = Data()

        // file field — M4A content type
        body.appendMultipart(boundary: boundary, name: "file",
                             filename: fileURL.lastPathComponent,
                             contentType: "audio/mp4", data: audioData)
        // model
        body.appendMultipart(boundary: boundary, name: "model", value: "gpt-4o-transcribe-diarize")
        // response format
        body.appendMultipart(boundary: boundary, name: "response_format", value: "diarized_json")
        // chunking strategy — required for audio > 30s
        body.appendMultipart(boundary: boundary, name: "chunking_strategy", value: "auto")

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let diarized = try await sendRequest(body: body, boundary: boundary)
        let transcript = assembleTranscript(from: diarized)

        logger.info("OpenAI transcription complete — \(transcript.segments.count) segments, \(transcript.duration)s")
        return transcript
    }

    // MARK: - Multi-Chunk Transcription

    /// Max concurrent API uploads — balances speed vs. rate limiting
    private static let maxConcurrentUploads = 4

    private func transcribeChunks(_ chunks: [AudioChunk]) async throws -> AssembledTranscript {
        let total = chunks.count
        logger.warning("Transcribing \(total) chunks in parallel (max \(Self.maxConcurrentUploads) concurrent)...")

        // Transcribe all chunks concurrently, collecting (index, segments) pairs
        let indexedResults: [(Int, [OpenAIDiarizedSegment])] = try await withThrowingTaskGroup(
            of: (Int, [OpenAIDiarizedSegment]).self
        ) { group in
            // Semaphore to limit concurrency
            let semaphore = ConcurrencyLimiter(limit: Self.maxConcurrentUploads)

            for (index, chunk) in chunks.enumerated() {
                group.addTask { [self] in
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    logger.warning("Transcribing chunk \(index + 1)/\(total) (offset \(String(format: "%.1f", chunk.timeOffset))s)...")

                    let diarized = try await self.transcribeSingleChunk(chunk: chunk)
                    let segments = diarized.segments ?? []

                    logger.info("Chunk \(index + 1) done — \(segments.count) raw segments")
                    return (index, segments)
                }
            }

            var collected: [(Int, [OpenAIDiarizedSegment])] = []
            for try await result in group {
                collected.append(result)
            }
            return collected
        }

        // Sort by chunk index to build speaker map in deterministic order
        let sortedResults = indexedResults.sorted { $0.0 < $1.0 }

        // Build global speaker map and offset timestamps
        var globalSpeakerMap: [String: Int] = [:]
        var nextSpeakerID = 0
        var allSegments: [TranscriptSegment] = []

        for (index, rawSegments) in sortedResults {
            let chunk = chunks[index]

            for seg in rawSegments {
                let text = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }

                let speakerKey = seg.speaker ?? "unknown"
                if globalSpeakerMap[speakerKey] == nil {
                    globalSpeakerMap[speakerKey] = nextSpeakerID
                    nextSpeakerID += 1
                }

                allSegments.append(TranscriptSegment(
                    speaker: globalSpeakerMap[speakerKey]!,
                    text: text,
                    startTime: seg.start + chunk.timeOffset,
                    endTime: seg.end + chunk.timeOffset
                ))
            }
        }

        // Sort by time (chunks may have overlapping regions)
        allSegments.sort { $0.startTime < $1.startTime }

        // Deduplicate overlapping segments from chunk boundaries
        let deduped = deduplicateOverlap(allSegments)

        let duration = deduped.last?.endTime ?? 0
        let merged = deduped.mergingConsecutiveSpeakers()

        logger.info("Multi-chunk transcription complete — \(merged.count) merged segments, \(String(format: "%.0f", duration))s total")
        return AssembledTranscript(segments: merged, duration: duration)
    }

    /// Upload and transcribe a single audio chunk via the OpenAI API.
    private func transcribeSingleChunk(chunk: AudioChunk) async throws -> OpenAIDiarizedResponse {
        let audioData = try Data(contentsOf: chunk.url)

        let boundary = UUID().uuidString
        var body = Data()

        body.appendMultipart(boundary: boundary, name: "file",
                             filename: chunk.url.lastPathComponent,
                             contentType: "audio/mp4", data: audioData)
        body.appendMultipart(boundary: boundary, name: "model", value: "gpt-4o-transcribe-diarize")
        body.appendMultipart(boundary: boundary, name: "response_format", value: "diarized_json")
        body.appendMultipart(boundary: boundary, name: "chunking_strategy", value: "auto")

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return try await sendRequest(body: body, boundary: boundary)
    }

    // MARK: - Network

    private func sendRequest(body: Data, boundary: String) async throws -> OpenAIDiarizedResponse {
        var lastError: Error = OpenAITranscriptionError.invalidResponse

        for attempt in 0..<maxRetries {
            if attempt > 0 {
                let delay = Double(1 << attempt) // 2s, 4s, 8s
                logger.info("Transcription retry \(attempt + 1)/\(self.maxRetries) after \(delay)s")
                try? await Task.sleep(for: .seconds(delay))
            }

            do {
                return try await sendSingleRequest(body: body, boundary: boundary)
            } catch let error as OpenAITranscriptionError {
                lastError = error
                if case .apiError(let statusCode, _) = error {
                    switch statusCode {
                    case 429:
                        logger.warning("OpenAI rate limited — will retry")
                        continue
                    case 500...599:
                        logger.warning("OpenAI server error \(statusCode) — will retry")
                        continue
                    default:
                        throw error // 401, 413, 400 etc — don't retry
                    }
                }
                throw error
            } catch {
                lastError = error
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain {
                    logger.warning("Network error (code \(nsError.code)) — will retry: \(error.localizedDescription, privacy: .public)")
                    continue
                }
                throw error
            }
        }

        throw lastError
    }

    private func sendSingleRequest(body: Data, boundary: String) async throws -> OpenAIDiarizedResponse {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAITranscriptionError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            logger.error("OpenAI API error \(httpResponse.statusCode): \(responseBody, privacy: .public)")
            throw OpenAITranscriptionError.apiError(statusCode: httpResponse.statusCode, message: responseBody)
        }

        return try JSONDecoder().decode(OpenAIDiarizedResponse.self, from: data)
    }

    // MARK: - Assembly

    private func assembleTranscript(from response: OpenAIDiarizedResponse) -> AssembledTranscript {
        guard let rawSegments = response.segments, !rawSegments.isEmpty else {
            return AssembledTranscript(segments: [], duration: 0)
        }

        // Map speaker letter strings ("A", "B", …) to integer IDs (0, 1, …)
        var speakerMap: [String: Int] = [:]
        var nextID = 0

        let segments: [TranscriptSegment] = rawSegments.compactMap { seg in
            let text = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }

            let speakerKey = seg.speaker ?? "unknown"
            if speakerMap[speakerKey] == nil {
                speakerMap[speakerKey] = nextID
                nextID += 1
            }

            return TranscriptSegment(
                speaker: speakerMap[speakerKey]!,
                text: text,
                startTime: seg.start,
                endTime: seg.end
            )
        }

        let duration = segments.last?.endTime ?? 0
        let merged = segments.mergingConsecutiveSpeakers()

        return AssembledTranscript(segments: merged, duration: duration)
    }

    /// Remove duplicate segments from overlapping chunk boundaries.
    /// Two segments are considered duplicates if they have similar timestamps and text.
    private func deduplicateOverlap(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        guard segments.count > 1 else { return segments }

        var result: [TranscriptSegment] = [segments[0]]

        for i in 1..<segments.count {
            let current = segments[i]
            let previous = result.last!

            // If segments start within 1 second of each other and have similar text, skip the duplicate
            let timeDelta = abs(current.startTime - previous.startTime)
            if timeDelta < 1.0 && textSimilar(current.text, previous.text) {
                continue
            }

            // Also skip if the current segment is entirely within the previous segment's time range
            if current.startTime >= previous.startTime && current.endTime <= previous.endTime + 0.5 {
                continue
            }

            result.append(current)
        }

        return result
    }

    /// Simple text similarity check — are the first 20 characters the same?
    private func textSimilar(_ a: String, _ b: String) -> Bool {
        let prefixLen = 20
        return a.prefix(prefixLen).lowercased() == b.prefix(prefixLen).lowercased()
    }
}

// MARK: - Concurrency Limiter

/// Simple actor-based semaphore to limit concurrent async tasks.
private actor ConcurrencyLimiter {
    private let limit: Int
    private var current = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = limit
    }

    func wait() async {
        if current < limit {
            current += 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            current -= 1
        }
    }
}

// MARK: - Multipart Helpers

private extension Data {
    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipart(boundary: String, name: String, filename: String,
                                  contentType: String, data fileData: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        append(fileData)
        append("\r\n".data(using: .utf8)!)
    }
}
