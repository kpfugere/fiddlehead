import Foundation

/// Fallback chain for error recovery:
/// 1. Structured markdown note (OpenAI)
/// 2. Raw transcript as markdown
/// 3. Audio file only
enum ErrorRecovery {
    /// Attempt to save at least something from a failed pipeline run.
    /// Returns the URL of whatever was saved, or nil if nothing could be saved.
    @MainActor
    static func saveFallback(
        transcript: AssembledTranscript?,
        audioURL: URL?,
        settings: AppSettings,
        date: Date
    ) -> URL? {
        // Level 2: Save raw transcript
        if let transcript, !transcript.isEmpty {
            let baseFilename = NoteStorage.transcriptFilename(for: date)
            let filename = NoteStorage.uniqueFilename(base: baseFilename, in: settings.saveLocation)
            let url = settings.saveLocation
                .appendingPathComponent(filename)

            let durationMin = Int(transcript.duration) / 60
            let durationSec = Int(transcript.duration) % 60

            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            let content = """
            ---
            date: \(ISO8601DateFormatter().string(from: date))
            duration: \(durationMin)m \(durationSec)s
            status: unstructured
            ---

            # Recording — \(formatter.string(from: date))

            > Note: This transcript could not be structured automatically.

            ## Transcript

            \(transcript.formatted(speakerName: settings.speakerName.isEmpty ? nil : settings.speakerName))
            """

            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                return url
            } catch {
                // Fall through to audio-only fallback
            }
        }

        // Level 3: Audio file exists
        if let audioURL, FileManager.default.fileExists(atPath: audioURL.path) {
            return audioURL
        }

        return nil
    }
}
