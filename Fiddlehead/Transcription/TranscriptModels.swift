import Foundation

// MARK: - Assembled Transcript

struct TranscriptSegment {
    let speaker: Int
    let text: String
    let startTime: Double
    let endTime: Double
}

struct AssembledTranscript {
    let segments: [TranscriptSegment]
    let duration: Double
    /// When true, speaker 0 = mic (user), speaker 1+ = system audio (others).
    /// Labels are deterministic from audio channels rather than voice-based diarization.
    let multichannelLabeled: Bool

    init(segments: [TranscriptSegment], duration: Double, multichannelLabeled: Bool = false) {
        self.segments = segments
        self.duration = duration
        self.multichannelLabeled = multichannelLabeled
    }

    var isEmpty: Bool { segments.isEmpty }

    /// Number of distinct speakers detected
    var speakerCount: Int {
        Set(segments.map(\.speaker)).count
    }

    /// Formatted transcript with speaker labels.
    /// If a speakerName is provided, it replaces "Speaker 1" (the mic user).
    /// If only one speaker is detected, omit speaker labels entirely.
    func formatted(speakerName: String? = nil) -> String {
        let singleSpeaker = speakerCount <= 1
        var result = ""
        var currentSpeaker = -1

        for segment in segments {
            if segment.speaker != currentSpeaker {
                if !result.isEmpty { result += "\n\n" }
                if !singleSpeaker {
                    let label = speakerLabel(for: segment.speaker, speakerName: speakerName)
                    result += "**\(label):** "
                }
                currentSpeaker = segment.speaker
            } else {
                result += " "
            }
            result += segment.text
        }
        return result
    }

    /// Plain text without markdown formatting
    func plainText(speakerName: String? = nil) -> String {
        let singleSpeaker = speakerCount <= 1
        var result = ""
        var currentSpeaker = -1

        for segment in segments {
            if segment.speaker != currentSpeaker {
                if !result.isEmpty { result += "\n\n" }
                if !singleSpeaker {
                    let label = speakerLabel(for: segment.speaker, speakerName: speakerName)
                    result += "\(label): "
                }
                currentSpeaker = segment.speaker
            } else {
                result += " "
            }
            result += segment.text
        }
        return result
    }

    private func speakerLabel(for speaker: Int, speakerName: String?) -> String {
        if speaker == 0 {
            return speakerName ?? "Me"
        } else {
            return "Them"
        }
    }
}

// MARK: - Shared Helpers

extension Array where Element == TranscriptSegment {
    /// Merge consecutive segments from the same speaker into single segments.
    func mergingConsecutiveSpeakers() -> [TranscriptSegment] {
        guard !isEmpty else { return [] }

        var merged: [TranscriptSegment] = []
        var current = self[0]

        for i in 1..<count {
            let next = self[i]
            if next.speaker == current.speaker {
                current = TranscriptSegment(
                    speaker: current.speaker,
                    text: current.text + " " + next.text,
                    startTime: current.startTime,
                    endTime: next.endTime
                )
            } else {
                merged.append(current)
                current = next
            }
        }
        merged.append(current)

        return merged
    }
}
