import Foundation
import os.log
import SwiftUI

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "LicenseManager")

enum LicenseStatus: String {
    case free
    case licensed
}

/// Manages license state: free tier recording cap and LemonSqueezy license activation.
@MainActor
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()
    static let freeRecordingLimit = 10

    static let checkoutURL = URL(string: "https://store.fiddleheadai.com/checkout/buy/18ff7027-7060-4a0d-9fc3-099c2df5230c")!

    @AppStorage("totalRecordingCount") var totalRecordingCount: Int = 0
    @AppStorage("licenseStatus") private var licenseStatusRaw: String = LicenseStatus.free.rawValue

    /// Activation in progress
    @Published var isActivating = false
    /// Error message from last activation attempt
    @Published var activationError: String?

    private init() {}

    // MARK: - Computed Properties

    var licenseStatus: LicenseStatus {
        get { LicenseStatus(rawValue: licenseStatusRaw) ?? .free }
        set { licenseStatusRaw = newValue.rawValue }
    }

    var isLicensed: Bool { licenseStatus == .licensed }

    var canRecord: Bool {
        isLicensed || totalRecordingCount < Self.freeRecordingLimit
    }

    var recordingsRemaining: Int {
        max(0, Self.freeRecordingLimit - totalRecordingCount)
    }

    // MARK: - Actions

    func incrementRecordingCount() {
        guard !isLicensed else { return }
        totalRecordingCount += 1
        logger.info("Recording count: \(self.totalRecordingCount)/\(Self.freeRecordingLimit)")
    }

    /// Activate a license key via LemonSqueezy API.
    func activateLicense(_ key: String) async {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            activationError = "Please enter a license key"
            return
        }

        isActivating = true
        activationError = nil

        do {
            _ = try await LicenseValidator.activate(key: trimmed)
            // Store key in Keychain
            try KeychainManager.shared.save(key: .licenseKey, value: trimmed)
            licenseStatus = .licensed
            logger.info("License activated and stored")
        } catch {
            activationError = error.localizedDescription
            logger.error("Activation failed: \(error)")
        }

        isActivating = false
    }

    /// Re-validate the stored license key on app launch.
    func validateOnLaunch() {
        guard isLicensed, let key = KeychainManager.shared.retrieve(key: .licenseKey) else { return }

        Task {
            let valid = await LicenseValidator.validate(key: key)
            if !valid {
                logger.warning("License no longer valid — reverting to free")
                licenseStatus = .free
                KeychainManager.shared.delete(key: .licenseKey)
            }
        }
    }

    /// Open the LemonSqueezy checkout page in the default browser.
    func openCheckout() {
        // Append redirect URL for URL scheme callback
        var components = URLComponents(url: Self.checkoutURL, resolvingAgainstBaseURL: false)!
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(
            name: "checkout[custom][redirect_url]",
            value: "fiddlehead://activate"
        ))
        components.queryItems = queryItems

        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }
}
