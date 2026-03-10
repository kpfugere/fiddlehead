import SwiftUI

enum TranscriptionProvider: String, CaseIterable, Identifiable {
    case openai = "openai"
    case assemblyai = "assemblyai"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: "OpenAI"
        case .assemblyai: "AssemblyAI"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("speakerName") var speakerName = ""
    @AppStorage("systemAudioEnabled") var systemAudioEnabled = true
    @AppStorage("keepAudioEnabled") var keepAudioEnabled = false
    @AppStorage("saveLocationPath") var saveLocationPath = ""
    @AppStorage("openAIAPIKey") var openAIAPIKey = ""
    @AppStorage("assemblyAIAPIKey") var assemblyAIAPIKey = ""
    @AppStorage("transcriptionProvider") var transcriptionProviderRaw = TranscriptionProvider.openai.rawValue
    @AppStorage("calendarEnabled") var calendarEnabled = false
    @AppStorage("silenceTimeoutMinutes") var silenceTimeoutMinutes = 3
    @AppStorage("autoModeEnabled") var autoModeEnabled = false
    @AppStorage("autoModeMaxRecordingMinutes") var autoModeMaxRecordingMinutes = 120

    var transcriptionProvider: TranscriptionProvider {
        get { TranscriptionProvider(rawValue: transcriptionProviderRaw) ?? .openai }
        set { transcriptionProviderRaw = newValue.rawValue }
    }

    var hasAPIKeys: Bool {
        // OpenAI key is always required (for structuring), plus the selected transcription provider's key
        guard !openAIAPIKey.isEmpty else { return false }
        switch transcriptionProvider {
        case .openai: return true
        case .assemblyai: return !assemblyAIAPIKey.isEmpty
        }
    }

    /// One-time migration: move API keys from Keychain to UserDefaults
    func migrateFromKeychainIfNeeded() {
        let keychain = KeychainManager.shared
        if let key = keychain.retrieve(key: .deepgramAPIKey), !key.isEmpty {
            keychain.delete(key: .deepgramAPIKey)
        }
        if let key = keychain.retrieve(key: .claudeAPIKey), !key.isEmpty {
            keychain.delete(key: .claudeAPIKey)
        }
    }

    // MARK: - Save Location

    var saveLocation: URL {
        if !saveLocationPath.isEmpty {
            return URL(fileURLWithPath: saveLocationPath)
        }
        return defaultSaveLocation
    }

    var defaultSaveLocation: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents")
            .appendingPathComponent("Fiddlehead")
    }

    func ensureSaveLocationExists() {
        let fm = FileManager.default
        let url = saveLocation
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    func updateSaveLocation(_ url: URL) {
        saveLocationPath = url.path
        // Store security-scoped bookmark for sandbox
        BookmarkManager.shared.saveBookmark(for: url)
    }
}
