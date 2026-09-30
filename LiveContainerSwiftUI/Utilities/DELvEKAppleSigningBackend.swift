import Foundation
import Security
#if canImport(SideSign)
import SideSign
#endif

/// Secure Apple-signing preparation layer.
///
/// SideSign supplies CSR generation, Apple authentication/developer-portal,
/// certificate/profile and bundle-signing primitives. DELvEK owns orchestration
/// and secure state; the Apple password is never persisted.
@MainActor
public final class DELvEKAppleSigningBackend: ObservableObject {
    public static let shared = DELvEKAppleSigningBackend()

    @Published public private(set) var account: String?
    @Published public private(set) var csrReady = false
    @Published public private(set) var lastError: String?

    private let keychain = DELvEKKeychain()
    private let csrKey = "delvek.signing.csr"
    private let privateKeyKey = "delvek.signing.privateKey"

    private init() {
        csrReady = keychain.data(for: privateKeyKey) != nil && keychain.data(for: csrKey) != nil
    }

    public func prepareAccount(_ appleID: String) throws {
        let normalized = appleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.contains("@") else {
            throw BackendError.invalidAppleID
        }
        account = normalized
    }

    /// Generates the local private key + CSR required by Apple's development
    /// certificate request. The Apple password is deliberately not an argument.
    public func prepareCSR() throws {
        #if canImport(SideSign)
        let request = try CertificateRequest(machineName: "DELvEK")
        try keychain.set(request.csrData, for: csrKey)
        try keychain.set(request.privateKey, for: privateKeyKey)
        csrReady = true
        #else
        throw BackendError.sideSignUnavailable
        #endif
    }

    public func clearSession() {
        account = nil
        lastError = nil
    }

    public enum BackendError: LocalizedError {
        case invalidAppleID
        case sideSignUnavailable
        public var errorDescription: String? {
            switch self {
            case .invalidAppleID: return "Enter a valid Apple ID email address."
            case .sideSignUnavailable: return "The SideSign package is not linked to this target."
            }
        }
    }
}

private final class DELvEKKeychain {
    func data(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.delvek.signing",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    func set(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.delvek.signing",
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus)) }
        } else if status != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}
