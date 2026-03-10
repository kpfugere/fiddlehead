import Foundation
import os.log

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "TopicSplitter")

/// Identifies topic boundaries in a transcript using gpt-4o.
/// Returns an array of topic segments that can be structured and saved individually.
final class TopicSplitter: Sendable {
    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "gpt-4o") {
        self.apiKey = apiKey
        self.model = model
    }

    struct TopicSegment: Sendable {
        let title: String
        let segments: [TranscriptSegment]
        let duration: TimeInterval
    }

    /// Split a transcript into topic-based segments.
    /// Returns a single segment for short transcripts (< 3 minutes).
    func split(transcript: AssembledTranscript, speakerName: String?) async throws -> [TopicSegment] {
        // Short transcripts are a single topic — skip the API call.
        // 10 minutes minimum avoids over-splitting short conversations into
        // fragments where the summary is longer than the transcript itself.
        guard transcript.duration >= 600 else {
            logger.info("Transcript < 10min (\(transcript.duration, format: .fixed(precision: 0))s) — single topic")
            return [TopicSegment(
                title: "",
                segments: transcript.segments,
                duration: transcript.duration
            )]
        }

        let numberedLines = buildNumberedLines(transcript: transcript, speakerName: speakerName)
        let boundaries = try await detectBoundaries(numberedLines: numberedLines, lineCount: transcript.segments.count)

        guard boundaries.count > 1 else {
            logger.info("LLM found single topic")
            return [TopicSegment(
                title: boundaries.first?.title ?? "",
                segments: transcript.segments,
                duration: transcript.duration
            )]
        }

        logger.info("LLM split into \(boundaries.count) topics")
        return boundaries.map { boundary in
            let start = max(0, boundary.startLine)
            let end = min(transcript.segments.count - 1, boundary.endLine)
            let segs = Array(transcript.segments[start...end])
            let dur: TimeInterval
            if let first = segs.first, let last = segs.last {
                dur = last.endTime - first.startTime
            } else {
                dur = 0
            }
            return TopicSegment(title: boundary.title, segments: segs, duration: dur)
        }
    }

    // MARK: - Private

    private struct BoundaryResult: Codable {
        let title: String
        let start_line: Int
        let end_line: Int

        var startLine: Int { start_line }
        var endLine: Int { end_line }
    }

    private func buildNumberedLines(transcript: AssembledTranscript, speakerName: String?) -> String {
        transcript.segments.enumerated().map { index, seg in
            let speaker = "Speaker \(seg.speaker + 1)"
            return "\(index): [\(speaker)] \(seg.text)"
        }.joined(separator: "\n")
    }

    private func detectBoundaries(numberedLines: String, lineCount: Int) async throws -> [BoundaryResult] {
        let systemPrompt = """
        You identify topic boundaries in meeting transcripts. Given numbered transcript lines, \
        return a JSON array of topic segments. Each segment has a short title, start_line, and end_line (inclusive, 0-indexed). \
        Every line must belong to exactly one segment. Segments must be contiguous and non-overlapping. \
        IMPORTANT: Prefer FEWER, LARGER topics. Only split when there is a completely distinct subject change. \
        A single conversation that meanders slightly is still ONE topic. \
        Each topic should cover at least 3-5 minutes of content. Never create a segment shorter than 1 minute. \
        If in doubt, do NOT split — return a single topic. \
        Return ONLY the JSON array, no other text.
        """

        let userPrompt = """
        Split this transcript into topics. There are \(lineCount) lines (0 to \(lineCount - 1)).

        \(numberedLines)
        """

        let request = OpenAIChatRequest(
            model: model,
            messages: [
                OpenAIChatMessage(role: "system", content: systemPrompt),
                OpenAIChatMessage(role: "user", content: userPrompt)
            ],
            max_tokens: 4096,
            temperature: 0.1
        )

        let body = try JSONEncoder().encode(request)
        let responseText = try await sendRequest(body: body)

        // Parse JSON from response (strip markdown fences if present)
        let cleaned = responseText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            logger.error("Failed to encode cleaned response as UTF-8")
            return fallback(lineCount: lineCount)
        }

        do {
            let boundaries = try JSONDecoder().decode([BoundaryResult].self, from: data)
            guard !boundaries.isEmpty else { return fallback(lineCount: lineCount) }
            return boundaries
        } catch {
            logger.error("JSON parse failed: \(error.localizedDescription, privacy: .public)")
            return fallback(lineCount: lineCount)
        }
    }

    private func fallback(lineCount: Int) -> [BoundaryResult] {
        [BoundaryResult(title: "", start_line: 0, end_line: lineCount - 1)]
    }

    private func sendRequest(body: Data) async throws -> String {
        var urlRequest = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = body
        urlRequest.timeoutInterval = 60

        let (responseData, httpResponse) = try await URLSession.shared.data(for: urlRequest)

        guard let http = httpResponse as? HTTPURLResponse else {
            throw OpenAIStructuringError.requestFailed("Invalid response")
        }

        switch http.statusCode {
        case 200:
            let response = try JSONDecoder().decode(OpenAIChatResponse.self, from: responseData)
            guard let text = response.choices.first?.message.content, !text.isEmpty else {
                throw OpenAIStructuringError.emptyResponse
            }
            if let usage = response.usage {
                logger.info("Topic split tokens — prompt: \(usage.prompt_tokens), completion: \(usage.completion_tokens)")
            }
            return text

        case 401:
            throw OpenAIStructuringError.invalidAPIKey

        case 429:
            throw OpenAIStructuringError.rateLimited

        default:
            throw OpenAIStructuringError.requestFailed("HTTP \(http.statusCode)")
        }
    }
}
