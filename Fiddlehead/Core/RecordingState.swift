import Foundation

enum RecordingState: Equatable {
    case idle
    case recording(startTime: Date)
    case processing(stage: ProcessingStage)
    case completed(noteURL: URL, title: String? = nil)
    case error(message: String)

    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): true
        case let (.recording(a), .recording(b)): a == b
        case let (.processing(a), .processing(b)): a == b
        case let (.completed(a, _), .completed(b, _)): a == b
        case let (.error(a), .error(b)): a == b
        default: false
        }
    }

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var isProcessing: Bool {
        if case .processing = self { return true }
        return false
    }
}

enum ProcessingStage: Equatable {
    case transcribing
    case structuring
    case saving

    var label: String {
        switch self {
        case .transcribing: "Transcribing..."
        case .structuring: "Structuring notes..."
        case .saving: "Saving..."
        }
    }

    var progress: Double {
        switch self {
        case .transcribing: 0.33
        case .structuring: 0.66
        case .saving: 0.9
        }
    }
}
