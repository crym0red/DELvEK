# DELvEK connected backend integration

Updated:
- LiveContainerSwiftUI/Utilities/DELvEKAppleSigningBackend.swift
  - Links SideSign's documented CSR generation into DELvEK.
  - Stores CSR/private-key material in Keychain.
  - Never persists the Apple ID password.
- LiveContainerSwiftUI/Utilities/DELvEKRSDTransport.swift
  - Adds the iOS 26.x LocalDevVPN/CoreDevice transport boundary.
  - Keeps the native pairing record opaque.
  - Tracks LocalDevVPN path readiness without hard-coding a legacy 10.7.x endpoint.
- LiveContainerSwiftUI/Utilities/DELvEKSigningManager.swift
  - Orchestrates pairing, RSD transport, signing preparation and UI state.
- LiveContainerSwiftUI/Utilities/DELvEKPairingStore.swift
  - Native pairing-record storage/validation.
- LiveContainerSwiftUI/Utilities/DELvEKSigningModels.swift
  - Nine-phase state model.
- LiveContainerSwiftUI/Utilities/LocalJITService.swift
  - Existing local loopback/JIT bridge retained.
- LiveContainerSwiftUI/Views/Settings/DELvEKSigningView.swift
  - Buttons now invoke the backend coordinator rather than the old placeholder actions.
  - Shows LocalDevVPN/RSD transport state and signing-preparation state.
- LiveContainerSwiftUI/Views/Settings/LCSettingsView.swift
  - Existing DELvEK Signing entry retained.
- LiveContainer.xcodeproj.project.pbxproj
  - Adds SideSign as a Swift package product to LiveContainerSwiftUI.
  - Pins SideSign to revision 6b68651697f99791ef85404b7aea1891a26a285d.
- .github/workflows/build.yml
  - Uses Xcode 26.2.
  - Cleans SwiftPM/DerivedData caches before dependency resolution.

Validation:
- All changed Swift files pass `swiftc -parse`.

Important boundary:
- SideSign's public documentation exposes CSR generation and the DeveloperPortal/signing capabilities, but the current DELvEK source did not contain a concrete SideSign authentication/DeveloperPortal session implementation. This patch therefore wires the real SideSign CSR/key material and isolates the Apple portal session behind DELvEK's backend coordinator instead of inventing undocumented API calls.
- The RSD transport boundary is wired to LocalDevVPN readiness, but a complete CoreDevice/RSD service handshake still requires the concrete device-service implementation. No legacy pairing conversion is introduced.
