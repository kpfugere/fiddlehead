import Foundation

// MARK: - Upload Response

struct AssemblyAIUploadResponse: Codable, Sendable {
    let upload_url: String
}

// MARK: - Transcript Request

struct AssemblyAITranscriptRequest: Codable, Sendable {
    let audio_url: String
    let speech_models: [String]
    let language_detection: Bool
    let speaker_labels: Bool?
    let multichannel: Bool?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(audio_url, forKey: .audio_url)
        try container.encode(speech_models, forKey: .speech_models)
        try container.encode(language_detection, forKey: .language_detection)
        try container.encodeIfPresent(speaker_labels, forKey: .speaker_labels)
        try container.encodeIfPresent(multichannel, forKey: .multichannel)
    }
}

// MARK: - Transcript Response

struct AssemblyAITranscriptResponse: Codable, Sendable {
    let id: String
    let status: String
    let text: String?
    let utterances: [AssemblyAIUtterance]?
    let channels: [AssemblyAIChannel]?
    let error: String?
}

struct AssemblyAIChannel: Codable, Sendable {
    let channel_label: String
    let words: [AssemblyAIWord]
}

struct AssemblyAIWord: Codable, Sendable {
    let text: String
    let start: Int       // milliseconds
    let end: Int         // milliseconds
    let confidence: Double
}

struct AssemblyAIUtterance: Codable, Sendable {
    let speaker: String        // "A", "B", "C", …
    let text: String
    let start: Int             // milliseconds
    let end: Int               // milliseconds
    let confidence: Double
}

// MARK: - Errors

enum AssemblyAITranscriptionError: Error, LocalizedError {
    case invalidResponse
    case uploadFailed(statusCode: Int, message: String)
    case apiError(statusCode: Int, message: String)
    case transcriptionFailed(message: String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from AssemblyAI"
        case .uploadFailed(let code, let message):
            "AssemblyAI upload failed (\(code)): \(message)"
        case .apiError(let code, let message):
            "AssemblyAI API error (\(code)): \(message)"
        case .transcriptionFailed(let message):
            "AssemblyAI transcription failed: \(message)"
        case .timeout:
            "AssemblyAI transcription timed out"
        }
    }
}
