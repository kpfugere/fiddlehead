import AVFoundation
@preconcurrency import ScreenCaptureKit
import TelemetryDeck

@MainActor
final class PermissionManager: ObservableObject {
    @Published var microphoneGranted = false
    @Published var screenCaptureGranted = false

    func checkPermissions() {
        checkMicrophone()
        Task { await checkScreenCapture() }
    }

    // MARK: - Microphone

    func checkMicrophone() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneGranted = true
        case .notDetermined:
            microphoneGranted = false
        case .denied, .restricted:
            microphoneGranted = false
        @unknown default:
            microphoneGranted = false
        }
    }

    func requestMicrophone() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphoneGranted = granted
        TelemetryDeck.signal("permissionResult", parameters: [
            "type": "microphone",
            "granted": "\(granted)",
        ])
        return granted
    }

    // MARK: - Screen Capture (for system audio)

    func checkScreenCapture() async {
        do {
            // Attempting to get shareable content tests the permission
            _ = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: false
            )
            screenCaptureGranted = true
            TelemetryDeck.signal("permissionResult", parameters: [
                "type": "screenCapture",
                "granted": "true",
            ])
        } catch {
            screenCaptureGranted = false
            TelemetryDeck.signal("permissionResult", parameters: [
                "type": "screenCapture",
                "granted": "false",
            ])
        }
    }

    func openScreenCaptureSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
