import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private let hotkeyManager = GlobalHotkeyManager()
    nonisolated(unsafe) var pipeline: RecordingPipeline?
    nonisolated(unsafe) var autoMode: AutoModeController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hotkey registered when pipeline is set via registerHotkey()
        Task { @MainActor in
            let settings = AppSettings()
            settings.ensureSaveLocationExists()
        }
    }

    func registerHotkey(pipeline: RecordingPipeline, autoMode: AutoModeController) {
        self.pipeline = pipeline
        self.autoMode = autoMode
        let pipelineRef = pipeline
        hotkeyManager.register {
            Task { @MainActor in
                pipelineRef.toggleRecording()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop any in-progress recording to flush audio and close WebSocket cleanly
        if let pipeline {
            Task { @MainActor in
                if pipeline.isRecording {
                    pipeline.stopRecording()
                }
            }
        }
        if let autoMode {
            Task { @MainActor in
                autoMode.disable()
            }
        }
        hotkeyManager.unregister()
    }
}
