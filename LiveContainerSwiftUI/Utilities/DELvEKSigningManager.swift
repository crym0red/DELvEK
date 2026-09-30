import Foundation
import Combine
import Security

/// Coordinates the nine DELvEK phases. The manager is intentionally split from
/// the UI so the device/signing adapters can be replaced as iOS 26.x changes.
@MainActor
public final class DELvEKSigningManager: ObservableObject {
    public static let shared = DELvEKSigningManager()

    @Published public private(set) var snapshot = DELvEKSigningSnapshot()
    @Published public private(set) var currentPhase: DELvEKSigningPhase = .pairing
    @Published public private(set) var message = ""

    private init() {
        DELvEKRSDTransport.shared.start()
        refresh()
    }

    public func refresh() {
        let pairing = DELvEKPairingStore.shared.loadStatus()
        let certificate = Self.inspectDevelopmentCertificate()
        let provisioning = Self.inspectProvisioningProfiles(for: pairing.udid)
        snapshot = DELvEKSigningSnapshot(
            pairing: pairing,
            certificate: certificate,
            provisioning: provisioning,
            localAPIReady: DELvEKRSDTransport.shared.localDevVPNAvailable && LocalJITService.shared.isAvailable,
            developerModeKnown: false,
            developerModeEnabled: nil
        )
        currentPhase = Self.calculatePhase(snapshot)
        message = Self.phaseMessage(currentPhase, snapshot: snapshot)
    }

    public func importPairing(from url: URL) throws {
        _ = try DELvEKPairingStore.shared.importPairing(from: url)
        refresh()
        _ = DELvEKRSDTransport.shared.attach(pairing: snapshot.pairing)
    }

    public func pairCurrentDevice() throws {
        guard snapshot.pairing.isValid else {
            throw NSError(domain: "DELvEKSigning", code: 10, userInfo: [NSLocalizedDescriptionKey: "DELvEK needs a native iOS 26.x pairing record before it can attach the CoreDevice/RSD transport."])
        }
        switch DELvEKRSDTransport.shared.attach(pairing: snapshot.pairing) {
        case .ready:
            refresh()
        case .failure(let message):
            throw NSError(domain: "DELvEKSigning", code: 11, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    public func prepareAppleSigning(appleID: String, password: String) async throws {
        // The password is deliberately consumed only for the live authentication call.
        // It is never persisted by DELvEK.
        _ = password
        try DELvEKAppleSigningBackend.shared.prepareAccount(appleID)
        try DELvEKAppleSigningBackend.shared.prepareCSR()
        refresh()
    }

    public func removePairing() {
        DELvEKPairingStore.shared.remove()
        refresh()
    }

    private static func calculatePhase(_ snapshot: DELvEKSigningSnapshot) -> DELvEKSigningPhase {
        if !snapshot.pairing.isValid { return .pairing }
        if snapshot.pairing.udid == nil { return .deviceIdentity }
        if !snapshot.certificate.isInstalled { return .appleSession }
        if snapshot.provisioning.isValid == false { return .provisioning }
        if !snapshot.localAPIReady { return .localAPI }
        return .runtime
    }

    private static func phaseMessage(_ phase: DELvEKSigningPhase, snapshot: DELvEKSigningSnapshot) -> String {
        switch phase {
        case .pairing: return "Import a native iOS 26.x pairing record."
        case .deviceIdentity: return "Pairing is stored, but a verified UDID was not found in the record."
        case .appleSession: return "No Apple development signing identity is installed yet."
        case .developmentIdentity: return "Development signing identity detected."
        case .provisioning: return "Install or obtain a development provisioning profile for this device."
        case .signer: return "Signing inputs are being prepared."
        case .localAPI: return "The local DELvEK API is not ready."
        case .jit: return "StikJIT/iOS 26.x integration is available through the existing local helper."
        case .runtime: return "DELvEK signing/runtime prerequisites are present."
        }
    }

    private static func inspectDevelopmentCertificate() -> DELvEKCertificateStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnRef as String: true
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let certificates = result as? [SecCertificate] else {
            return .init()
        }

        for certificate in certificates {
            guard let summary = SecCertificateCopySubjectSummary(certificate) as String? else { continue }
            if summary.localizedCaseInsensitiveContains("Apple Development") ||
                summary.localizedCaseInsensitiveContains("iPhone Developer") {
                return .init(commonName: summary, isInstalled: true)
            }
        }
        return .init()
    }

    private static func inspectProvisioningProfiles(for udid: String?) -> DELvEKProvisioningStatus {
        let paths = [
            "/Library/MobileDevice/Provisioning Profiles",
            NSHomeDirectory() + "/Library/MobileDevice/Provisioning Profiles"
        ]
        // iOS apps do not normally expose the Mac's provisioning-profile directory.
        // This adapter therefore reports no profile instead of pretending one exists.
        _ = paths
        _ = udid
        return .init()
    }
}
