---
title: "Building and Packaging"
---

# Building and Packaging

NativeMessageBox ships cross-platform build scripts for native libraries, managed packages, and optional mobile/browser artifacts.

## Prerequisites

| Host OS | Required toolchains |
| --- | --- |
| macOS | Xcode command-line tools, CMake 3.21+, Ninja, .NET 8 SDK |
| Linux | GCC/Clang toolchain, CMake 3.21+, Ninja, .NET 8 SDK |
| Windows | Visual Studio C++ workload, CMake 3.21+, Ninja, .NET 8 SDK, PowerShell 7+ |

Additional SDKs are needed only when you build optional targets such as Android, iOS, or browser WASM.

## Main Commands

```bash
# macOS / Linux
./build/build.sh
./build/build.sh --all
./build/build.sh --wasm

# Windows
pwsh build/build.ps1
pwsh build/build.ps1 -All
```

## Packaging Scripts

| Script | Output |
| --- | --- |
| `build/scripts/package-android-aar.sh` | `artifacts/android/NativeMessageBox.aar` |
| `build/scripts/package-ios-xcframework.sh` | `artifacts/ios/NativeMessageBox.xcframework` |
| `build/scripts/package-wasm.sh` | Browser runtime package under `artifacts/web/` |

## Generated Artifacts

- NuGet package under `artifacts/nuget/`
- RID-specific native runtime zips under `artifacts/native-*`
- Android AAR, iOS XCFramework, and browser package outputs when requested

## Validation

After a full build:

- Run `dotnet test NativeMessageBox.sln`
- Inspect the produced runtime folders in the package or artifact zips
- Build one of the samples to verify end-to-end integration

## Related

- [Samples](samples.md)
- [Desktop Platforms](../platforms/desktop-platforms.md)
- [Mobile Platforms](../platforms/mobile-platforms.md)
