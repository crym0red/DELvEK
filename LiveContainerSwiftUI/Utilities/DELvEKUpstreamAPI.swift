import Foundation
import SideSign
import Minimuxer

/// Thin adapter over the real upstream libraries used by DELvEK.
///
/// SideSign supplies Apple's signing primitives (CSR/key material and app
/// signing), while Minimuxer supplies the on-device device-service transport.
/// DELvEK owns orchestration and persistence; it does not reimplement either
/// upstream protocol.
public final class DELvEKUpstreamAPI {
    public static let shared = DELvEKUpstreamAPI()

    private init() {}

    public struct CSRMaterial: Sendable {
        public let csr: Data
        public let privateKey: Data
    }

    public func generateCSR() throws -> CSRMaterial {
        let request = try CertificateRequest(machineName: "DELvEK")
        return CSRMaterial(csr: request.csrData, privateKey: request.privateKey)
    }

    public func startTransport(with pairingFile: URL) async throws {
        #if targetEnvironment(simulator)
        throw DELvEKUpstreamError.unsupportedOnSimulator
        #else
        await Minimuxer.shared.network.start()
        try await Minimuxer.shared.core.start(
            pairingFile: pairingFile.path,
            mountPath: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path,
            preferred: nil
        )
        #endif
    }

    public func stopTransport() async throws {
        #if !targetEnvironment(simulator)
        try await Minimuxer.shared.core.stop()
        #endif
    }

    public func fetchUDID() async throws -> String {
        #if targetEnvironment(simulator)
        throw DELvEKUpstreamError.unsupportedOnSimulator
        #else
        let udid = try await Minimuxer.shared.core.fetchUDID()
        guard !udid.isEmpty else { throw DELvEKUpstreamError.emptyUDID }
        return udid
        #endif
    }

    public func installProvisioningProfile(_ data: Data) async throws {
        #if targetEnvironment(simulator)
        throw DELvEKUpstreamError.unsupportedOnSimulator
        #else
        try await Minimuxer.shared.core.installProvisioningProfile(profile: data)
        #endif
    }

    public func pairWirelessly(
        outputDirectory: URL,
        completion: @escaping @Sendable (Result<URL, Error>) -> Void
    ) {
        let output = outputDirectory.path
        Minimuxer.shared.wirelessPair.start(outPath: output) { result in
            switch result {
            case .success(let device):
                completion(.success(URL(fileURLWithPath: device.pairingFilePath)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

public enum DELvEKUpstreamError: LocalizedError {
    case unsupportedOnSimulator
    case emptyUDID

    public var errorDescription: String? {
        switch self {
        case .unsupportedOnSimulator:
            return "The real device transport is unavailable in the iOS simulator."
        case .emptyUDID:
            return "The upstream device service returned an empty UDID."
        }
    }
}
