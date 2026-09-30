import SwiftUI
import UniformTypeIdentifiers

struct DELvEKSigningView: View {
    @ObservedObject private var manager = DELvEKSigningManager.shared

    @State private var showPairingImporter = false
    @State private var errorMessage: String?
    @State private var appleID = ""
    @State private var applePassword = ""
    @State private var verificationCode = ""
    @State private var verificationMethod: VerificationMethod = .trustedDevice
    @State private var showVerification = false
    @State private var showBackendPlaceholder = false
    @State private var backendAction = ""

    private enum VerificationMethod: String, CaseIterable, Identifiable {
        case trustedDevice = "Apple Device"
        case sms = "Text Message (SMS)"
        case phone = "Phone Call"

        var id: String { rawValue }
    }

    var body: some View {
        Form(content: {
            accountSection
            deviceSection
            certificateSection
            trustSection
            localServicesSection
            phasesSection
            refreshSection
        })
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
        .sheet(isPresented: $showVerification) {
            verificationSheet
        }
        .alert("DELvEK", isPresented: Binding(
            get: { errorMessage != nil || showBackendPlaceholder },
            set: { presented in
                if !presented {
                    errorMessage = nil
                    showBackendPlaceholder = false
                }
            }
        )) {
            Button("OK") {
                errorMessage = nil
                showBackendPlaceholder = false
            }
        } message: {
            Text(errorMessage ?? backendAction)
        }
    }

    private var accountSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 30))
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Apple Developer Account")
                            .font(.headline)
                        Text(manager.snapshot.certificate.isInstalled ? "Development identity detected" : "Sign in to prepare development signing")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                TextField("Apple ID", text: $appleID)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)

                SecureField("Apple ID Password", text: $applePassword)
                    .textContentType(.password)

                Button {
                    showVerification = true
                } label: {
                    Label("Sign In & Pair Device", systemImage: "person.badge.key.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(appleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || applePassword.isEmpty)

                Text("Credentials should be passed only to the Apple authentication implementation and never stored in DELvEK's ordinary app settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Apple ID Authentication")
        } footer: {
            Text("The backend will perform the native Apple account/device pairing flow. DELvEK does not generate or invent developer certificates locally.")
        }
    }

    private var deviceSection: some View {
        Section {
            statusRow("Pairing", manager.snapshot.pairing.isValid ? "Valid" : "Required", ok: manager.snapshot.pairing.isValid)
            statusRow("Pairing format", manager.snapshot.pairing.format, ok: manager.snapshot.pairing.isValid)

            VStack(alignment: .leading, spacing: 5) {
                Text("UDID")
                    .font(.subheadline)
                Text(manager.snapshot.pairing.udid ?? "Not available")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Pair Device") {
                    backendAction = "The native iOS 26.x RSD/CoreDevice pairing backend will be connected here."
                    showBackendPlaceholder = true
                }
                .buttonStyle(.borderedProminent)

                Button("Import Pairing") {
                    showPairingImporter = true
                }
                .buttonStyle(.bordered)
            }

            if manager.snapshot.pairing.isStored {
                Button("Remove Pairing Record", role: .destructive) {
                    manager.removePairing()
                }
            }
        } header: {
            Text("Device Pairing")
        } footer: {
            Text("DELvEK is designed around the iOS 26.x RSD/CoreDevice pairing architecture rather than converting the native pairing data to the older legacy format.")
        }
    }

    private var certificateSection: some View {
        Section {
            statusRow(
                "Development Certificate",
                manager.snapshot.certificate.isInstalled
                    ? (manager.snapshot.certificate.commonName ?? "Installed")
                    : "Not installed",
                ok: manager.snapshot.certificate.isInstalled
            )

            detailRow("Team ID", manager.snapshot.certificate.teamIdentifier ?? "—")
            detailRow("Expires", formattedDate(manager.snapshot.certificate.expiration))

            Button {
                backendAction = "Certificate acquisition will be connected after Apple authentication and device pairing are implemented."
                showBackendPlaceholder = true
            } label: {
                Label("Obtain Development Certificate", systemImage: "checkmark.seal")
            }
            .buttonStyle(.borderedProminent)

            Button {
                backendAction = "Certificate inspection is already wired to the local Keychain; refresh after installing the identity."
                manager.refresh()
            } label: {
                Label("Refresh Certificate", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("Development Certificate")
        } footer: {
            Text("The installed identity and Team ID will be displayed here once the backend completes the Apple development-signing flow.")
        }
    }

    private var trustSection: some View {
        Section {
            statusRow("Provisioning Profile", manager.snapshot.provisioning.isValid ? "Valid" : "Not available", ok: manager.snapshot.provisioning.isValid)
            detailRow("App Identifier", manager.snapshot.provisioning.appIdentifier ?? "—")
            detailRow("Profile Team", manager.snapshot.provisioning.teamIdentifier ?? "—")
            detailRow("Profile Expires", formattedDate(manager.snapshot.provisioning.expiration))

            Button {
                backendAction = "The trust/provisioning download step will be connected to the backend after authentication."
                showBackendPlaceholder = true
            } label: {
                Label("Download Trust Profile", systemImage: "arrow.down.doc")
            }
            .buttonStyle(.bordered)
        } header: {
            Text("Trust & Installation")
        } footer: {
            Text("This section is reserved for the device-specific development provisioning/trust material required by the final installer flow.")
        }
    }

    private var localServicesSection: some View {
        Section {
            statusRow("Local API", manager.snapshot.localAPIReady ? "Available" : "Unavailable", ok: manager.snapshot.localAPIReady)
            statusRow("LocalDevVPN / Backloop", manager.snapshot.localAPIReady ? "Ready" : "Not connected", ok: manager.snapshot.localAPIReady)
            statusRow("StikJIT", "Integrated", ok: true)
            statusRow("iOS 26.x RSD", "Supported by pairing layer", ok: true)

            Button {
                backendAction = "The local API/backloop service will be started and health-checked here once its backend adapter is connected."
                showBackendPlaceholder = true
            } label: {
                Label("Test Local API", systemImage: "network")
            }
        } header: {
            Text("Local Services")
        }
    }

    private var phasesSection: some View {
        Section {
            ForEach(DELvEKSigningPhase.allCases) { phase in
                let completed = phase.rawValue < manager.currentPhase.rawValue
                let active = phase == manager.currentPhase

                HStack(spacing: 12) {
                    Image(systemName: completed ? "checkmark.circle.fill" : (active ? "circle.dotted" : "circle"))
                        .foregroundStyle(completed ? .green : (active ? .blue : .secondary))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Phase \(phase.rawValue): \(phase.title)")
                            .font(.subheadline.weight(active ? .semibold : .regular))
                        if active {
                            Text(manager.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
        } header: {
            Text("DELvEK Setup")
        }
    }

    private var refreshSection: some View {
        Section {
            Button {
                manager.refresh()
            } label: {
                Label("Refresh DELvEK Signing State", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var verificationSheet: some View {
        NavigationStack {
            Form(content: {
                Section {
                    Text("Apple requires verification when the account signs in from a new device or session.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 10) {
                        verificationButton(.trustedDevice, title: "Apple Devices (Recommended)", icon: "apple.logo")
                        verificationButton(.sms, title: "Text Message (SMS)", icon: "message.fill")
                        verificationButton(.phone, title: "Phone Call", icon: "phone.fill")
                    }

                    SecureField("Verification Code", text: $verificationCode)
                        .keyboardType(.numberPad)

                    Button("Submit Verification Code") {
                        backendAction = "Verification UI is ready. The Apple authentication backend still needs to submit the code and continue pairing."
                        showVerification = false
                        showBackendPlaceholder = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(verificationCode.isEmpty)
                } header: {
                    Text("Verification")
                }
            })
            .navigationTitle("Apple Verification")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showVerification = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }


    private func verificationButton(_ method: VerificationMethod, title: String, icon: String) -> some View {
        Button {
            verificationMethod = method
        } label: {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
                if verificationMethod == method {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(verificationMethod == method ? .blue : .secondary)
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
                .multilineTextAlignment(.trailing)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
