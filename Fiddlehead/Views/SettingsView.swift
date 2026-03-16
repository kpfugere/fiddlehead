import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var openAIKey = ""
    @State private var showOpenAIKey = false
    @State private var assemblyAIKey = ""
    @State private var showAssemblyAIKey = false
    @State private var hasScreenRecordingPermission = false
    @State private var openAIEdited = false
    @State private var assemblyAIEdited = false
    @State private var licenseKey = ""
    @State private var showLicenseKeyEntry = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Storage
                settingsSection("storage") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("save location")
                            .font(FiddleheadTheme.mono(12, weight: .medium))
                            .foregroundStyle(FiddleheadTheme.textPrimary)

                        HStack {
                            Text(settings.saveLocation.path)
                                .font(FiddleheadTheme.monoFixed(11))
                                .foregroundStyle(FiddleheadTheme.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button("change...") {
                                pickSaveLocation()
                            }
                            .font(FiddleheadTheme.mono(11))
                        }

                        Toggle("keep audio files", isOn: $settings.keepAudioEnabled)
                            .font(FiddleheadTheme.mono(12))
                            .foregroundStyle(FiddleheadTheme.textPrimary)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                }

                // MARK: - Recording
                settingsSection("recording") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("capture system audio", isOn: $settings.systemAudioEnabled)
                            .font(FiddleheadTheme.mono(12))
                            .foregroundStyle(FiddleheadTheme.textPrimary)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .onChange(of: settings.systemAudioEnabled) { _, enabled in
                                if enabled {
                                    SystemAudioCapture.requestPermission()
                                    checkScreenRecordingPermission()
                                }
                            }

                        if settings.systemAudioEnabled {
                            if hasScreenRecordingPermission {
                                Text("✓ screen recording permission granted")
                                    .font(FiddleheadTheme.mono(10))
                                    .foregroundStyle(.green.opacity(0.8))
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("⚠ screen recording permission required")
                                        .font(FiddleheadTheme.mono(10))
                                        .foregroundStyle(.orange.opacity(0.9))

                                    Text("fiddlehead needs this to capture audio from calls and other apps.")
                                        .font(FiddleheadTheme.mono(10))
                                        .foregroundStyle(FiddleheadTheme.textSecondary)

                                    Button("open system settings →") {
                                        NSWorkspace.shared.open(
                                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                                        )
                                    }
                                    .font(FiddleheadTheme.mono(11))

                                    Text("after enabling, restart fiddlehead.")
                                        .font(FiddleheadTheme.mono(10))
                                        .foregroundStyle(FiddleheadTheme.textSecondary)
                                }
                            }
                        }
                    }
                }

                // MARK: - Auto Mode
                settingsSection("auto mode") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("enable auto mode", isOn: $settings.autoModeEnabled)
                            .font(FiddleheadTheme.mono(12))
                            .foregroundStyle(FiddleheadTheme.textPrimary)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .disabled(!settings.hasAPIKeys)

                        Text("detects when a call app opens your microphone and automatically records, transcribes, and saves notes. screen recording permission is only needed during recording, not during detection.")
                            .font(FiddleheadTheme.mono(10))
                            .foregroundStyle(FiddleheadTheme.textSecondary)

                        if !settings.hasAPIKeys {
                            Text("requires an openai api key")
                                .font(FiddleheadTheme.mono(10))
                                .foregroundStyle(.orange.opacity(0.9))
                        }
                    }
                }

                // MARK: - Calendar
                settingsSection("calendar") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("detect upcoming meetings", isOn: $settings.calendarEnabled)
                            .font(FiddleheadTheme.mono(12))
                            .foregroundStyle(FiddleheadTheme.textPrimary)
                            .toggleStyle(.switch)
                            .controlSize(.small)

                        Text("reads events from calendars configured in system settings")
                            .font(FiddleheadTheme.mono(10))
                            .foregroundStyle(FiddleheadTheme.textSecondary)

                        if settings.calendarEnabled {
                            Text("prompts 1 minute before meetings with 2+ attendees and a video link")
                                .font(FiddleheadTheme.mono(10))
                                .foregroundStyle(FiddleheadTheme.textSecondary)

                            HStack(spacing: 4) {
                                Text("add calendars in")
                                    .font(FiddleheadTheme.mono(10))
                                    .foregroundStyle(FiddleheadTheme.textSecondary)
                                Text("system settings → internet accounts")
                                    .font(FiddleheadTheme.mono(10, weight: .medium))
                                    .foregroundStyle(FiddleheadTheme.accent)
                                    .onTapGesture {
                                        if let url = URL(string: "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }
                                Image(systemName: "arrow.up.forward")
                                    .font(.system(size: 8))
                                    .foregroundStyle(FiddleheadTheme.accent)
                            }
                        }

                        HStack {
                            Text("silence auto-stop")
                                .font(FiddleheadTheme.mono(12))
                                .foregroundStyle(FiddleheadTheme.textPrimary)

                            Spacer()

                            Picker("", selection: $settings.silenceTimeoutMinutes) {
                                Text("off").tag(0)
                                Text("2 min").tag(2)
                                Text("3 min").tag(3)
                                Text("5 min").tag(5)
                                Text("10 min").tag(10)
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                        }

                        Text("auto-stops recording after sustained silence")
                            .font(FiddleheadTheme.mono(10))
                            .foregroundStyle(FiddleheadTheme.textSecondary)
                    }
                }

                // MARK: - API Keys
                settingsSection("api keys") {
                    VStack(alignment: .leading, spacing: 12) {
                        apiKeyField(
                            label: "openai — note structuring",
                            key: $openAIKey,
                            isVisible: $showOpenAIKey,
                            edited: $openAIEdited,
                            realKey: settings.openAIAPIKey,
                            onCommit: { settings.openAIAPIKey = openAIKey }
                        )

                        Divider()

                        apiKeyField(
                            label: "assemblyai — transcription",
                            key: $assemblyAIKey,
                            isVisible: $showAssemblyAIKey,
                            edited: $assemblyAIEdited,
                            realKey: settings.assemblyAIAPIKey,
                            onCommit: { settings.assemblyAIAPIKey = assemblyAIKey }
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("speech model")
                                .font(FiddleheadTheme.mono(11, weight: .medium))
                                .foregroundStyle(FiddleheadTheme.textPrimary)

                            Picker("", selection: $settings.assemblyAISpeechModel) {
                                Text("universal-2").tag("universal-2")
                                Text("universal-3-pro").tag("universal-3-pro")
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            Text(settings.assemblyAISpeechModel == "universal-3-pro"
                                ? "higher accuracy for en, es, pt, fr, de, it. falls back to universal-2 for other languages. costs more."
                                : "supports 99 languages at standard pricing."
                            )
                                .font(FiddleheadTheme.mono(10))
                                .foregroundStyle(FiddleheadTheme.textSecondary)
                        }
                    }
                }

                // MARK: - Speaker
                settingsSection("speaker name") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("your name", text: $settings.speakerName)
                            .textFieldStyle(.roundedBorder)
                            .font(FiddleheadTheme.mono(12))

                        Text("used to label your mic channel in transcripts.")
                            .font(FiddleheadTheme.mono(10))
                            .foregroundStyle(FiddleheadTheme.textSecondary)
                    }
                }

                // MARK: - License
                settingsSection("license") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("status")
                                .font(FiddleheadTheme.mono(12, weight: .medium))
                                .foregroundStyle(FiddleheadTheme.textPrimary)

                            Spacer()

                            Text(licenseManager.isLicensed ? "licensed" : "free")
                                .font(FiddleheadTheme.mono(12))
                                .foregroundStyle(licenseManager.isLicensed ? FiddleheadTheme.saved : FiddleheadTheme.textSecondary)
                        }

                        if !licenseManager.isLicensed {
                            HStack {
                                Text("recordings used")
                                    .font(FiddleheadTheme.mono(12))
                                    .foregroundStyle(FiddleheadTheme.textPrimary)

                                Spacer()

                                Text("\(licenseManager.totalRecordingCount) / \(LicenseManager.freeRecordingLimit)")
                                    .font(FiddleheadTheme.monoFixed(12))
                                    .foregroundStyle(
                                        licenseManager.canRecord
                                            ? FiddleheadTheme.textSecondary
                                            : FiddleheadTheme.recording
                                    )
                            }

                            Button(action: { licenseManager.openCheckout() }) {
                                Text("unlock fiddlehead — $29")
                                    .font(FiddleheadTheme.mono(12, weight: .medium))
                                    .foregroundStyle(FiddleheadTheme.background)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(FiddleheadTheme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: FiddleheadTheme.cornerRadius))
                            }
                            .buttonStyle(.plain)

                            if showLicenseKeyEntry {
                                HStack(spacing: 8) {
                                    TextField("license key", text: $licenseKey)
                                        .textFieldStyle(.roundedBorder)
                                        .font(FiddleheadTheme.monoFixed(11))
                                        .onSubmit {
                                            guard !licenseKey.isEmpty else { return }
                                            Task { await licenseManager.activateLicense(licenseKey) }
                                        }

                                    if licenseManager.isActivating {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Button("activate") {
                                            Task { await licenseManager.activateLicense(licenseKey) }
                                        }
                                        .font(FiddleheadTheme.mono(11))
                                        .disabled(licenseKey.isEmpty)
                                    }
                                }

                                if let error = licenseManager.activationError {
                                    Text(error)
                                        .font(FiddleheadTheme.mono(10))
                                        .foregroundStyle(FiddleheadTheme.recording)
                                }
                            } else {
                                Button("i have a license key") {
                                    showLicenseKeyEntry = true
                                }
                                .font(FiddleheadTheme.mono(11))
                                .foregroundStyle(FiddleheadTheme.accent)
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // MARK: - About
                settingsSection("about") {
                    Text("fiddlehead v0.1.0")
                        .font(FiddleheadTheme.mono(11))
                        .foregroundStyle(FiddleheadTheme.textSecondary)
                }
            }
            .padding(24)
        }
        .frame(width: 420, height: 640)
        .onAppear {
            checkScreenRecordingPermission()
        }
    }

    // MARK: - Components

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(FiddleheadTheme.mono(10, weight: .bold))
                .foregroundStyle(FiddleheadTheme.textSecondary)
                .tracking(1.5)

            content()
        }
    }

    /// API key field with separate display/edit modes.
    /// The real key is NEVER placed into a text field unless the user clicks "change".
    /// This prevents masked values from overwriting the real key.
    private func apiKeyField(
        label: String,
        key: Binding<String>,
        isVisible: Binding<Bool>,
        edited: Binding<Bool>,
        realKey: String,
        onCommit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(FiddleheadTheme.mono(11, weight: .medium))
                .foregroundStyle(FiddleheadTheme.textPrimary)

            if edited.wrappedValue {
                // EDIT MODE: user is entering a new key
                HStack(spacing: 8) {
                    TextField("paste new api key", text: key)
                        .textFieldStyle(.roundedBorder)
                        .font(FiddleheadTheme.monoFixed(11))
                        .onSubmit {
                            guard !key.wrappedValue.isEmpty else { return }
                            onCommit()
                            edited.wrappedValue = false
                        }

                    Button("save") {
                        onCommit()
                        edited.wrappedValue = false
                    }
                    .font(FiddleheadTheme.mono(11))
                    .disabled(key.wrappedValue.isEmpty)

                    Button("cancel") {
                        key.wrappedValue = ""
                        edited.wrappedValue = false
                    }
                    .font(FiddleheadTheme.mono(10))
                    .foregroundStyle(FiddleheadTheme.textSecondary)
                    .buttonStyle(.plain)
                }
            } else {
                // DISPLAY MODE: read-only, no text field bound to key
                HStack(spacing: 8) {
                    if realKey.isEmpty {
                        Text("not configured")
                            .font(FiddleheadTheme.monoFixed(11))
                            .foregroundStyle(FiddleheadTheme.textSecondary.opacity(0.5))
                    } else if isVisible.wrappedValue {
                        Text(realKey)
                            .font(FiddleheadTheme.monoFixed(11))
                            .foregroundStyle(FiddleheadTheme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    } else {
                        Text(maskedKey(realKey))
                            .font(FiddleheadTheme.monoFixed(11))
                            .foregroundStyle(FiddleheadTheme.textSecondary)
                    }

                    Spacer()

                    if !realKey.isEmpty {
                        Button(isVisible.wrappedValue ? "hide" : "show") {
                            isVisible.wrappedValue.toggle()
                        }
                        .font(FiddleheadTheme.mono(10))
                        .foregroundStyle(FiddleheadTheme.textSecondary)
                        .buttonStyle(.plain)
                    }

                    Button(realKey.isEmpty ? "add key" : "change") {
                        key.wrappedValue = ""
                        edited.wrappedValue = true
                        isVisible.wrappedValue = false
                    }
                    .font(FiddleheadTheme.mono(10))
                    .foregroundStyle(FiddleheadTheme.accent)
                    .buttonStyle(.plain)
                }
            }

            if !realKey.isEmpty && !edited.wrappedValue {
                Text("✓ configured")
                    .font(FiddleheadTheme.mono(10))
                    .foregroundStyle(FiddleheadTheme.saved)
            }
        }
    }

    // MARK: - Helpers

    private func maskedKey(_ key: String) -> String {
        guard key.count > 8 else { return String(repeating: "•", count: key.count) }
        let suffix = String(key.suffix(4))
        return String(repeating: "•", count: 8) + suffix
    }

    private func checkScreenRecordingPermission() {
        hasScreenRecordingPermission = SystemAudioCapture.hasPermission
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
