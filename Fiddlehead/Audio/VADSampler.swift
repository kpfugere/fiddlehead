import CoreAudio
import os.log

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "VAD")

/// Monitors whether the default input audio device is in use by any process.
/// When a call app (Zoom, Teams, Meet) opens the mic, fires `onVoiceDetected`.
/// Uses CoreAudio property listener — zero permissions, zero indicators.
final class VADSampler: @unchecked Sendable {
    private var isRunning = false
    private var listenerInstalled = false
    private var currentInputDeviceID: AudioDeviceID = kAudioObjectUnknown

    /// Delay (seconds) after mic becomes active before firing callback.
    /// Prevents false triggers from brief mic access (e.g., permission checks).
    private let activationDelay: TimeInterval = 3.0
    private var activationTask: Task<Void, Never>?

    /// Called on the main actor when a call is detected (mic opened by another app).
    var onVoiceDetected: (@MainActor () -> Void)?

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let deviceID = getDefaultInputDevice()
        guard deviceID != kAudioObjectUnknown else {
            logger.warning("VAD: No default input device found")
            return
        }
        currentInputDeviceID = deviceID
        installListener(on: deviceID)

        // Also listen for default device changes (e.g., user switches mic)
        installDefaultDeviceListener()

        // Check current state immediately — if mic is already active (e.g., call in progress)
        if isDeviceRunning(deviceID) {
            logger.info("VAD: Mic already active on start — scheduling activation")
            scheduleActivation()
        }

        logger.info("VAD started — monitoring mic activity on device \(deviceID)")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        activationTask?.cancel()
        activationTask = nil
        removeListener()
        removeDefaultDeviceListener()
        currentInputDeviceID = kAudioObjectUnknown
        logger.info("VAD stopped")
    }

    // MARK: - CoreAudio Helpers

    private func getDefaultInputDevice() -> AudioDeviceID {
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )
        return status == noErr ? deviceID : kAudioObjectUnknown
    }

    private func isDeviceRunning(_ deviceID: AudioDeviceID) -> Bool {
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &size, &running
        )
        return status == noErr && running != 0
    }

    // MARK: - Property Listeners

    private var runningListenerBlock: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?

    private func installListener(on deviceID: AudioDeviceID) {
        removeListener()

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self, self.isRunning else { return }
            let running = self.isDeviceRunning(deviceID)
            logger.info("VAD: Mic device running changed → \(running)")

            if running {
                self.scheduleActivation()
            } else {
                self.cancelActivation()
            }
        }
        runningListenerBlock = block

        let status = AudioObjectAddPropertyListenerBlock(
            deviceID, &address, DispatchQueue.main, block
        )
        if status == noErr {
            listenerInstalled = true
        } else {
            logger.warning("VAD: Failed to install running listener: \(status)")
        }
    }

    private func removeListener() {
        guard listenerInstalled, currentInputDeviceID != kAudioObjectUnknown,
              let block = runningListenerBlock else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            currentInputDeviceID, &address, DispatchQueue.main, block
        )
        runningListenerBlock = nil
        listenerInstalled = false
    }

    private func installDefaultDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self, self.isRunning else { return }
            let newDevice = self.getDefaultInputDevice()
            guard newDevice != self.currentInputDeviceID else { return }

            logger.info("VAD: Default input device changed → \(newDevice)")
            self.removeListener()
            self.currentInputDeviceID = newDevice
            if newDevice != kAudioObjectUnknown {
                self.installListener(on: newDevice)
            }
        }
        defaultDeviceListenerBlock = block

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address, DispatchQueue.main, block
        )
    }

    private func removeDefaultDeviceListener() {
        guard let block = defaultDeviceListenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address, DispatchQueue.main, block
        )
        defaultDeviceListenerBlock = nil
    }

    // MARK: - Activation Delay

    private func scheduleActivation() {
        activationTask?.cancel()
        activationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(self?.activationDelay ?? 3))
            guard let self, self.isRunning, !Task.isCancelled else { return }
            // Verify mic is still active after delay
            guard self.isDeviceRunning(self.currentInputDeviceID) else {
                logger.info("VAD: Mic no longer active after delay — ignoring")
                return
            }
            logger.info("VAD: Mic confirmed active for \(self.activationDelay)s — triggering")
            self.stop()
            self.onVoiceDetected?()
        }
    }

    private func cancelActivation() {
        activationTask?.cancel()
        activationTask = nil
    }
}
