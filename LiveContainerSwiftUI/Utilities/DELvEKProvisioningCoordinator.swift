import Foundation

/// Single orchestration point for the complete DELvEK device/signing pipeline.
///
/// The coordinator deliberately does not invent private Apple/CoreDevice APIs.
/// It connects the concrete pieces already present in DELvEK: native pairing
/// record storage, signing-state inspection, the local loopback API, and the
/// existing StikJIT helper. Apple certificate/profile acquisition is represented
/// by the state transition and is refreshed from the device after the external
/// provisioning operation completes.
@MainActor
public final class DELvEKProvisioningCoordinator: ObservableObject {
    public static let shared = DELvEKProvisioningCoordinator()

    @Published public private(set) var snapshot = DELvEKSigningSnapshot()
    @Published public private(set) var phase: DELvEKSigningPhase = .pairing
    @Published public private(set) var lastError: String?
    @Published public private(set) var isRunning = false

    private let manager = DELvEKSigningManager.shared
    private let upstream = DELvEKUpstreamAPI.shared
    private init() { refresh() }

    public func refresh() {
        manager.refresh()
        snapshot = manager.snapshot
        phase = manager.currentPhase
        lastError = nil
    }

    public func importNativePairing(from url: URL) throws {
        try manager.importPairing(from: url)
        refresh()
    }

    public func removePairing() {
        manager.removePairing()
        refresh()
    }

    public func generateSigningCSR() throws -> DELvEKUpstreamAPI.CSRMaterial {
        try upstream.generateCSR()
    }

    public func pairAndDiscoverUDID() async {
        isRunning = true
        defer { isRunning = false }
        do {
            let pairingURL = DELvEKPairingStore.shared.pairingURL
            try await upstream.startTransport(with: pairingURL)
            let udid = try await upstream.fetchUDID()
            snapshot.pairing.udid = udid
            snapshot.pairing.isValid = true
            phase = .appleSession
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            refresh()
        }
    }

    /// Runs every currently executable local stage in order. Stages that depend
    /// on Apple's server-side provisioning remain represented by their real
    /// observed state instead of being reported as successful prematurely.
    public func reconcileAll() async {
        isRunning = true
        defer { isRunning = false }
        refresh()

        // Phase 1/2: native pairing + device identity.
        guard snapshot.pairing.isValid, snapshot.pairing.udid != nil else {
            phase = snapshot.pairing.isValid ? .deviceIdentity : .pairing
            return
        }

        // Phase 3/4/5: Apple session, certificate, and profile are reflected
        // from actual installed signing material. No fake success state.
        if !snapshot.certificate.isInstalled {
            phase = .appleSession
            return
        }

        if !snapshot.provisioning.isValid {
            phase = .provisioning
            return
        }

        // Phase 6: signer inputs are now present.
        phase = .signer

        // Phase 7: local loopback service.
        if !snapshot.localAPIReady {
            phase = .localAPI
            return
        }

        // Phase 8/9 are provided by the existing StikJIT/guest runtime path.
        phase = .jit
        refresh()
        if snapshot.localAPIReady {
            phase = .runtime
        }
    }
}
