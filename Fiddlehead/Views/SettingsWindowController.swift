import AppKit
import SwiftUI

/// Opens the settings panel as a proper NSWindow.
/// LSUIElement apps can't use SwiftUI's `Settings` scene reliably —
/// `@Environment(\.openSettings)` ends up opening macOS System Settings.
/// This controller manages a dedicated window instead.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(settings: AppSettings) {
        // If already open, just bring to front
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let view = SettingsView()
            .environmentObject(settings)
            .environmentObject(LicenseManager.shared)

        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Fiddlehead Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 420, height: 640))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.delegate = WindowCloseDelegate.shared
        self.window = window

        // Temporarily become a regular app so the window can receive focus
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func close() {
        window?.close()
        window = nil
        // Return to accessory (menu bar only) mode
        NSApp.setActivationPolicy(.accessory)
    }
}

/// Restores accessory activation policy when the settings window is closed via the title bar.
private final class WindowCloseDelegate: NSObject, NSWindowDelegate, @unchecked Sendable {
    static let shared = WindowCloseDelegate()

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
