# Build Scripts

This folder contains cross-platform build orchestration scripts (Bash and PowerShell), CMake toolchain configuration, and packaging metadata used by local builds and CI pipelines.

## Entry Points

- `build.sh` &mdash; unified build entry point for macOS and Linux hosts. Supports building the desktop host binaries, the Android AAR, the WebAssembly module, and (on macOS) the iOS xcframework.
- `build.ps1` &mdash; unified build entry point for Windows hosts (works with PowerShell 7+ on any platform). Supports desktop builds, Android packaging, WebAssembly packaging, and iOS packaging when run on macOS.
- `scripts/package-ios-xcframework.sh` &mdash; produces `NativeMessageBox.xcframework` with device + simulator slices (requires Xcode toolchain).
- `scripts/package-android-aar.sh` &mdash; builds native libraries for multiple Android ABIs and bundles them (with the Java bridge) into `NativeMessageBox.aar`.
- `scripts/package-wasm.sh` &mdash; compiles the native core with Emscripten using the `wasm-release` CMake preset and copies the resulting `libnative_message_box.wasm` artifacts.

## Common Usage

```bash
# macOS/Linux: build host binaries (default configuration: Release)
./build/build.sh

# macOS/Linux: build everything (host + Android + iOS)
./build/build.sh --all

# macOS/Linux: just package Android artifacts
./build/build.sh --android

# macOS/Linux: only produce the WebAssembly module
./build/build.sh --wasm
```

```powershell
# Windows (PowerShell 7+): build host binaries
pwsh build/build.ps1

# Windows: include Android packaging
pwsh build/build.ps1 -Targets host,android

# macOS with PowerShell 7+: build everything
pwsh build/build.ps1 -All

# Windows/macOS/Linux (PowerShell 7+): only produce WebAssembly module
pwsh build/build.ps1 -Targets wasm
```

Both entry points accept:

- `--config` / `-Configuration` &mdash; choose the build configuration (`Release` by default).
- `--skip-tests` / `-SkipTests` &mdash; omit native unit tests during the host build.
- `--skip-dotnet` / `-SkipDotnet` &mdash; skip the `dotnet restore/build/pack` steps.

See `docs/building.md` for more detailed setup guidance.
