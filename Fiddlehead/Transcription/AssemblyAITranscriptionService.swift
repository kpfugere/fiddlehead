import Foundation
import os.log

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "AssemblyAITranscription")

/// Transcribes a saved audio file using AssemblyAI's Universal model with speaker diarization.
/// Uses a 3-step async flow: upload → submit → poll for completion.
///
/// AssemblyAI accepts files up to 2.2 GB and 10 hours, so chunking is not needed.
/// We still strip silence and compress to M4A to reduce upload size and billing.
final class AssemblyAITranscriptionService: TranscriptionService, Sendable {
    private let apiKey: String
    private let speechModels: [String]
    private let maxRetries: Int
    private static let pollInterval: Duration = .seconds(3)
    private static let maxPollTime: Duration = .seconds(600) // 10 minutes

    init(apiKey: String, speechModels: [String] = ["universal-2"], maxRetries: Int = 3) {
        self.apiKey = apiKey
        self.speechModels = speechModels
        self.maxRetries = maxRetries
    }

    func transcribe(fileURL: URL, channels: Int) async throws -> AssembledTranscript {
        // Step 0: Strip silence to reduce upload size (and per-second billing)
        let preprocessed = try AudioPreprocessor.removeSilence(wavURL: fileURL)
        let activeWAV = preprocessed.url

        // Step 1: Compress WAV → M4A (AAC), preserving channel count
        logger.info("Compressing WAV before AssemblyAI upload...")
        let m4aURL = try await AudioCompressor.compress(wavURL: activeWAV, channels: channels)

        var tempFiles: [URL] = [m4aURL]
        if activeWAV != fileURL { tempFiles.append(activeWAV) }
        defer { AudioCompressor.cleanup(tempFiles: tempFiles) }

        // Step 2: Upload file to AssemblyAI
        let uploadURL = try await uploadFile(fileURL: m4aURL)

        // Step 3: Submit transcription job (multichannel if stereo, else speaker diarization)
        let useMultichannel = channels >= 2
        let transcriptID = try await submitTranscription(audioURL: uploadURL, multichannel: useMultichannel)

        // Step 4: Poll until completion
        let response = try await pollForCompletion(transcriptID: transcriptID)

        // Step 5: Assemble into common transcript format
        let transcript: AssembledTranscript
        if useMultichannel, response.channels != nil {
            transcript = assembleMultichannelTranscript(from: response, originalDuration: preprocessed.originalDuration)
        } else {
            let assembled = assembleTranscript(from: response)
            transcript = AssembledTranscript(
                segments: assembled.segments,
                duration: preprocessed.originalDuration
            )
        }

        logger.info("AssemblyAI transcription complete — \(transcript.segments.count) segments, multichannel: \(transcript.multichannelLabeled)")

        return transcript
    }

    // MARK: - Upload

    private func uploadFile(fileURL: URL) async throws -> String {
        let audioData = try Data(contentsOf: fileURL)
        logger.warning("Uploading \(audioData.count) bytes to AssemblyAI...")

        var request = URLRequest(url: URL(string: "https://api.assemblyai.com/v2/upload")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        let (data, response) = try await sendWithRetry {
            try await URLSession.shared.upload(for: request, from: audioData)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AssemblyAITranscriptionError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            logger.error("AssemblyAI upload error \(httpResponse.statusCode): \(body, privacy: .public)")
            throw AssemblyAITranscriptionError.uploadFailed(statusCode: httpResponse.statusCode, message: body)
        }

        let uploadResponse = try JSONDecoder().decode(AssemblyAIUploadResponse.self, from: data)
        logger.info("File uploaded to AssemblyAI")
        return uploadResponse.upload_url
    }

    // MARK: - Submit

    private func submitTranscription(audioURL: String, multichannel: Bool = false) async throws -> String {
        let requestBody: AssemblyAITranscriptRequest
        if multichannel {
            // AssemblyAI now supports multichannel + speaker_labels together
            requestBody = AssemblyAITranscriptRequest(
                audio_url: audioURL,
                speech_models: speechModels,
                language_detection: true,
                speaker_labels: true,
                multichannel: true
            )
            logger.info("Submitting multichannel transcription with speaker labels, models: \(self.speechModels, privacy: .public)")
        } else {
            requestBody = AssemblyAITranscriptRequest(
                audio_url: audioURL,
                speech_models: speechModels,
                language_detection: true,
                speaker_labels: true,
                multichannel: nil
            )
        }

        var request = URLRequest(url: URL(string: "https://api.assemblyai.com/v2/transcript")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await sendWithRetry {
            try await URLSession.shared.data(for: request)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AssemblyAITranscriptionError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            logger.error("AssemblyAI submit error \(httpResponse.statusCode): \(body, privacy: .public)")
            throw AssemblyAITranscriptionError.apiError(statusCode: httpResponse.statusCode, message: body)
        }

        let submitResponse = try JSONDecoder().decode(AssemblyAITranscriptResponse.self, from: data)
        logger.info("AssemblyAI transcription submitted — id: \(submitResponse.id, privacy: .public)")
        return submitResponse.id
    }

    // MARK: - Poll

    private func pollForCompletion(transcriptID: String) async throws -> AssemblyAITranscriptResponse {
        let url = URL(string: "https://api.assemblyai.com/v2/transcript/\(transcriptID)")!
        let startTime = ContinuousClock.now

        while ContinuousClock.now - startTime < Self.maxPollTime {
            try await Task.sleep(for: Self.pollInterval)

            var request = URLRequest(url: url)
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                logger.warning("AssemblyAI poll returned non-200 — retrying")
                continue
            }

            let pollResponse = try JSONDecoder().decode(AssemblyAITranscriptResponse.self, from: data)

            switch pollResponse.status {
            case "completed":
                logger.info("AssemblyAI transcription completed")
                return pollResponse
            case "error":
                let msg = pollResponse.error ?? "unknown error"
                logger.error("AssemblyAI transcription error: \(msg, privacy: .public)")
                throw AssemblyAITranscriptionError.transcriptionFailed(message: msg)
            default:
                // "queued" or "processing" — keep polling
                logger.debug("AssemblyAI status: \(pollResponse.status, privacy: .public)")
                continue
            }
        }

        throw AssemblyAITranscriptionError.timeout
    }

    // MARK: - Assembly

    /// Assemble multichannel response into transcript with deterministic speaker labels.
    /// Uses channel_label to map channels, builds segments per channel independently,
    /// then deduplicates overlapping segments (crosstalk) using confidence scores.
    private func assembleMultichannelTranscript(from response: AssemblyAITranscriptResponse, originalDuration: Double) -> AssembledTranscript {
        guard let channels = response.channels, !channels.isEmpty else {
            logger.warning("Multichannel response has no channels — falling back to utterance assembly")
            let fallback = assembleTranscript(from: response)
            return AssembledTranscript(segments: fallback.segments, duration: originalDuration)
        }

        // Map channel_label to speaker ID: "Channel 1" (mic/left) = speaker 0, "Channel 2" (system/right) = speaker 1
        // Fall back to array index if labels are missing or unexpected
        for channel in channels {
            logger.info("AssemblyAI channel: \(channel.channel_label, privacy: .public) — \(channel.words.count) words")
        }

        struct ChannelSegment {
            let speaker: Int
            let text: String
            let start: Double
            let end: Double
            let avgConfidence: Double
        }

        // Step 1: Build utterance-level segments per channel independently.
        // Words within 1.5s of each other on the same channel form one segment.
        let gapThreshold = 1.5
        var allChannelSegments: [ChannelSegment] = []

        for channel in channels {
            let speaker = speakerForChannelLabel(channel.channel_label, channels: channels)
            let words = channel.words.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            guard !words.isEmpty else { continue }

            var segStart = Double(words[0].start) / 1000.0
            var segEnd = Double(words[0].end) / 1000.0
            var segText = words[0].text.trimmingCharacters(in: .whitespacesAndNewlines)
            var segConfidenceSum = words[0].confidence
            var segWordCount = 1

            for i in 1..<words.count {
                let word = words[i]
                let wordStart = Double(word.start) / 1000.0
                let wordEnd = Double(word.end) / 1000.0
                let wordText = word.text.trimmingCharacters(in: .whitespacesAndNewlines)

                if wordStart - segEnd <= gapThreshold {
                    // Continue current segment
                    segText += " " + wordText
                    segEnd = wordEnd
                    segConfidenceSum += word.confidence
                    segWordCount += 1
                } else {
                    // Emit segment, start new one
                    allChannelSegments.append(ChannelSegment(
                        speaker: speaker, text: segText,
                        start: segStart, end: segEnd,
                        avgConfidence: segConfidenceSum / Double(segWordCount)
                    ))
                    segStart = wordStart
                    segEnd = wordEnd
                    segText = wordText
                    segConfidenceSum = word.confidence
                    segWordCount = 1
                }
            }
            allChannelSegments.append(ChannelSegment(
                speaker: speaker, text: segText,
                start: segStart, end: segEnd,
                avgConfidence: segConfidenceSum / Double(segWordCount)
            ))
        }

        // Step 2: Deduplicate overlapping segments from different channels (crosstalk).
        // When segments from different speakers overlap >50% in time, keep the one
        // with higher average confidence (the channel that actually captured the voice).
        allChannelSegments.sort { $0.start < $1.start }
        var deduped: [ChannelSegment] = []
        var skipIndices: Set<Int> = []
        var dedupCount = 0

        for i in 0..<allChannelSegments.count {
            guard !skipIndices.contains(i) else { continue }
            let seg = allChannelSegments[i]

            // Look ahead for overlapping segments from a different speaker
            var bestSeg = seg
            for j in (i + 1)..<allChannelSegments.count {
                guard !skipIndices.contains(j) else { continue }
                let other = allChannelSegments[j]
                if other.start >= seg.end { break } // no more overlap possible
                guard other.speaker != seg.speaker else { continue }

                // Calculate overlap ratio
                let overlapStart = max(seg.start, other.start)
                let overlapEnd = min(seg.end, other.end)
                let overlap = max(0, overlapEnd - overlapStart)
                let shorterDuration = min(seg.end - seg.start, other.end - other.start)
                guard shorterDuration > 0 else { continue }
                let overlapRatio = overlap / shorterDuration

                if overlapRatio > 0.5 {
                    // Crosstalk — keep the segment with higher confidence
                    dedupCount += 1
                    if other.avgConfidence > bestSeg.avgConfidence {
                        skipIndices.insert(i)
                        bestSeg = other
                    }
                    skipIndices.insert(j)
                }
            }
            if !skipIndices.contains(i) {
                deduped.append(bestSeg)
            } else if bestSeg.start != seg.start || bestSeg.end != seg.end {
                // The "other" segment won — add it instead
                deduped.append(bestSeg)
            }
        }

        guard !deduped.isEmpty else {
            return AssembledTranscript(segments: [], duration: originalDuration, multichannelLabeled: true)
        }

        // Step 3: Convert to TranscriptSegments and merge consecutive same-speaker
        let segments = deduped.map { seg in
            TranscriptSegment(speaker: seg.speaker, text: seg.text, startTime: seg.start, endTime: seg.end)
        }
        let merged = segments.mergingConsecutiveSpeakers()

        logger.info("Multichannel assembly: \(channels.count) channels → \(merged.count) segments (\(dedupCount) crosstalk segments removed)")

        return AssembledTranscript(segments: merged, duration: originalDuration, multichannelLabeled: true)
    }

    /// Map AssemblyAI channel_label to speaker ID.
    /// "Channel 1" = left audio = mic = speaker 0 (user).
    /// "Channel 2" = right audio = system = speaker 1 (them).
    /// Falls back to array index if labels are unexpected.
    private func speakerForChannelLabel(_ label: String, channels: [AssemblyAIChannel]) -> Int {
        // Parse the channel number from labels like "Channel 1", "Channel 2"
        let digits = label.filter(\.isNumber)
        if let channelNumber = Int(digits) {
            // Channel 1 = left = mic = speaker 0, Channel 2 = right = system = speaker 1
            return channelNumber - 1
        }
        // Fallback: use position in array
        if let idx = channels.firstIndex(where: { $0.channel_label == label }) {
            logger.warning("Unexpected channel label '\(label, privacy: .public)' — using array index \(idx)")
            return idx
        }
        return 0
    }

    private func assembleTranscript(from response: AssemblyAITranscriptResponse) -> AssembledTranscript {
        guard let utterances = response.utterances, !utterances.isEmpty else {
            return AssembledTranscript(segments: [], duration: 0)
        }

        // Map speaker letter strings ("A", "B", …) to integer IDs (0, 1, …)
        var speakerMap: [String: Int] = [:]
        var nextID = 0

        let segments: [TranscriptSegment] = utterances.compactMap { utt in
            let text = utt.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }

            if speakerMap[utt.speaker] == nil {
                speakerMap[utt.speaker] = nextID
                nextID += 1
            }

            return TranscriptSegment(
                speaker: speakerMap[utt.speaker]!,
                text: text,
                startTime: Double(utt.start) / 1000.0,  // ms → seconds
                endTime: Double(utt.end) / 1000.0
            )
        }

        let duration = segments.last?.endTime ?? 0
        let merged = segments.mergingConsecutiveSpeakers()

        return AssembledTranscript(segments: merged, duration: duration)
    }

    // MARK: - Retry Helper

    /// Retry network requests with exponential backoff for transient errors.
    private func sendWithRetry(
        _ operation: () async throws -> (Data, URLResponse)
    ) async throws -> (Data, URLResponse) {
        var lastError: Error = AssemblyAITranscriptionError.invalidResponse

        for attempt in 0..<maxRetries {
            if attempt > 0 {
                let delay = Double(1 << attempt) // 2s, 4s, 8s
                logger.info("AssemblyAI retry \(attempt + 1)/\(self.maxRetries) after \(delay)s")
                try? await Task.sleep(for: .seconds(delay))
            }

            do {
                let (data, response) = try await operation()

                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 429:
                        logger.warning("AssemblyAI rate limited — will retry")
                        lastError = AssemblyAITranscriptionError.apiError(statusCode: 429, message: "rate limited")
                        continue
                    case 500...599:
                        logger.warning("AssemblyAI server error \(httpResponse.statusCode) — will retry")
                        lastError = AssemblyAITranscriptionError.apiError(statusCode: httpResponse.statusCode, message: "server error")
                        continue
                    default:
                        return (data, response)
                    }
                }

                return (data, response)
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
}
