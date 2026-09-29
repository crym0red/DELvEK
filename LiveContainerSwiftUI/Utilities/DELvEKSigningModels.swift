import Foundation

/// The nine-stage DELvEK device/signing pipeline.
public enum DELvEKSigningPhase: Int, CaseIterable, Identifiable, Codable {
    case pairing = 1
    case deviceIdentity = 2
    case appleSession = 3
    case developmentIdentity = 4
    case provisioning = 5
    case signer = 6
    case localAPI = 7
    case jit = 8
    case runtime = 9

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .pairing: return "RSD/CoreDevice Pairing"
        case .deviceIdentity: return "Device Identity"
        case .appleSession: return "Apple Account Session"
        case .developmentIdentity: return "Development Signing Identity"
        case .provisioning: return "Provisioning Profile"
        case .signer: return "DELvEK Signer"
        case .localAPI: return "Local API / LocalDevVPN"
        case .jit: return "StikJIT / iOS 26.x"
        case .runtime: return "Installation / Runtime"
        }
    }
}

public enum DELvEKStatusState: String, Codable {
    case unavailable
    case needsSetup
    case ready
    case error
}

public struct DELvEKPairingStatus: Codable, Equatable {
    public var isStored: Bool
    public var isValid: Bool
    public var udid: String?
    public var sourceName: String?
    public var format: String

    public init(isStored: Bool = false, isValid: Bool = false, udid: String? = nil, sourceName: String? = nil, format: String = "Unknown") {
        self.isStored = isStored
        self.isValid = isValid
        self.udid = udid
        self.sourceName = sourceName
        self.format = format
    }
}

public struct DELvEKCertificateStatus: Codable, Equatable {
    public var commonName: String?
    public var teamIdentifier: String?
    public var expiration: Date?
    public var isInstalled: Bool

    public init(commonName: String? = nil, teamIdentifier: String? = nil, expiration: Date? = nil, isInstalled: Bool = false) {
        self.commonName = commonName
        self.teamIdentifier = teamIdentifier
        self.expiration = expiration
        self.isInstalled = isInstalled
    }
}

public struct DELvEKProvisioningStatus: Codable, Equatable {
    public var appIdentifier: String?
    public var teamIdentifier: String?
    public var expiration: Date?
    public var devices: [String]
    public var isValid: Bool

    public init(appIdentifier: String? = nil, teamIdentifier: String? = nil, expiration: Date? = nil, devices: [String] = [], isValid: Bool = false) {
        self.appIdentifier = appIdentifier
        self.teamIdentifier = teamIdentifier
        self.expiration = expiration
        self.devices = devices
        self.isValid = isValid
    }
}

public struct DELvEKSigningSnapshot: Codable, Equatable {
    public var pairing: DELvEKPairingStatus
    public var certificate: DELvEKCertificateStatus
    public var provisioning: DELvEKProvisioningStatus
    public var localAPIReady: Bool
    public var developerModeKnown: Bool
    public var developerModeEnabled: Bool?

    public init(
        pairing: DELvEKPairingStatus = .init(),
        certificate: DELvEKCertificateStatus = .init(),
        provisioning: DELvEKProvisioningStatus = .init(),
        localAPIReady: Bool = false,
        developerModeKnown: Bool = false,
        developerModeEnabled: Bool? = nil
    ) {
        self.pairing = pairing
        self.certificate = certificate
        self.provisioning = provisioning
        self.localAPIReady = localAPIReady
        self.developerModeKnown = developerModeKnown
        self.developerModeEnabled = developerModeEnabled
    }
}
