import Foundation
import os.log

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "Silence")

/// Monitors PCM audio buffers for sustained silence and fires a callback
/// when the silence duration exceeds a configurable timeout.
///
/// Channel-aware: when fed a stereo interleaved buffer (mic = left, system = right,
/// as produced by `AudioMixer` in stereo mode), the two channels are measured
/// independently. This matters for auto-stop after a meeting ends: the remote
/// (system) audio truly drops to ~0, while the local mic keeps capturing ambient
/// room noise. We only count silence when *both* the mic is below a noise-floor
/// threshold AND the system channel is quiet — so the always-on mic's ambient
/// noise can no longer keep a finished meeting recording alive forever.
@MainActor
final class SilenceDetector {
    /// RMS threshold for the microphone / local channel.
    /// Set above the ambient room-noise floor (HVAC, typing, breathing, fans),
    /// which typically sits around -50 dB for a laptop mic. ~400 ≈ -38 dB;
    /// normal speech is roughly -20..-30 dB and clears this comfortably.
    private let micSilenceThreshold: Float = 400

    /// RMS threshold for the system-audio (remote) channel. Captured system audio
    /// is ~0 when no app produces output, so this stays low. ~150 ≈ -46 dB.
    private let systemSilenceThreshold: Float = 150

    /// Duration in seconds of continuous silence before triggering.
    var silenceTimeoutSeconds: TimeInterval = 180

    /// Called once when silence exceeds the timeout. Reset clears the fired state.
    var onSilenceTimeout: (() -> Void)?

    private var silentDuration: TimeInterval = 0
    private var hasFired = false

    /// Expected sample rate — used to convert buffer size to duration.
    private let sampleRate: Double = 16000

    /// Number of audio channels (1=mono, 2=stereo). Affects buffer duration calculation
    /// and selects mono vs. per-channel silence measurement.
    var channels: Int = 1

    /// Process a buffer of Int16 PCM audio. Call this for every audio chunk.
    func processBuffer(_ data: Data) {
        guard !hasFired else { return }

        let isSilent: Bool
        if channels == 2 {
            // Stereo interleaved: left = mic (even idx), right = system (odd idx).
            // A meeting that has ended = remote (system) silent AND only mic ambient noise.
            let (micRMS, systemRMS) = calculateStereoRMS(data)
            isSilent = micRMS < micSilenceThreshold && systemRMS < systemSilenceThreshold
        } else {
            // Mono: either mic-only or a mic+system mixdown. Ambient room noise on the
            // mic must fall below the raised threshold to count as silence.
            let rms = calculateRMS(data)
            isSilent = rms < micSilenceThreshold
        }

        let frameCount = data.count / (2 * channels)
        let bufferDuration = Double(frameCount) / sampleRate

        if isSilent {
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

    /// RMS over all samples (mono buffers, or a stereo buffer treated as a single stream).
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

    /// Separate RMS for the mic (left/even) and system (right/odd) channels of a
    /// stereo interleaved Int16 buffer.
    private func calculateStereoRMS(_ data: Data) -> (mic: Float, system: Float) {
        data.withUnsafeBytes { raw in
            guard let baseAddress = raw.baseAddress else { return (0, 0) }
            let samples = baseAddress.assumingMemoryBound(to: Int16.self)
            let count = data.count / MemoryLayout<Int16>.size
            guard count > 1 else { return (0, 0) }

            var micSumSq: Float = 0
            var systemSumSq: Float = 0
            var frames = 0
            var i = 0
            while i + 1 < count {
                let mic = Float(samples[i])
                let system = Float(samples[i + 1])
                micSumSq += mic * mic
                systemSumSq += system * system
                frames += 1
                i += 2
            }
            guard frames > 0 else { return (0, 0) }
            let micRMS = (micSumSq / Float(frames)).squareRoot()
            let systemRMS = (systemSumSq / Float(frames)).squareRoot()
            return (micRMS, systemRMS)
        }
    }
}
