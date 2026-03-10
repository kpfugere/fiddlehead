import Carbon
import AppKit

/// Registers a global hotkey (⌘⇧R) using the Carbon Event API.
/// This is the only reliable method for global hotkeys on macOS.
final class GlobalHotkeyManager: @unchecked Sendable {
    private var eventHandler: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    private let hotkeyID = EventHotKeyID(signature: OSType(0x46444C48), id: 1) // "FDLH"
    private var callback: (() -> Void)?

    func register(callback: @escaping () -> Void) {
        self.callback = callback

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Install handler
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotkey()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard status == noErr else { return }

        // Register ⌘⇧R
        // R key = kVK_ANSI_R = 0x0F
        var hotkeyRef: EventHotKeyRef?
        RegisterEventHotKey(
            UInt32(kVK_ANSI_R),
            UInt32(cmdKey | shiftKey),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        self.hotkeyRef = hotkeyRef
    }

    func unregister() {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        callback = nil
    }

    private func handleHotkey() {
        DispatchQueue.main.async { [weak self] in
            self?.callback?()
        }
    }

    deinit {
        unregister()
    }
}
