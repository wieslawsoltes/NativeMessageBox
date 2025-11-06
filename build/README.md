# Build Scripts

This folder contains cross-platform build orchestration scripts (PowerShell, Bash), CMake toolchain configuration, and packaging metadata used by local builds and CI pipelines.

- `build.sh` / `build.ps1` — end-to-end native + managed build and packaging for desktop targets.
- `scripts/package-ios-xcframework.sh` — produces `NativeMessageBox.xcframework` with device + simulator slices (requires Xcode toolchain).
- `scripts/package-android-aar.sh` — builds the Android native libraries for multiple ABIs and bundles them (with the Java bridge) into `NativeMessageBox.aar`.
