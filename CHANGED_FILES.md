# DELvEK Signing UI integration

- LiveContainerSwiftUI/Views/Settings/LCSettingsView.swift
  - Adds a real visible “DELvEK Signing & Device” row inside the Settings Form.
  - Removes the previous NavigationLink incorrectly created inside onAppear.
- LiveContainerSwiftUI/Views/Settings/DELvEKSigningView.swift
  - Apple ID authentication UI shell
  - verification UI
  - device pairing / UDID UI
  - development certificate UI
  - trust/provisioning UI
  - Local API / backloop / StikJIT status
  - nine-phase setup UI
  - Xcode 26.2-compatible verification sheet
- LiveContainerSwiftUI/Utilities/DELvEKSigningManager.swift
- LiveContainerSwiftUI/Utilities/DELvEKSigningModels.swift
- LiveContainerSwiftUI/Utilities/DELvEKPairingStore.swift
- LiveContainerSwiftUI/Utilities/LocalJITService.swift
