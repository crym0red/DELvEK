# DELvEK Built-in JIT

DELvEK's built-in JIT path uses the StikJIT XCFramework in a separate helper extension so the host process is never asked to debug itself.

## Runtime requirements

- iOS 17.4 or later.
- DELvEK must be installed with `get-task-allow=true`.
- Developer Mode enabled.
- A valid device pairing file at `Documents/StikJIT/pairingFile.plist`.
- LocalDevVPN connected so the RSD tunnel is reachable at the StikJIT default endpoint.
- Wi-Fi is recommended by the StikJIT integration guide.

On iOS 27+, on-device pairing can be produced by the StikPair workflow. On iOS 26, import a valid pairing file obtained through a supported pairing method.

## Build

The repository does not vendor the StikJIT binary. `Scripts/build_stikjit.sh` pins StikJIT 1.8.0, builds its XCFramework with XcodeGen/Xcode, and writes it to `build/StikJIT/StikJIT.xcframework` before DELvEK is built.

## Runtime flow

1. DELvEK starts a loopback-only HTTP API.
2. Guest launch requests JIT for the current host/LiveProcess PID.
3. DELvEK sends the PID and pairing bytes to the helper extension.
4. The helper writes a temporary pairing file, calls `StikJIT.enableJIT` on its serial queue, and waits for completion.
5. The helper posts the result back to the loopback API.
6. DELvEK launches the guest only after JIT succeeds.

The certificate/JIT-less path remains available as a fallback.
