import Foundation

/// Stores a user-supplied native device pairing record without rewriting it.
///
/// iOS 26.x uses the RSD/CoreDevice-era pairing flow. DELvEK deliberately keeps
/// the pairing blob opaque here: the transport adapter can evolve independently
/// without converting an RSD record into the legacy Lockdown format.
public final class DELvEKPairingStore {
    public static let shared = DELvEKPairingStore()

    private let fileManager = FileManager.default
    private let directoryName = "DELvEK/DevicePairing"
    private let fileName = "pairing-record.plist"

    private init() {}

    public var directoryURL: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    public var pairingURL: URL {
        directoryURL.appendingPathComponent(fileName)
    }

    public var exists: Bool {
        fileManager.fileExists(atPath: pairingURL.path)
    }

    public func importPairing(from source: URL) throws -> DELvEKPairingStatus {
        guard source.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "DELvEKPairing", code: 1, userInfo: [NSLocalizedDescriptionKey: "DELvEK could not access the selected pairing record."])
        }
        defer { source.stopAccessingSecurityScopedResource() }

        let data = try Data(contentsOf: source)
        guard !data.isEmpty else {
            throw NSError(domain: "DELvEKPairing", code: 2, userInfo: [NSLocalizedDescriptionKey: "The pairing record is empty."])
        }

        // Validate that this is a property-list based pairing record, but do not
        // mutate its schema. RSD/CoreDevice records can contain keys unknown to us.
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dictionary = object as? [String: Any], !dictionary.isEmpty else {
            throw NSError(domain: "DELvEKPairing", code: 3, userInfo: [NSLocalizedDescriptionKey: "The pairing record is not a valid property-list dictionary."])
        }

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let temporary = directoryURL.appendingPathComponent("pairing-record.tmp")
        try data.write(to: temporary, options: .atomic)
        if exists { try fileManager.removeItem(at: pairingURL) }
        try fileManager.moveItem(at: temporary, to: pairingURL)

        let udid = Self.findUDID(in: dictionary)
        let format = Self.detectFormat(in: dictionary)
        return DELvEKPairingStatus(isStored: true, isValid: true, udid: udid, sourceName: source.lastPathComponent, format: format)
    }

    public func loadStatus() -> DELvEKPairingStatus {
        guard exists, let data = try? Data(contentsOf: pairingURL) else { return .init() }
        guard let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = object as? [String: Any], !dictionary.isEmpty else {
            return .init(isStored: true, isValid: false)
        }
        return DELvEKPairingStatus(
            isStored: true,
            isValid: true,
            udid: Self.findUDID(in: dictionary),
            sourceName: pairingURL.lastPathComponent,
            format: Self.detectFormat(in: dictionary)
        )
    }

    public func remove() {
        try? fileManager.removeItem(at: pairingURL)
    }

    private static func detectFormat(in dictionary: [String: Any]) -> String {
        let keys = Set(dictionary.keys.map { $0.lowercased() })
        if keys.contains("rsd") || keys.contains("rsdpairing") || keys.contains("remote_secure") || keys.contains("remote secure") {
            return "RSD/CoreDevice"
        }
        if keys.contains("devicecertificate") || keys.contains("hostcertificate") || keys.contains("systembuid") {
            return "Lockdown-compatible"
        }
        return "Property-list pairing record"
    }

    private static func findUDID(in dictionary: [String: Any]) -> String? {
        let preferredKeys = ["UDID", "udid", "UniqueDeviceID", "uniqueDeviceID", "DeviceID", "deviceID"]
        for key in preferredKeys {
            if let value = dictionary[key] as? String, isPlausibleUDID(value) { return value }
        }
        for value in dictionary.values {
            if let nested = value as? [String: Any], let found = findUDID(in: nested) { return found }
            if let array = value as? [Any] {
                for item in array {
                    if let nested = item as? [String: Any], let found = findUDID(in: nested) { return found }
                }
            }
        }
        return nil
    }

    private static func isPlausibleUDID(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 20, normalized.count <= 64 else { return false }
        return normalized.allSatisfy { $0.isNumber || $0.isLetter || $0 == "-" }
    }
}
