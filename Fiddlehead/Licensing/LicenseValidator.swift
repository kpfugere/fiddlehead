import Foundation
import IOKit
import os.log

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "LicenseValidator")

enum LicenseValidationError: LocalizedError {
    case invalidKey
    case networkError(String)
    case serverError(String)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidKey: "Invalid license key"
        case .networkError(let msg): "Network error: \(msg)"
        case .serverError(let msg): "Server error: \(msg)"
        case .decodingError: "Failed to parse license response"
        }
    }
}

/// Communicates with the LemonSqueezy license API to activate and validate license keys.
enum LicenseValidator {
    private static let activateURL = URL(string: "https://api.lemonsqueezy.com/v1/licenses/activate")!
    private static let validateURL = URL(string: "https://api.lemonsqueezy.com/v1/licenses/validate")!

    /// Activate a license key against this machine. Returns the license instance ID on success.
    static func activate(key: String) async throws -> String {
        let fingerprint = machineFingerprint()
        let body: [String: String] = [
            "license_key": key,
            "instance_name": fingerprint
        ]

        var request = URLRequest(url: activateURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await performRequest(request)

        guard let http = response as? HTTPURLResponse else {
            throw LicenseValidationError.networkError("Invalid response")
        }

        let decoded = try JSONDecoder().decode(LemonSqueezyResponse.self, from: data)

        if http.statusCode == 200, decoded.activated == true {
            logger.info("License activated successfully")
            return decoded.instance?.id ?? ""
        }

        let errorMsg = decoded.error ?? "Activation failed (HTTP \(http.statusCode))"
        logger.error("License activation failed: \(errorMsg)")
        throw LicenseValidationError.invalidKey
    }

    /// Validate an already-activated license key. Returns true if the key is still valid.
    static func validate(key: String) async -> Bool {
        let fingerprint = machineFingerprint()
        let body: [String: String] = [
            "license_key": key,
            "instance_name": fingerprint
        ]

        var request = URLRequest(url: validateURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await performRequest(request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return false
            }
            let decoded = try JSONDecoder().decode(LemonSqueezyResponse.self, from: data)
            let valid = decoded.valid == true
            logger.info("License validation: \(valid ? "valid" : "invalid")")
            return valid
        } catch {
            logger.error("License validation network error: \(error)")
            // On network failure, assume valid to avoid blocking offline users
            return true
        }
    }

    // MARK: - Private

    private static func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw LicenseValidationError.networkError(error.localizedDescription)
        }
    }

    /// Hardware UUID from IOKit — stable machine fingerprint.
    static func machineFingerprint() -> String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }

        guard let uuidData = IORegistryEntryCreateCFProperty(
            service,
            "IOPlatformUUID" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String else {
            return "unknown-\(ProcessInfo.processInfo.hostName)"
        }
        return uuidData
    }
}

// MARK: - LemonSqueezy API Response

private struct LemonSqueezyResponse: Decodable {
    let valid: Bool?
    let activated: Bool?
    let error: String?
    let instance: Instance?

    struct Instance: Decodable {
        let id: String
    }
}
