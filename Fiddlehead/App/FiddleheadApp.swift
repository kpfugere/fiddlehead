import Combine
import SwiftUI

@main
struct FiddleheadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var pipeline = RecordingPipeline()
    @StateObject private var settings = AppSettings()
    @StateObject private var autoMode = AutoModeController()
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var licenseManager = LicenseManager.shared
    @StateObject private var updateController = UpdateController()

    private let onboardingController = OnboardingWindowController()
    private let settingsController = SettingsWindowController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(openSettingsAction: { settingsController.show(settings: settings) })
                .environmentObject(pipeline)
                .environmentObject(settings)
                .environmentObject(autoMode)
                .environmentObject(licenseManager)
                .environmentObject(updateController)
                .onAppear {
                    settings.migrateFromKeychainIfNeeded()
                    pipeline.configure(settings: settings)
                    autoMode.configure(settings: settings)
                    appDelegate.registerHotkey(pipeline: pipeline, autoMode: autoMode)
                    onboardingController.showIfNeeded(settings: settings)
                    coordinator.setup(pipeline: pipeline, autoMode: autoMode, settings: settings)
                    licenseManager.validateOnLaunch()
                    updateController.startIfNeeded()
                }
                .onOpenURL { url in
                    guard url.scheme == "fiddlehead",
                          url.host == "activate",
                          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                          let key = components.queryItems?.first(where: { $0.name == "license_key" })?.value
                    else { return }
                    Task { await licenseManager.activateLicense(key) }
                }
        } label: {
            MenuBarLabel(
                isRecording: pipeline.isRecording || autoMode.state == .recording,
                isProcessing: !pipeline.activeJobs.isEmpty
            )
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - App Coordinator

/// Bridges Combine observation between MeetingMonitor, RecordingPipeline, and the prompt panel.
/// Needed because SwiftUI's App struct can't store AnyCancellable sets.
@MainActor
final class AppCoordinator: ObservableObject {
    let meetingMonitor = MeetingMonitor()
    let meetingPromptController = MeetingPromptController()
    private var cancellables = Set<AnyCancellable>()

    func setup(pipeline: RecordingPipeline, autoMode: AutoModeController, settings: AppSettings) {
        // Apply initial calendar state
        applyCalendarSetting(settings.calendarEnabled)

        // Restore auto mode on launch if previously enabled
        if settings.autoModeEnabled {
            autoMode.enable()
            pipeline.autoModeActive = true
        }

        // Observe calendarEnabled setting → start/stop monitoring
        // Also observe autoModeEnabled → enable/disable auto mode
        // @AppStorage doesn't expose a Combine publisher, so observe objectWillChange
        var lastCalendarEnabled = settings.calendarEnabled
        var lastAutoModeEnabled = settings.autoModeEnabled
        settings.objectWillChange
            .sink { [weak self, weak settings, weak autoMode, weak pipeline] _ in
                guard let self, let settings, let autoMode, let pipeline else { return }
                // objectWillChange fires before the change, so defer the check
                DispatchQueue.main.async {
                    let currentCalendar = settings.calendarEnabled
                    if currentCalendar != lastCalendarEnabled {
                        lastCalendarEnabled = currentCalendar
                        self.applyCalendarSetting(currentCalendar)
                    }

                    let currentAutoMode = settings.autoModeEnabled
                    if currentAutoMode != lastAutoModeEnabled {
                        lastAutoModeEnabled = currentAutoMode
                        if currentAutoMode {
                            autoMode.enable()
                            pipeline.autoModeActive = true
                        } else {
                            autoMode.disable()
                            pipeline.autoModeActive = false
                        }
                    }
                }
            }
            .store(in: &cancellables)

        // Observe isShowingPrompt → show/hide the floating panel
        meetingMonitor.$isShowingPrompt
            .removeDuplicates()
            .sink { [weak self] showing in
                guard let self else { return }
                if showing, let meeting = self.meetingMonitor.upcomingMeeting {
                    self.meetingPromptController.show(
                        meeting: meeting,
                        onAccept: { [weak self] in
                            guard let self else { return }
                            self.meetingMonitor.acceptMeeting(meeting)
                            pipeline.startRecording(for: meeting)
                            if let videoURL = meeting.videoURL {
                                NSWorkspace.shared.open(videoURL)
                            }
                        },
                        onDismiss: { [weak self] in
                            self?.meetingMonitor.dismissMeeting(meeting)
                        }
                    )
                } else if !showing {
                    self.meetingPromptController.dismiss()
                }
            }
            .store(in: &cancellables)

        // Observe pipeline state → notify meetingMonitor when recording ends
        pipeline.$state
            .sink { [weak self] state in
                if case .idle = state {
                    self?.meetingMonitor.recordingEnded()
                }
            }
            .store(in: &cancellables)
    }

    private func applyCalendarSetting(_ enabled: Bool) {
        if enabled {
            meetingMonitor.startMonitoring()
        } else {
            meetingMonitor.stopMonitoring()
            meetingPromptController.dismiss()
        }
    }
}

/// Menu bar icon — custom fiddlehead fern with recording indicator.
private struct MenuBarLabel: View {
    let isRecording: Bool
    let isProcessing: Bool

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 4) {
            Image("MenuBarIcon")
                .renderingMode(.template)

            if isRecording {
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
                    .opacity(pulse ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
                    .onDisappear { pulse = false }
            } else if isProcessing {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
            }
        }
    }
}
