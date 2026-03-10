import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var permissions = PermissionManager()

    // Step order: 0=Welcome, 1=Permissions, 2=API Key, 3=Save Location
    @State private var step = 0
    @State private var openAIKey = ""
    @State private var speakerName = ""

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<4) { i in
                    Text(i <= step ? "●" : "○")
                        .font(FiddleheadTheme.mono(8))
                        .foregroundStyle(i <= step ? FiddleheadTheme.accent : FiddleheadTheme.textSecondary.opacity(0.3))
                }
            }
            .padding(.top, 24)

            Spacer()

            // Step content
            Group {
                switch step {
                case 0: welcomeStep
                case 1: permissionsStep
                case 2: apiKeysStep
                case 3: saveLocationStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)

            Spacer()

            // Navigation
            HStack {
                if step > 0 {
                    Button("← back") {
                        saveKeysIfNeeded()
                        withAnimation { step -= 1 }
                    }
                    .buttonStyle(.plain)
                    .font(FiddleheadTheme.mono(12))
                    .foregroundStyle(FiddleheadTheme.textSecondary)
                }

                Spacer()

                Button(step == 3 ? "get started →" : "continue →") {
                    advance()
                }
                .buttonStyle(.borderedProminent)
                .tint(FiddleheadTheme.recording)
                .font(FiddleheadTheme.mono(12, weight: .medium))
                .disabled(!canAdvance)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 480, height: 400)
        .background(FiddleheadTheme.background)
        .onAppear {
            permissions.checkPermissions()
            openAIKey = settings.openAIAPIKey
            speakerName = settings.speakerName
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Text("~")
                .font(FiddleheadTheme.mono(48, weight: .light))
                .foregroundStyle(FiddleheadTheme.accent)

            Text("fiddlehead")
                .font(FiddleheadTheme.mono(24, weight: .bold))
                .foregroundStyle(FiddleheadTheme.textPrimary)

            Text("record meetings and conversations.\ntranscribed and structured automatically.")
                .font(FiddleheadTheme.mono(13))
                .foregroundStyle(FiddleheadTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("permissions")
                .font(FiddleheadTheme.mono(20, weight: .bold))
                .foregroundStyle(FiddleheadTheme.textPrimary)

            Text("microphone access is required. system audio capture needs screen recording permission — you may need to restart after granting it.")
                .font(FiddleheadTheme.mono(12))
                .foregroundStyle(FiddleheadTheme.textSecondary)
                .lineSpacing(2)

            VStack(spacing: 12) {
                permissionRow(
                    glyph: "◉",
                    title: "microphone",
                    granted: permissions.microphoneGranted,
                    action: {
                        Task {
                            _ = await permissions.requestMicrophone()
                        }
                    }
                )

                permissionRow(
                    glyph: "◉",
                    title: "screen recording (system audio)",
                    granted: permissions.screenCaptureGranted,
                    action: {
                        permissions.openScreenCaptureSettings()
                    }
                )
            }

            Text("screen recording is optional — skip to record mic only.")
                .font(FiddleheadTheme.mono(10))
                .foregroundStyle(FiddleheadTheme.textSecondary)
                .padding(.top, 4)
        }
    }

    private var apiKeysStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("api key")
                .font(FiddleheadTheme.mono(20, weight: .bold))
                .foregroundStyle(FiddleheadTheme.textPrimary)

            Text("openai handles both transcription and note structuring. your key is stored locally.")
                .font(FiddleheadTheme.mono(12))
                .foregroundStyle(FiddleheadTheme.textSecondary)
                .lineSpacing(2)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("openai api key")
                        .font(FiddleheadTheme.mono(11, weight: .medium))
                        .foregroundStyle(FiddleheadTheme.textPrimary)
                    SecureField("sk-...", text: $openAIKey)
                        .textFieldStyle(.roundedBorder)
                        .font(FiddleheadTheme.monoFixed(11))
                        .onChange(of: openAIKey) { saveKeysIfNeeded() }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("your name (optional)")
                        .font(FiddleheadTheme.mono(11, weight: .medium))
                        .foregroundStyle(FiddleheadTheme.textPrimary)
                    TextField("labels your mic channel", text: $speakerName)
                        .textFieldStyle(.roundedBorder)
                        .font(FiddleheadTheme.mono(11))
                        .onChange(of: speakerName) { settings.speakerName = speakerName }
                }
            }
        }
    }

    private var saveLocationStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("save location")
                .font(FiddleheadTheme.mono(20, weight: .bold))
                .foregroundStyle(FiddleheadTheme.textPrimary)

            Text("choose where notes are saved. default: ~/Documents/Fiddlehead")
                .font(FiddleheadTheme.mono(12))
                .foregroundStyle(FiddleheadTheme.textSecondary)
                .lineSpacing(2)

            HStack {
                Text("▸")
                    .font(FiddleheadTheme.mono(12))
                    .foregroundStyle(FiddleheadTheme.accent)
                Text(settings.saveLocation.path)
                    .font(FiddleheadTheme.monoFixed(11))
                    .foregroundStyle(FiddleheadTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(12)
            .background(FiddleheadTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: FiddleheadTheme.cornerRadius))

            Button("change location...") {
                pickSaveLocation()
            }
            .font(FiddleheadTheme.mono(12))

            Text("ready. press ⌘⇧R from any app to start recording.")
                .font(FiddleheadTheme.mono(12, weight: .medium))
                .foregroundStyle(FiddleheadTheme.saved)
                .padding(.top, 8)
        }
    }

    // MARK: - Helpers

    private func permissionRow(
        glyph: String,
        title: String,
        granted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(glyph)
                .font(FiddleheadTheme.mono(12))
                .foregroundStyle(granted ? FiddleheadTheme.saved : FiddleheadTheme.textSecondary)
                .frame(width: 24)

            Text(title)
                .font(FiddleheadTheme.mono(12))
                .foregroundStyle(FiddleheadTheme.textPrimary)

            Spacer()

            if granted {
                Text("✓")
                    .font(FiddleheadTheme.mono(14, weight: .bold))
                    .foregroundStyle(FiddleheadTheme.saved)
            } else {
                Button("grant") { action() }
                    .font(FiddleheadTheme.mono(11))
                    .buttonStyle(.borderedProminent)
                    .tint(FiddleheadTheme.recording)
                    .controlSize(.small)
            }
        }
        .padding(10)
        .background(FiddleheadTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FiddleheadTheme.cornerRadius))
    }

    private var canAdvance: Bool {
        switch step {
        case 2: !openAIKey.isEmpty
        default: true
        }
    }

    private func saveKeysIfNeeded() {
        if !openAIKey.isEmpty {
            settings.openAIAPIKey = openAIKey
        }
    }

    private func advance() {
        switch step {
        case 2:
            saveKeysIfNeeded()
            if !speakerName.isEmpty {
                settings.speakerName = speakerName
            }
            withAnimation { step += 1 }

        case 3:
            settings.ensureSaveLocationExists()
            settings.hasCompletedOnboarding = true
            onComplete()

        default:
            withAnimation { step += 1 }
        }
    }

    private func pickSaveLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose where Fiddlehead saves your notes"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            settings.updateSaveLocation(url)
        }
    }
}
