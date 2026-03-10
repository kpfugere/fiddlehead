import AppKit
import SwiftUI

/// Manages the floating meeting prompt panel that appears below the menu bar.
/// Uses NSPanel with `.nonactivatingPanel` to avoid stealing focus from video call apps.
@MainActor
final class MeetingPromptController {
    private var panel: NSPanel?
    private var autoDismissTask: Task<Void, Never>?

    /// Show the meeting prompt panel.
    func show(
        meeting: MeetingEvent,
        onAccept: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        dismiss()

        let view = MeetingPromptView(
            meeting: meeting,
            onAccept: { [weak self] in
                self?.dismiss()
                onAccept()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
                onDismiss()
            }
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 110)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 110),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.contentView = hostingView

        // Position: centered horizontally, just below menu bar
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let x = screenFrame.midX - 150
            let y = screenFrame.maxY - 28 - 110
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.panel = panel

        // Fade in
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 1
        }

        // Auto-dismiss after 30 seconds
        autoDismissTask = Task {
            try? await Task.sleep(for: .seconds(30))
            if self.panel != nil {
                onDismiss()
                self.dismiss()
            }
        }
    }

    /// Hide and clean up the panel.
    func dismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil

        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel?.close()
            self?.panel = nil
        })
    }
}

// MARK: - SwiftUI View

private struct MeetingPromptView: View {
    let meeting: MeetingEvent
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Meeting info
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title.lowercased())
                    .font(FiddleheadTheme.mono(13, weight: .medium))
                    .foregroundStyle(FiddleheadTheme.textPrimary)
                    .lineLimit(2)

                Text(subtitle)
                    .font(FiddleheadTheme.mono(11))
                    .foregroundStyle(FiddleheadTheme.textSecondary)
            }

            Spacer()

            // Actions
            VStack(spacing: 8) {
                Button(action: onAccept) {
                    HStack(spacing: 6) {
                        Text("●")
                            .font(FiddleheadTheme.mono(8))
                        Text("take notes")
                            .font(FiddleheadTheme.mono(12, weight: .medium))
                    }
                    .foregroundStyle(FiddleheadTheme.background)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(FiddleheadTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: FiddleheadTheme.cornerRadius))
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Text("dismiss")
                        .font(FiddleheadTheme.mono(10))
                        .foregroundStyle(FiddleheadTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: FiddleheadTheme.cornerRadiusLarge)
                .fill(FiddleheadTheme.surface)
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: FiddleheadTheme.cornerRadiusLarge)
                        .stroke(FiddleheadTheme.border, lineWidth: 1)
                )
        )
    }

    private var subtitle: String {
        let seconds = meeting.secondsUntilStart()
        let timeText: String
        if seconds > 60 {
            timeText = "in \(Int(seconds / 60)) min"
        } else if seconds > 0 {
            timeText = "in <1 min"
        } else {
            timeText = "now"
        }
        return "\(timeText) · \(meeting.attendeeCount) attendees"
    }
}
