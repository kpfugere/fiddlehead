import Foundation

// MARK: - OpenAI Chat Completions Request

struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIChatMessage]
    let max_tokens: Int
    let temperature: Double
}

struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

// MARK: - OpenAI Chat Completions Response

struct OpenAIChatResponse: Codable {
    let id: String
    let choices: [OpenAIChatChoice]
    let usage: OpenAIChatUsage?
}

struct OpenAIChatChoice: Codable {
    let index: Int
    let message: OpenAIChatMessage
    let finish_reason: String?
}

struct OpenAIChatUsage: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
}

// MARK: - OpenAI Chat Completions Error

struct OpenAIChatErrorResponse: Codable {
    let error: OpenAIChatErrorDetail
}

struct OpenAIChatErrorDetail: Codable {
    let message: String
    let type: String?
    let code: String?
}

/// Result from structuring, including whether the output was truncated.
struct StructuringResult {
    let content: String
    let truncated: Bool
}

enum OpenAIStructuringError: Error, LocalizedError {
    case invalidAPIKey
    case requestFailed(String)
    case rateLimited
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: "Invalid OpenAI API key"
        case .requestFailed(let msg): "OpenAI API error: \(msg)"
        case .rateLimited: "OpenAI API rate limited — try again shortly"
        case .emptyResponse: "OpenAI returned an empty response"
        }
    }
}
