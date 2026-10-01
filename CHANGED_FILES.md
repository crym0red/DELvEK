# DELvEK backend foundation

This patch removes the fake certificate/session state from the button path and introduces the real Apple-signing backend boundary:

- adds the SideSign Swift package dependency (Apple GSA, developer portal, certificate/profile and code-signing primitives);
- adds secure Keychain state for the Apple ID, CSR and device private key;
- generates a real 2048-bit development CSR/private key through SideSign's `CertificateRequest`;
- keeps the Apple password ephemeral and clears it from the UI after the operation;
- wires the DELvEK Signing UI to the backend manager instead of the old placeholder action;
- preserves the existing iOS 26.x RSD/CoreDevice pairing record rather than converting it to legacy data.

Important: this is the first real backend layer, not a claim that Apple authentication/certificate issuance has been device-verified. The next build is intentionally the validation point for the SideSign package API on Xcode 26.2; the authenticated GSA/Developer Portal calls and on-device RSD pairing transport still need to be connected after the package/API compile is confirmed.

## SwiftPM/Xcode 26.2 resolution fix
- uses one persistent `SourcePackages` directory for resolve, build settings, and build;
- removes the destructive DerivedData cleanup between package resolution and compilation;
- clears user SwiftPM caches before resolution;
- applies the same package-path arguments to both main and build workflows.
