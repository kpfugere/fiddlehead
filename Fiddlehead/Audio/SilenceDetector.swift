import Foundation
import os.log

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "Silence")

/// Monitors PCM audio buffers for sustained silence and fires a callback
/// when the silence duration exceeds a configurable timeout.
@MainActor
final class SilenceDetector {
    /// RMS threshold below which audio is considered silent.
    /// For Int16 PCM: RMS < 100 is roughly -50dB.
    private let silenceThreshold: Float = 100

    /// Duration in seconds of continuous silence before triggering.
    var silenceTimeoutSeconds: TimeInterval = 180

    /// Called once when silence exceeds the timeout. Reset clears the fired state.
    var onSilenceTimeout: (() -> Void)?

    private var silentDuration: TimeInterval = 0
    private var hasFired = false

    /// Expected sample rate — used to convert buffer size to duration.
    private let sampleRate: Double = 16000

    /// Number of audio channels (1=mono, 2=stereo). Affects buffer duration calculation.
    var channels: Int = 1

    /// Process a buffer of Int16 PCM audio. Call this for every audio chunk.
    func processBuffer(_ data: Data) {
        guard !hasFired else { return }

        let rms = calculateRMS(data)
        let bufferDuration = Double(data.count / (2 * channels)) / sampleRate

        if rms < silenceThreshold {
            silentDuration += bufferDuration
            if silentDuration >= silenceTimeoutSeconds {
                hasFired = true
                logger.info("Silence timeout reached after \(self.silentDuration, format: .fixed(precision: 0))s")
                onSilenceTimeout?()
            }
        } else {
            if silentDuration > 5 {
                logger.debug("Silence broken after \(self.silentDuration, format: .fixed(precision: 0))s")
            }
            silentDuration = 0
        }
    }

    /// Reset state for a new recording session.
    func reset() {
        silentDuration = 0
        hasFired = false
    }

    // MARK: - Private

    private func calculateRMS(_ data: Data) -> Float {
        data.withUnsafeBytes { raw in
            guard let baseAddress = raw.baseAddress else { return 0 }
            let samples = baseAddress.assumingMemoryBound(to: Int16.self)
            let count = data.count / MemoryLayout<Int16>.size
            guard count > 0 else { return 0 }

            var sumOfSquares: Float = 0
            for i in 0..<count {
                let sample = Float(samples[i])
                sumOfSquares += sample * sample
            }
            return (sumOfSquares / Float(count)).squareRoot()
        }
    }
}
