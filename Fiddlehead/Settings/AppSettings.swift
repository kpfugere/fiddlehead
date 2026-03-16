import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("speakerName") var speakerName = ""
    @AppStorage("systemAudioEnabled") var systemAudioEnabled = true
    @AppStorage("keepAudioEnabled") var keepAudioEnabled = false
    @AppStorage("saveLocationPath") var saveLocationPath = ""
    @AppStorage("openAIAPIKey") var openAIAPIKey = ""
    @AppStorage("assemblyAIAPIKey") var assemblyAIAPIKey = ""
    @AppStorage("calendarEnabled") var calendarEnabled = false
    @AppStorage("silenceTimeoutMinutes") var silenceTimeoutMinutes = 3
    @AppStorage("autoModeEnabled") var autoModeEnabled = false
    @AppStorage("autoModeMaxRecordingMinutes") var autoModeMaxRecordingMinutes = 120
    @AppStorage("assemblyAISpeechModel") var assemblyAISpeechModel = "universal-2"

    /// The `speech_models` array sent to AssemblyAI.
    /// For universal-3-pro we include universal-2 as a fallback for unsupported languages.
    var assemblyAISpeechModels: [String] {
        if assemblyAISpeechModel == "universal-3-pro" {
            return ["universal-3-pro", "universal-2"]
        }
        return ["universal-2"]
    }

    var hasAPIKeys: Bool {
        !openAIAPIKey.isEmpty && !assemblyAIAPIKey.isEmpty
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
        NoteStorage.ensureClaudeSkill(in: url)
    }

    func updateSaveLocation(_ url: URL) {
        saveLocationPath = url.path
        // Store security-scoped bookmark for sandbox
        BookmarkManager.shared.saveBookmark(for: url)
    }
}
