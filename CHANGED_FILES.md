DELvEK nine-phase implementation - changed files only

Phases represented:
1. RSD/CoreDevice-aware pairing record storage/validation adapter
2. UDID extraction/display
3. Apple development-session state model
4. Development certificate discovery
5. Provisioning-profile state model
6. Signing pipeline state model
7. Local API state integration
8. StikJIT/iOS 26.x integration state
9. Runtime/installation pipeline state

This patch intentionally does not fake an Apple developer certificate, provisioning
profile, or RSD pairing handshake. Those are represented by adapters/status models
so the real device/auth implementation can be added and debugged against iOS 26.x.
