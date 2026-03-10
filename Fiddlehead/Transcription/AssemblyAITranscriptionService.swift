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
    private let maxRetries: Int
    private static let pollInterval: Duration = .seconds(3)
    private static let maxPollTime: Duration = .seconds(600) // 10 minutes

    init(apiKey: String, maxRetries: Int = 3) {
        self.apiKey = apiKey
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
        let transcriptID = try await submitTranscription(audioURL: uploadURL, multichannel: useMultichannel, audioChannels: useMultichannel ? channels : nil)

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

    private func submitTranscription(audioURL: String, multichannel: Bool = false, audioChannels: Int? = nil) async throws -> String {
        let requestBody: AssemblyAITranscriptRequest
        if multichannel {
            // multichannel and speaker_labels are mutually exclusive in AssemblyAI
            requestBody = AssemblyAITranscriptRequest(
                audio_url: audioURL,
                speech_models: ["universal-2"],
                speaker_labels: nil,
                multichannel: true,
                audio_channels: audioChannels
            )
            logger.info("Submitting multichannel transcription (channels: \(audioChannels ?? 2))")
        } else {
            requestBody = AssemblyAITranscriptRequest(
                audio_url: audioURL,
                speech_models: ["universal-2"],
                speaker_labels: true,
                multichannel: nil,
                audio_channels: nil
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
    /// Channel 1 (index 0) = mic = speaker 0 (user), Channel 2 (index 1) = system = speaker 1 (them).
    private func assembleMultichannelTranscript(from response: AssemblyAITranscriptResponse, originalDuration: Double) -> AssembledTranscript {
        guard let channels = response.channels, !channels.isEmpty else {
            logger.warning("Multichannel response has no channels — falling back to utterance assembly")
            let fallback = assembleTranscript(from: response)
            return AssembledTranscript(segments: fallback.segments, duration: originalDuration)
        }

        // Collect all words with their speaker (channel index)
        struct TimedWord {
            let speaker: Int
            let text: String
            let start: Double
            let end: Double
        }

        var allWords: [TimedWord] = []
        for (channelIndex, channel) in channels.enumerated() {
            // AssemblyAI labels channels "Channel 1", "Channel 2", etc.
            // Channel 1 = first audio channel = mic (left) = speaker 0
            // Channel 2 = second audio channel = system (right) = speaker 1
            let speaker = channelIndex
            for word in channel.words {
                let text = word.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                allWords.append(TimedWord(
                    speaker: speaker,
                    text: text,
                    start: Double(word.start) / 1000.0,
                    end: Double(word.end) / 1000.0
                ))
            }
        }

        // Sort by start time
        allWords.sort { $0.start < $1.start }

        guard !allWords.isEmpty else {
            return AssembledTranscript(segments: [], duration: originalDuration, multichannelLabeled: true)
        }

        // Group consecutive same-speaker words into segments
        var segments: [TranscriptSegment] = []
        var currentSpeaker = allWords[0].speaker
        var currentText = allWords[0].text
        var currentStart = allWords[0].start
        var currentEnd = allWords[0].end

        for i in 1..<allWords.count {
            let word = allWords[i]
            if word.speaker == currentSpeaker {
                currentText += " " + word.text
                currentEnd = word.end
            } else {
                segments.append(TranscriptSegment(
                    speaker: currentSpeaker,
                    text: currentText,
                    startTime: currentStart,
                    endTime: currentEnd
                ))
                currentSpeaker = word.speaker
                currentText = word.text
                currentStart = word.start
                currentEnd = word.end
            }
        }
        segments.append(TranscriptSegment(
            speaker: currentSpeaker,
            text: currentText,
            startTime: currentStart,
            endTime: currentEnd
        ))

        let merged = segments.mergingConsecutiveSpeakers()
        logger.info("Multichannel assembly: \(channels.count) channels → \(merged.count) segments")

        return AssembledTranscript(segments: merged, duration: originalDuration, multichannelLabeled: true)
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
