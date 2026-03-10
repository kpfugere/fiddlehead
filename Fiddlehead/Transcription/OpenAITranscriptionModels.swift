import Foundation

// MARK: - Diarized JSON Response

struct OpenAIDiarizedResponse: Codable, Sendable {
    let text: String?
    let segments: [OpenAIDiarizedSegment]?
}

struct OpenAIDiarizedSegment: Codable, Sendable {
    let id: String?
    let speaker: String?
    let text: String
    let start: Double
    let end: Double
    let type: String?
}

// MARK: - Errors

enum OpenAITranscriptionError: Error, LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from OpenAI"
        case .apiError(let code, let message):
            "OpenAI API error (\(code)): \(message)"
        }
    }
}
