# iOS Packaging Guide

The native iOS implementation ships as an `xcframework` so that both device (`iphoneos`) and simulator (`iphonesimulator`) binaries are available to consumers. Packaging relies on CMake (Xcode generator) and the `xcodebuild -create-xcframework` tool bundled with Xcode.

## Prerequisites
- Xcode command-line tools installed (`xcode-select --install`).
- CMake 3.21+ with the Xcode generator.

## Generating the XCFramework
```bash
./build/scripts/package-ios-xcframework.sh
```

Environment variables:
- `CONFIGURATION` (default: `Release`) — CMake/Xcode build configuration.
- `NMB_IOS_DEPLOYMENT_TARGET` (default: `13.0`) — minimum iOS version for the produced binaries.

Outputs are written to `artifacts/ios/`:
- `NativeMessageBox.xcframework` — contains device + simulator slices.
- `manifest.json` — metadata describing build configuration and architectures.

To consume the framework in the Avalonia cross-platform sample, ensure the generated `NativeMessageBox.xcframework` remains at `artifacts/ios/`. The iOS project adds it as a `NativeReference` when the directory exists.

## Consuming the XCFramework
1. Copy `NativeMessageBox.xcframework` into your Xcode or .NET for iOS project.
2. Add the framework to your app bundle and ensure it is code-signed with the host application.
3. Update the managed runtime probing paths (if necessary) to include the directory hosting the `.xcframework` slice for the current runtime (`ios-arm64`, `iossimulator-arm64`, etc.). The managed loader already recognises iOS and simulator RIDs.
