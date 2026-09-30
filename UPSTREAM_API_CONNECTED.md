# DELvEK upstream API connection

This patch connects DELvEK's existing orchestration to the upstream packages rather than placeholder adapters.

## Added upstream dependencies

- SideSign: https://github.com/SideStore/SideSign.git
- MinimuxerPackage: https://github.com/SideStore/MinimuxerPackage.git

The LiveContainerSwiftUI target now consumes the `SideSign` and `Minimuxer` products.

## Real upstream calls now used

- `CertificateRequest(machineName:)` for CSR/private-key material from SideSign.
- `Minimuxer.shared.core.start(...)` for the device-service transport.
- `Minimuxer.shared.core.fetchUDID()` for live device identity.
- `Minimuxer.shared.core.installProvisioningProfile(profile:)` for profile installation.
- `Minimuxer.shared.wirelessPair.start(...)` for upstream wireless pairing generation.
- `Minimuxer.shared.core.stop()` for transport shutdown.

The DELvEK coordinator exposes the upstream CSR and pair/discover operations so the Settings UI can drive the same pipeline.

The Apple Developer Portal operations remain owned by SideSign; DELvEK does not duplicate Apple's authentication or developer APIs.
