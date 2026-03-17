import AppKit
import SwiftUI

/// Opens the onboarding wizard as a proper NSWindow.
/// LSUIElement apps need manual window management + temporary activation
/// to keep focus on input fields.
@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?

    func showIfNeeded(settings: AppSettings) {
        guard !settings.hasCompletedOnboarding else { return }
        guard window == nil else { return }

        let view = OnboardingView {
            settings.hasCompletedOnboarding = true
            self.close()
        }
        .environmentObject(settings)

        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to Fiddlehead"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 480, height: 400))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
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
