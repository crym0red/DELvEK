import SwiftUI
import UniformTypeIdentifiers

struct DELvEKSigningView: View {
    @ObservedObject private var manager = DELvEKSigningManager.shared
    @State private var showPairingImporter = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Current phase")
                    Spacer()
                    Text("\(manager.currentPhase.rawValue)/9")
                        .foregroundStyle(.secondary)
                }
                Text(manager.currentPhase.title)
                    .font(.headline)
                Text(manager.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Pipeline")
            }

            Section {
                statusRow("Pairing", manager.snapshot.pairing.isValid ? "Valid" : "Required", ok: manager.snapshot.pairing.isValid)
                statusRow("Format", manager.snapshot.pairing.format, ok: manager.snapshot.pairing.isValid)
                HStack {
                    Text("UDID")
                    Spacer()
                    Text(manager.snapshot.pairing.udid ?? "Not available")
                        .font(.caption.monospaced())
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }
                Button("Import Pairing Record") { showPairingImporter = true }
                if manager.snapshot.pairing.isStored {
                    Button("Remove Pairing Record", role: .destructive) {
                        manager.removePairing()
                    }
                }
            } header: {
                Text("Device")
            } footer: {
                Text("DELvEK preserves the native pairing record instead of converting iOS 26.x RSD/CoreDevice data into the legacy format.")
            }

            Section {
                statusRow("Certificate", manager.snapshot.certificate.isInstalled ? (manager.snapshot.certificate.commonName ?? "Installed") : "Not installed", ok: manager.snapshot.certificate.isInstalled)
                HStack {
                    Text("Team ID")
                    Spacer()
                    Text(manager.snapshot.certificate.teamIdentifier ?? "—")
                        .foregroundStyle(.secondary)
                }
                statusRow("Provisioning", manager.snapshot.provisioning.isValid ? "Valid" : "Not available", ok: manager.snapshot.provisioning.isValid)
            } header: {
                Text("Development Signing")
            }

            Section {
                statusRow("Local API", manager.snapshot.localAPIReady ? "Available" : "Unavailable", ok: manager.snapshot.localAPIReady)
                statusRow("StikJIT", "Integrated", ok: true)
                statusRow("iOS 26.x pairing", "RSD-aware", ok: true)
            } header: {
                Text("Local Services")
            }

            Section {
                ForEach(DELvEKSigningPhase.allCases) { phase in
                    HStack {
                        Image(systemName: phase.rawValue <= manager.currentPhase.rawValue ? "checkmark.circle.fill" : "circle")
                        Text("\(phase.rawValue). \(phase.title)")
                    }
                }
            } header: {
                Text("Nine phases")
            }

            Section {
                Button("Refresh DELvEK Signing State") { manager.refresh() }
            }
        }
        .navigationTitle("DELvEK Signing")
        .fileImporter(
            isPresented: $showPairingImporter,
            allowedContentTypes: [.propertyList],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    try manager.importPairing(from: url)
                } catch {
                    errorMessage = error.localizedDescription
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .alert("DELvEK Pairing", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func statusRow(_ title: String, _ value: String, ok: Bool) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(ok ? .green : .orange)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
