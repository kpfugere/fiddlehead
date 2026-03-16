import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var pipeline: RecordingPipeline
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var autoMode: AutoModeController
    @EnvironmentObject var licenseManager: LicenseManager
    @EnvironmentObject var updateController: UpdateController

    var openSettingsAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            statusSection
            divider
            recentSection
            divider
            footerSection
        }
        .frame(width: FiddleheadTheme.popoverWidth)
        .background(FiddleheadTheme.background)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: FiddleheadTheme.paddingMedium) {
            HStack(spacing: 8) {
                statusIndicator
                statusText
                Spacer()
            }

            actionButton

            if !pipeline.activeJobs.isEmpty {
                activeJobsIndicator
            }
        }
        .padding(FiddleheadTheme.paddingLarge)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        Text(statusGlyph)
            .font(FiddleheadTheme.mono(10))
            .foregroundStyle(dotColor)
    }

    private var statusGlyph: String {
        if autoMode.state.isActive {
            switch autoMode.state {
            case .listening: return "◌"
            case .recording: return "●"
            case .processing: return "◎"
            case .cooldown: return "◌"
            case .error: return "✗"
            case .disabled: return "○"
            }
        }
        switch pipeline.state {
        case .recording: return "●"
        case .error: return "✗"
        default:
            return !pipeline.activeJobs.isEmpty ? "◎" : "○"
        }
    }

    private var dotColor: Color {
        if autoMode.state.isActive {
            switch autoMode.state {
            case .listening, .cooldown: return FiddleheadTheme.accent.opacity(0.6)
            case .recording: return FiddleheadTheme.recording
            case .processing: return FiddleheadTheme.accent
            case .error: return FiddleheadTheme.recording
            case .disabled: return FiddleheadTheme.textSecondary.opacity(0.5)
            }
        }
        switch pipeline.state {
        case .recording: return FiddleheadTheme.recording
        case .error: return FiddleheadTheme.recording
        default:
            return !pipeline.activeJobs.isEmpty ? FiddleheadTheme.accent : FiddleheadTheme.textSecondary.opacity(0.5)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        if autoMode.state.isActive {
            autoModeStatusText
        } else {
            manualStatusText
        }
    }

    @ViewBuilder
    private var autoModeStatusText: some View {
        switch autoMode.state {
        case .listening, .cooldown:
            Text("auto scribing")
                .font(FiddleheadTheme.mono(13, weight: .medium))
                .foregroundStyle(FiddleheadTheme.textPrimary)

        case .recording:
            HStack(spacing: 8) {
                Text("auto scribing")
                    .font(FiddleheadTheme.mono(13, weight: .medium))
                    .foregroundStyle(FiddleheadTheme.recording)
                Text(formattedAutoRecDuration)
                    .font(FiddleheadTheme.monoFixed(13))
                    .foregroundStyle(FiddleheadTheme.textSecondary)
            }

        case .processing:
            Text("auto scribing — processing")
                .font(FiddleheadTheme.mono(13, weight: .medium))
                .foregroundStyle(FiddleheadTheme.accent)

        case let .error(message):
            Text("auto — \(message.lowercased())")
                .font(FiddleheadTheme.mono(11))
                .foregroundStyle(FiddleheadTheme.recording)
                .lineLimit(2)

        case .disabled:
            EmptyView()
        }
    }

    @ViewBuilder
    private var manualStatusText: some View {
        switch pipeline.state {
        case .idle:
            Text("ready")
                .font(FiddleheadTheme.mono(13, weight: .medium))
                .foregroundStyle(FiddleheadTheme.textPrimary)

        case .recording:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("rec")
                        .font(FiddleheadTheme.mono(13, weight: .medium))
                        .foregroundStyle(FiddleheadTheme.recording)
                    Text(formattedDuration)
                        .font(FiddleheadTheme.monoFixed(13))
                        .foregroundStyle(FiddleheadTheme.textSecondary)
                }
                if settings.systemAudioEnabled && !pipeline.audioCaptureManager.systemAudioActive {
                    Text("mic only — system audio unavailable")
                        .font(FiddleheadTheme.mono(9))
                        .foregroundStyle(.orange.opacity(0.8))
                }
            }

        case let .error(message):
            Text(message.lowercased())
                .font(FiddleheadTheme.mono(11))
                .foregroundStyle(FiddleheadTheme.recording)
                .lineLimit(2)

        default:
            // .processing and .completed no longer used by the pipeline directly
            Text("ready")
                .font(FiddleheadTheme.mono(13, weight: .medium))
                .foregroundStyle(FiddleheadTheme.textPrimary)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if pipeline.isRecording {
            Button(action: { pipeline.toggleRecording() }) {
                HStack(spacing: 8) {
                    Text("■")
                        .font(FiddleheadTheme.mono(12))
                    Text("stop")
                        .font(FiddleheadTheme.mono(14, weight: .medium))
                }
                .foregroundStyle(FiddleheadTheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(FiddleheadTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: FiddleheadTheme.cornerRadius))
            }
            .buttonStyle(.plain)
        } else if autoMode.state.isActive {
            // Auto mode is running — show status instead of manual record button
            Button(action: { settings.autoModeEnabled = false }) {
                HStack(spacing: 8) {
                    Text("■")
                        .font(FiddleheadTheme.mono(12))
                    Text("stop auto mode")
                        .font(FiddleheadTheme.mono(14, weight: .medium))
                }
                .foregroundStyle(FiddleheadTheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(FiddleheadTheme.textSecondary)
                .clipShape(RoundedRectangle(cornerRadius: FiddleheadTheme.cornerRadius))
            }
            .buttonStyle(.plain)
        } else if !licenseManager.canRecord {
            Button(action: { licenseManager.openCheckout() }) {
                Text("upgrade to record")
                    .font(FiddleheadTheme.mono(14, weight: .medium))
                    .foregroundStyle(FiddleheadTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(FiddleheadTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: FiddleheadTheme.cornerRadius))
            }
            .buttonStyle(.plain)
        } else {
            Button(action: { pipeline.toggleRecording() }) {
                HStack(spacing: 8) {
                    Text("●")
                        .font(FiddleheadTheme.mono(10))
                    Text("take notes")
                        .font(FiddleheadTheme.mono(14, weight: .medium))
                }
                .foregroundStyle(FiddleheadTheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(FiddleheadTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: FiddleheadTheme.cornerRadius))
            }
            .buttonStyle(.plain)

            if !licenseManager.isLicensed {
                Text("\(licenseManager.recordingsRemaining) of \(LicenseManager.freeRecordingLimit) free")
                    .font(FiddleheadTheme.mono(10))
                    .foregroundStyle(FiddleheadTheme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var activeJobsIndicator: some View {
        let jobs = pipeline.activeJobs
        let count = jobs.count
        let label: String = {
            if count == 1, let job = jobs.first {
                return job.stage.label.lowercased()
            } else {
                return "processing \(count) notes..."
            }
        }()
        let progress: Double = {
            if count == 1, let job = jobs.first {
                return job.stage.progress
            } else {
                return jobs.map(\.stage.progress).reduce(0, +) / Double(max(count, 1))
            }
        }()

        VStack(spacing: 4) {
            ProgressView(value: progress)
                .tint(FiddleheadTheme.accent)
            Text(label)
                .font(FiddleheadTheme.mono(10))
                .foregroundStyle(FiddleheadTheme.textSecondary)
        }
    }

    // MARK: - Recent Section

    private var recentSection: some View {
        // `savedNoteCount` dependency forces refresh after a new note is saved
        let _ = pipeline.savedNoteCount
        return RecentNotesList(
            notes: NoteStorage.recentNotes(from: settings.saveLocation, limit: 5)
        )
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 0) {
            // Auto mode toggle row
            if !pipeline.isRecording {
                HStack {
                    Text("auto mode")
                        .font(FiddleheadTheme.mono(12))
                        .foregroundStyle(FiddleheadTheme.textPrimary)

                    Spacer()

                    Toggle("", isOn: $settings.autoModeEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .disabled(!settings.hasAPIKeys)
                }
                .padding(.horizontal, FiddleheadTheme.paddingLarge)
                .padding(.vertical, FiddleheadTheme.paddingSmall)

                Rectangle()
                    .fill(FiddleheadTheme.border)
                    .frame(height: 1)
            }

            HStack {
                Button(action: openSettingsAction) {
                    HStack(spacing: 4) {
                        Text("⚙")
                            .font(FiddleheadTheme.mono(11))
                        Text("settings")
                            .font(FiddleheadTheme.mono(12))
                    }
                    .foregroundStyle(FiddleheadTheme.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { updateController.checkForUpdates() }) {
                    Text("check for updates")
                        .font(FiddleheadTheme.mono(12))
                        .foregroundStyle(FiddleheadTheme.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("⌘Q quit")
                        .font(FiddleheadTheme.mono(12))
                        .foregroundStyle(FiddleheadTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
            }
            .padding(.horizontal, FiddleheadTheme.paddingLarge)
            .padding(.vertical, FiddleheadTheme.paddingMedium)
        }
    }

    // MARK: - Helpers

    private var divider: some View {
        Rectangle()
            .fill(FiddleheadTheme.border)
            .frame(height: 1)
    }

    private var formattedDuration: String {
        let minutes = Int(pipeline.recordingDuration) / 60
        let seconds = Int(pipeline.recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var formattedAutoRecDuration: String {
        let minutes = Int(autoMode.currentRecordingDuration) / 60
        let seconds = Int(autoMode.currentRecordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
