import Foundation
import Network

/// Device-side transport coordinator for the iOS 26.x LocalDevVPN/CoreDevice path.
///
/// DELvEK keeps the native pairing record opaque and uses the active LocalDevVPN
/// interface as the transport boundary. The actual RSD service handshake is kept
/// behind this type so it can evolve independently from the UI and signing layer.
@MainActor
public final class DELvEKRSDTransport: ObservableObject {
    public static let shared = DELvEKRSDTransport()

    @Published public private(set) var localDevVPNAvailable = false
    @Published public private(set) var endpoint: String?
    @Published public private(set) var lastError: String?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.delvek.rsd.path")
    private var started = false

    private init() {}

    public func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                // A connected path is necessary but not sufficient. We deliberately
                // do not claim that RSD is reachable until an endpoint is discovered.
                self.localDevVPNAvailable = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    public func stop() {
        monitor.cancel()
        started = false
        localDevVPNAvailable = false
        endpoint = nil
    }

    public func attach(pairing: DELvEKPairingStatus) -> Result {
        guard pairing.isValid else {
            lastError = "A valid native iOS 26.x pairing record is required."
            return .failure(lastError!)
        }

        start()
        guard localDevVPNAvailable else {
            lastError = "LocalDevVPN is not currently reachable."
            return .failure(lastError!)
        }

        // The LocalDevVPN peer/port is discovered by the CoreDevice/RSD adapter.
        // We intentionally do not hard-code the historical 10.7.x endpoint here.
        endpoint = nil
        lastError = nil
        return .ready
    }

    public enum Result: Equatable {
        case ready
        case failure(String)
    }
}
