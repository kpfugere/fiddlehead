import Foundation

/// Common interface for batch transcription services.
protocol TranscriptionService {
    func transcribe(fileURL: URL, channels: Int) async throws -> AssembledTranscript
}
