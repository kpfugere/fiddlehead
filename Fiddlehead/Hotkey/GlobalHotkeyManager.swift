import AppKit

/// Registers a global hotkey (⌘⇧R) using NSEvent monitors.
final class GlobalHotkeyManager: @unchecked Sendable {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var callback: (() -> Void)?

    func register(callback: @escaping () -> Void) {
        self.callback = callback

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleEvent(event) == true {
                return nil // Consume the event
            }
            return event
        }
    }

    func unregister() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        callback = nil
    }

    /// Returns true if the event matched ⌘⇧R and was handled.
    @discardableResult
    private func handleEvent(_ event: NSEvent) -> Bool {
        // ⌘⇧R: keyCode 0x0F = R
        let required: NSEvent.ModifierFlags = [.command, .shift]
        guard event.keyCode == 0x0F,
              event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(required)
        else { return false }

        DispatchQueue.main.async { [weak self] in
            self?.callback?()
        }
        return true
    }

    deinit {
        unregister()
    }
}
