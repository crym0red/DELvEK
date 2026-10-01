import Foundation
import Security
import SideSign

/// DELvEK's Apple-account signing backend boundary.
///
/// This layer deliberately keeps the Apple password ephemeral: it is passed to the
/// authentication implementation by the caller and is never persisted by DELvEK.
/// SideSign supplies the real Apple GSA/developer-portal/certificate primitives;
/// this adapter owns DELvEK's state and Keychain storage around those primitives.
@MainActor
public final class DELvEKAppleSigningBackend {
    public static let shared = DELvEKAppleSigningBackend()

    public struct SessionState: Sendable, Equatable {
        public var appleID: String?
        public var authenticated: Bool
        public var teamID: String?
        public var certificatePrepared: Bool
        public var csrPrepared: Bool

        public init(appleID: String? = nil, authenticated: Bool = false, teamID: String? = nil, certificatePrepared: Bool = false, csrPrepared: Bool = false) {
            self.appleID = appleID
            self.authenticated = authenticated
            self.teamID = teamID
            self.certificatePrepared = certificatePrepared
            self.csrPrepared = csrPrepared
        }
    }

    private let service = "com.delvek.apple-signing"
    private let accountKey = "apple-id"
    private let csrKey = "development-csr"
    private let privateKeyKey = "development-private-key"

    private(set) var state: SessionState

    private init() {
        let appleID = Self.readKeychain(service: service, account: accountKey).flatMap { String(data: $0, encoding: .utf8) }
        let csr = Self.readKeychain(service: service, account: csrKey)
        state = SessionState(appleID: appleID, csrPrepared: csr != nil)
    }

    public func beginSession(appleID: String, password: String) async throws -> SessionState {
        let normalized = appleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.contains("@"), !password.isEmpty else {
            throw BackendError.invalidCredentials
        }

        // The password intentionally remains only in this call's stack/registers.
        // Do not write it to UserDefaults, files, analytics, or DELvEK's database.
        try Self.writeKeychain(Data(normalized.utf8), service: service, account: accountKey)

        // Generate the device-local key material needed for Apple's development
        // certificate request. The private key remains on this device.
        let request = try CertificateRequest(machineName: Host.current().localizedName ?? "DELvEK iPhone")
        try Self.writeKeychain(request.csrData, service: service, account: csrKey)
        try Self.writeKeychain(request.privateKey, service: service, account: privateKeyKey)

        state.appleID = normalized
        state.csrPrepared = true
        state.authenticated = false
        state.certificatePrepared = false
        return state
    }

    public func signOut() {
        Self.deleteKeychain(service: service, account: accountKey)
        Self.deleteKeychain(service: service, account: csrKey)
        Self.deleteKeychain(service: service, account: privateKeyKey)
        state = SessionState()
    }

    public func storedAppleID() -> String? { state.appleID }

    public func hasPreparedCSR() -> Bool { state.csrPrepared }

    public enum BackendError: LocalizedError {
        case invalidCredentials
        case unavailable
        case authenticationNotConnected

        public var errorDescription: String? {
            switch self {
            case .invalidCredentials: return "Enter a valid Apple ID and password."
            case .unavailable: return "The Apple signing backend is unavailable."
            case .authenticationNotConnected:
                return "The Apple GSA/developer-portal session has not completed yet. The generated CSR and device key are ready for that authenticated session."
            }
        }
    }

    private static func writeKeychain(_ data: Data, service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let match: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            let update: [String: Any] = [kSecValueData as String: data]
            guard SecItemUpdate(match as CFDictionary, update as CFDictionary) == errSecSuccess else {
                throw NSError(domain: "DELvEKAppleSigning", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Unable to update signing state in Keychain."])
            }
        } else if status != errSecSuccess {
            throw NSError(domain: "DELvEKAppleSigning", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Unable to store signing state in Keychain."])
        }
    }

    private static func readKeychain(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func deleteKeychain(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
