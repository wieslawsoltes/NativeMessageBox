# Building NativeMessageBox

NativeMessageBox ships cross-platform tooling that can build the native libraries, .NET packages, and optional mobile artifacts (Android AAR, iOS xcframework) from macOS, Linux, and Windows hosts.

## Prerequisites

| Host OS | Required Toolchains |
| --- | --- |
| macOS | Xcode command-line tools, CMake 3.21+, Ninja, .NET 8 SDK, PowerShell 7+ (optional), Android SDK/NDK (optional for Android packaging), Emscripten SDK (optional for WebAssembly), JDK 8+ (for `javac`/`jar`) |
| Linux | GCC/Clang toolchain, CMake 3.21+, Ninja, .NET 8 SDK, PowerShell 7+ (optional), Android SDK/NDK (optional), Emscripten SDK (optional for WebAssembly), JDK 8+ |
| Windows | Visual Studio Build Tools (with C++ workload), CMake 3.21+, Ninja, .NET 8 SDK, PowerShell 7+, Android SDK/NDK (optional), Emscripten SDK (optional for WebAssembly), JDK 8+ |

> ℹ️ iOS packaging requires macOS with the full Xcode toolchain. The Android packaging scripts expect the `ANDROID_SDK_ROOT`, `ANDROID_NDK_ROOT`, and `JAVA_HOME`/`PATH` variables to be configured.

## Command Overview

### macOS / Linux (`build.sh`)

```bash
# Build desktop host binaries (Release configuration)
./build/build.sh

# Build everything (desktop + Android + iOS)
./build/build.sh --all

# Build host binaries in Debug and skip tests/dotnet steps
./build/build.sh --config Debug --skip-tests --skip-dotnet

# Only package Android artifacts (requires SDK/NDK/JDK)
./build/build.sh --android

# Only produce the iOS xcframework (macOS only)
./build/build.sh --ios

# Only produce the WebAssembly artifacts (requires Emscripten SDK)
./build/build.sh --wasm
```

> ℹ️ Non-macOS hosts automatically skip the iOS packaging step, so `--all` builds succeed everywhere.
> ℹ️ The WebAssembly preset bundles a default browser host (`src/native/web/message_box.js`). Override `Module.nativeMessageBox.showMessageBox` before loading the module to supply a custom UI or localization pipeline.
> ℹ️ When running inside a WebAssembly runtime, `NativeMessageBoxClient` selects `NativeMessageBoxBrowserHost` automatically and forwards requests through the `NativeMessageBoxManaged.*` JavaScript hooks—no native probing paths are required.

### Windows / Cross-platform PowerShell (`build.ps1`)

```powershell
# Build desktop host binaries (Release configuration)
pwsh build/build.ps1

# Build host + Android artifacts
pwsh build/build.ps1 -Targets host,android

# Build everything (on macOS with PowerShell 7+ this includes iOS packaging)
pwsh build/build.ps1 -All

# Debug build without tests or dotnet packaging
pwsh build/build.ps1 -Configuration Debug -SkipTests -SkipDotnet

# Produce only the iOS xcframework (requires macOS host with PowerShell 7+)
pwsh build/build.ps1 -Targets ios
```

The Windows script shares the same target semantics:

- `host` &mdash; native desktop build + .NET packaging.
- `android` &mdash; invokes `build/scripts/package-android-aar.sh`.
- `ios` &mdash; invokes `build/scripts/package-ios-xcframework.sh` when running on macOS.
- `wasm` &mdash; invokes `build/scripts/package-wasm.sh` (requires `emcc` from the Emscripten SDK).

## Artifact Locations

All artifacts are written to `artifacts/`:

- `artifacts/native/<rid>/` &mdash; native desktop binaries and symbols organized by runtime identifier.
- `artifacts/native-<rid>.zip` &mdash; zipped copies of the native artifacts (one per RID).
- `artifacts/nuget/` &mdash; `.nupkg` outputs for the managed layer.
- `artifacts/android/` &mdash; AAR bundle, JNI libraries per ABI, and metadata manifest.
- `artifacts/ios/` &mdash; xcframework bundle and manifest metadata.
- `artifacts/web/` &mdash; `libnativemessagebox.wasm`, optional loader shims, and metadata manifest.

Each packaging step generates a `manifest.json` with version and timestamp details to simplify CI publishing.
