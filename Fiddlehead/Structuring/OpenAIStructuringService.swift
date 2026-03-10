import Foundation
import os.log

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "OpenAIStructuring")

/// Sends transcripts to OpenAI Chat Completions API for structuring into markdown notes.
final class OpenAIStructuringService: Sendable {
    private let apiKey: String
    private let model: String
    private let maxRetries: Int

    init(apiKey: String, model: String = "gpt-4o", maxRetries: Int = 3) {
        self.apiKey = apiKey
        self.model = model
        self.maxRetries = maxRetries
    }

    /// Structure a transcript into a markdown note (with automatic retry for transient errors)
    func structure(
        transcript: String,
        duration: TimeInterval,
        meetingTitle: String? = nil
    ) async throws -> StructuringResult {
        let request = OpenAIChatRequest(
            model: model,
            messages: [
                OpenAIChatMessage(role: "system", content: StructuringPrompt.system),
                OpenAIChatMessage(
                    role: "user",
                    content: StructuringPrompt.userPrompt(
                        transcript: transcript,
                        duration: duration,
                        meetingTitle: meetingTitle
                    )
                )
            ],
            max_tokens: 8192,
            temperature: 0.3
        )

        let body = try JSONEncoder().encode(request)

        var lastError: Error = OpenAIStructuringError.requestFailed("Unknown")

        for attempt in 0..<maxRetries {
            if attempt > 0 {
                let delay = Double(1 << attempt)
                logger.info("OpenAI retry \(attempt + 1)/\(self.maxRetries) after \(delay)s")
                try? await Task.sleep(for: .seconds(delay))
            }

            do {
                let (content, finishReason) = try await sendRequest(body: body)
                let truncated = finishReason == "length"
                if truncated {
                    logger.warning("OpenAI output truncated (finish_reason=length)")
                }
                return StructuringResult(content: content, truncated: truncated)
            } catch let error as OpenAIStructuringError {
                lastError = error
                switch error {
                case .rateLimited:
                    logger.warning("OpenAI rate limited — will retry")
                    continue
                case .requestFailed(let msg) where msg.hasPrefix("HTTP 5"):
                    logger.warning("OpenAI server error — will retry: \(msg)")
                    continue
                default:
                    throw error
                }
            } catch {
                lastError = error
                if (error as NSError).domain == NSURLErrorDomain {
                    logger.warning("OpenAI network error — will retry: \(error.localizedDescription)")
                    continue
                }
                throw error
            }
        }

        throw lastError
    }

    /// Generate a brief session-level summary from individual topic summaries.
    func summarizeSession(topicSummaries: [String]) async throws -> String {
        let prompt = """
        Given these summaries from different topics in a single recording session, \
        write a concise 2-3 sentence overview that captures the key themes and outcomes \
        across all topics. Be specific — include names, numbers, and conclusions rather \
        than generic descriptions. Output only the summary text, nothing else.

        \(topicSummaries.enumerated().map { "Topic \($0.offset + 1): \($0.element)" }.joined(separator: "\n\n"))
        """

        let request = OpenAIChatRequest(
            model: model,
            messages: [
                OpenAIChatMessage(role: "system", content: "You are a concise note-taking assistant."),
                OpenAIChatMessage(role: "user", content: prompt)
            ],
            max_tokens: 512,
            temperature: 0.3
        )

        let body = try JSONEncoder().encode(request)
        let (content, _) = try await sendRequest(body: body)
        return content
    }

    // MARK: - Private

    private func sendRequest(body: Data) async throws -> (content: String, finishReason: String?) {
        var urlRequest = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = body
        urlRequest.timeoutInterval = 90

        let (responseData, httpResponse) = try await URLSession.shared.data(for: urlRequest)

        guard let http = httpResponse as? HTTPURLResponse else {
            throw OpenAIStructuringError.requestFailed("Invalid response")
        }

        switch http.statusCode {
        case 200:
            let response = try JSONDecoder().decode(OpenAIChatResponse.self, from: responseData)
            guard let choice = response.choices.first,
                  !choice.message.content.isEmpty else {
                throw OpenAIStructuringError.emptyResponse
            }
            return (content: choice.message.content, finishReason: choice.finish_reason)

        case 401:
            throw OpenAIStructuringError.invalidAPIKey

        case 429:
            throw OpenAIStructuringError.rateLimited

        default:
            if let errorResponse = try? JSONDecoder().decode(OpenAIChatErrorResponse.self, from: responseData) {
                throw OpenAIStructuringError.requestFailed(errorResponse.error.message)
            }
            throw OpenAIStructuringError.requestFailed("HTTP \(http.statusCode)")
        }
    }
}
