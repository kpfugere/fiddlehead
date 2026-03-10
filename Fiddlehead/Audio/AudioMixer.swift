import Foundation

/// Mixes two mono Int16 PCM streams into a single output stream.
/// When `stereo` is false (default), sums both inputs into mono for voice-based diarization.
/// When `stereo` is true, interleaves mic (ch0) and system (ch1) for channel-based identification.
final class AudioMixer: @unchecked Sendable {
    private let lock = NSLock()
    private var micBuffer: [Int16] = []
    private var systemBuffer: [Int16] = []
    /// When true, output is stereo interleaved (mic=left, system=right) instead of mono sum.
    var stereo: Bool = false

    private var outputContinuation: AsyncStream<Data>.Continuation?
    private var _outputStream: AsyncStream<Data>?

    /// The mixed mono output stream.
    /// Must call prepareStream() before feeding audio to avoid race conditions.
    var outputStream: AsyncStream<Data> {
        if let existing = _outputStream { return existing }
        return prepareStream()
    }

    /// Eagerly create and cache the output stream + continuation.
    @discardableResult
    func prepareStream() -> AsyncStream<Data> {
        _outputStream = nil
        outputContinuation = nil
        let stream = AsyncStream<Data> { continuation in
            self.outputContinuation = continuation
        }
        _outputStream = stream
        return stream
    }

    /// Add microphone audio samples
    func addMicAudio(_ data: Data) {
        let samples = data.withUnsafeBytes { buffer -> [Int16] in
            Array(buffer.bindMemory(to: Int16.self))
        }

        lock.lock()
        micBuffer.append(contentsOf: samples)
        lock.unlock()

        mixAndOutput()
    }

    /// Add system audio samples
    func addSystemAudio(_ data: Data) {
        let samples = data.withUnsafeBytes { buffer -> [Int16] in
            Array(buffer.bindMemory(to: Int16.self))
        }

        lock.lock()
        systemBuffer.append(contentsOf: samples)
        lock.unlock()

        mixAndOutput()
    }

    /// Mix both buffers into the output stream (mono sum or stereo interleave).
    private func mixAndOutput() {
        lock.lock()

        let micCount = micBuffer.count
        let sysCount = systemBuffer.count

        // Output in chunks of at least 1600 samples (~100ms at 16kHz)
        let minChunkSize = 1600
        let available = max(micCount, sysCount)

        guard available >= minChunkSize else {
            lock.unlock()
            return
        }

        let samplesToMix = available
        let isStereo = stereo
        let bytesPerSample = MemoryLayout<Int16>.size
        var output = Data(capacity: samplesToMix * bytesPerSample * (isStereo ? 2 : 1))

        for i in 0..<samplesToMix {
            let mic = i < micCount ? Int32(micBuffer[i]) : 0
            let sys = i < sysCount ? Int32(systemBuffer[i]) : 0

            if isStereo {
                // Interleave: left=mic, right=system
                var micSample = Int16(clamping: mic)
                var sysSample = Int16(clamping: sys)
                withUnsafeBytes(of: &micSample) { output.append(contentsOf: $0) }
                withUnsafeBytes(of: &sysSample) { output.append(contentsOf: $0) }
            } else {
                var mixed = Int16(clamping: mic + sys)
                withUnsafeBytes(of: &mixed) { output.append(contentsOf: $0) }
            }
        }

        // Remove consumed samples
        if micCount > 0 {
            micBuffer.removeFirst(min(samplesToMix, micCount))
        }
        if sysCount > 0 {
            systemBuffer.removeFirst(min(samplesToMix, sysCount))
        }

        lock.unlock()

        outputContinuation?.yield(output)
    }

    /// Flush any remaining samples
    func flush() {
        lock.lock()
        let micCount = micBuffer.count
        let sysCount = systemBuffer.count
        let remaining = max(micCount, sysCount)
        let isStereo = stereo

        if remaining > 0 {
            let bytesPerSample = MemoryLayout<Int16>.size
            var output = Data(capacity: remaining * bytesPerSample * (isStereo ? 2 : 1))

            for i in 0..<remaining {
                let mic = i < micCount ? Int32(micBuffer[i]) : 0
                let sys = i < sysCount ? Int32(systemBuffer[i]) : 0

                if isStereo {
                    var micSample = Int16(clamping: mic)
                    var sysSample = Int16(clamping: sys)
                    withUnsafeBytes(of: &micSample) { output.append(contentsOf: $0) }
                    withUnsafeBytes(of: &sysSample) { output.append(contentsOf: $0) }
                } else {
                    var mixed = Int16(clamping: mic + sys)
                    withUnsafeBytes(of: &mixed) { output.append(contentsOf: $0) }
                }
            }

            micBuffer.removeAll()
            systemBuffer.removeAll()
            lock.unlock()

            outputContinuation?.yield(output)
        } else {
            lock.unlock()
        }

        outputContinuation?.finish()
        outputContinuation = nil
        _outputStream = nil
    }
}
