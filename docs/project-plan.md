# Native Message Box FFI + .NET 8 Managed API Roadmap

This roadmap defines the phased delivery of a cross-platform native message box solution with a C ABI, managed .NET 8 layer, Avalonia sample applications, documentation, and GitHub Actions pipelines. Each task is numbered and checkable.

## Phase 1 — Product Definition & Architecture
- [x] 1.1 Capture platform capabilities matrix (Windows `MessageBoxExW`/TaskDialogIndirect, macOS `NSAlert`/`CFUserNotification`, Linux `GtkMessageDialog`/`zenity` fallback) with feature gaps.
- [x] 1.2 Define user experience requirements (button configurations, icons, modality, checkbox prompts, text input, localization support).
- [x] 1.3 Draft high-level architecture for native libraries, shared C ABI surface, managed wrapper, and interop helpers.
- [x] 1.4 Specify configuration model (structs/enums/flags) for C ABI ensuring binary compatibility and future extensibility.
- [x] 1.5 Approve error handling strategy (return codes vs. callback, errno usage) and logging hooks.
- [x] 1.6 Confirm build tooling stack (CMake/Meson for native, .NET SDK, optional vcpkg/homebrew packages) and repository layout.

## Phase 2 — C ABI Specification & Core Types
- [x] 2.1 Draft `include/native_message_box.h` header with versioning, calling conventions, opaque handles, and structs for options/results.
- [x] 2.2 Define enums for button sets, icons, modality, and additional UX features.
- [x] 2.3 Design extensibility mechanism (size-based struct versioning or feature flags).
- [x] 2.4 Create markdown spec documenting ABI contracts and binary compatibility guarantees.
- [x] 2.5 Prototype sample usage snippet in C demonstrating API ergonomics.

## Phase 3 — Native Host Implementations
- [x] 3.1 Implement Windows library (`src/native/windows/message_box.cpp`) using modern C++ with `win32` or `TaskDialogIndirect` fallback logic.
- [x] 3.2 Implement macOS library (`src/native/macos/MessageBox.mm`) bridging Objective-C for `NSAlert`/`NSPanel`.
- [x] 3.3 Implement Linux library (`src/native/linux/message_box.cpp`) targeting GTK 4 with CLI fallback (zenity/kdialog), load dynamically to avoid hard deps.
- [x] 3.4 Create shared utility layer for string encoding (UTF-8 <-> UTF-16), memory management, and thread marshalling.
- [x] 3.5 Add automated tests for native layer using platform-specific test harnesses (e.g., GoogleTest where feasible, otherwise headless unit tests with mocks).
- [x] 3.6 Package native binaries per platform (static/shared decisions, naming, version resources).

## Phase 4 — Managed Interop Layer (.NET 8)
- [x] 4.1 Define public `NativeMessageBox` namespace with records/enums mirroring C ABI.
- [x] 4.2 Use source-generated `LibraryImport` attributes for platform-specific entry points with function pointers.
- [x] 4.3 Implement marshaling helpers for strings, callbacks, and memory ownership.
- [x] 4.4 Provide async-friendly wrappers integrating with `Task` and cancellation tokens.
- [x] 4.5 Draft exception hierarchy and error surfacing consistent with .NET design guidelines.
- [x] 4.6 Add xUnit tests validating marshaling, struct alignment, and P/Invoke correctness (using `DllImportResolver` to load test doubles when needed).

## Phase 5 — Cross-Platform Orchestration
- [x] 5.1 Implement runtime detection and automatic native library loading (Windows DLL, macOS `.dylib`, Linux `.so`).
- [x] 5.2 Add configuration for probing paths, RID-specific assets, and optional self-contained deployment.
- [x] 5.3 Create abstraction to allow optional custom hosts (e.g., provide own native library).
- [x] 5.4 Validate thread apartment requirements (STA vs. main thread) and document constraints.
- [x] 5.5 Establish diagnostics hooks (logging delegate, event tracing) across native and managed layers.

## Phase 6 — Avalonia Sample Applications
- [x] 6.1 Scaffold sample solution (`samples/AvaloniaSamples.sln`) targeting Windows/macOS/Linux.
- [x] 6.2 Build `Sample.Showcase` demonstrating every configuration (buttons, icons, inputs, async usage) with live preview.
- [x] 6.3 Build `Sample.DialogPlayground` for integration scenarios (modal flows, MVVM commands).
- [x] 6.4 Add platform-specific launch scripts or packaging to run samples easily.
- [x] 6.5 Document sample usage and scenarios in README with screenshots/gifs.

## Phase 7 — Documentation & Developer Experience
- [x] 7.1 Produce conceptual docs (`docs/architecture.md`, `docs/abi-spec.md`, `docs/managed-api.md`).
- [x] 7.2 Create quick-start guide for consuming the package from .NET and native C/C++.
- [x] 7.3 Add API reference generation via DocFX or Sandcastle (automated from XML comments).
- [x] 7.4 Prepare troubleshooting and FAQ section (threading, Linux display server requirements).
- [x] 7.5 Draft contribution guidelines and code of conduct.

- [x] 8.3 Add packaging scripts for NuGet (managed) and native artifacts (ZIP/tarball).
- [x] 8.4 Implement `build.ps1` / `build.sh` orchestrating native + managed + samples builds.
- [x] 8.5 Integrate code formatting/linting (clang-format, dotnet format) and analyzers.
- [x] 8.6 Add versioning strategy (Git tags, ` Nerdbank.GitVersioning` or MINOR bump policy).

- [x] 9.1 Author GitHub Actions workflows for PR validation (build, tests, analyzers on Windows/macOS/Linux).
- [x] 9.2 Add matrix job for native builds producing artifacts per platform.
- [x] 9.3 Integrate sample app smoke tests (headless or screenshot capture where possible).
- [x] 9.4 Create release pipeline that publishes NuGet package and uploads native assets with provenance.
- [x] 9.5 Automate documentation build/deploy (GitHub Pages or docs publishing pipeline).

## Phase 10 — Release & Maintenance
- [x] 10.1 Define semantic versioning policy and changelog process.
- [x] 10.2 Set up issue templates, discussion categories, and support SLA.
- [x] 10.3 Plan roadmap for advanced features (custom button layout, embedded web content, theming).
- [x] 10.4 Establish security policy and vulnerability reporting path.
- [x] 10.5 Schedule long-term maintenance tasks (dependency upgrades, platform API updates).

## Phase 11 — iOS Platform Support
- [x] 11.1 Analyze iOS dialog UX expectations across UIKit and SwiftUI hosts, capturing API constraints and accessibility requirements. (See `docs/mobile-dialog-ux-analysis.md`)
- [x] 11.2 Implement native iOS library (`src/native/ios/MessageBox.mm`) wrapping `UIAlertController` with the shared C ABI surface.
- [x] 11.3 Ensure main-thread execution and run-loop integration, adding XCTest-based automation or simulator-driven smoke tests. (See `src/native/tests/sanity_test.c`)
- [x] 11.4 Package the iOS artifacts as an XCFramework (device + simulator) and extend the managed loader for RID-specific discovery. (See `build/scripts/package-ios-xcframework.sh`, `docs/ios-packaging.md`, `src/dotnet/NativeMessageBox/Interop/NativeLibraryLoader.cs`)
- [x] 11.5 Produce iOS sample integration (Avalonia.iOS or .NET MAUI head) and document deployment/configuration guidance. (See `samples/CrossPlatformSample/NativeMessageBox.CrossPlatformSample.sln`, `samples/README.md`, `docs/ios-packaging.md`)

## Phase 12 — Android Platform Support
- [x] 12.1 Research Android dialog patterns (AlertDialog, Material alerts) and define compatibility matrix for API levels and theming. (See `docs/mobile-dialog-ux-analysis.md`)
- [x] 12.2 Implement native Android bridge (`src/native/android/MessageBox.cpp`) using JNI to surface the C ABI via a lightweight Java/Kotlin host. (See `src/native/android/MessageBox.cpp`, `src/native/android/java/com/nativeinterop/NativeMessageBoxBridge.java`)
- [x] 12.3 Manage activity lifecycle and UI thread dispatch guarantees, adding Instrumentation/Espresso smoke tests where feasible. (See `docs/android-lifecycle.md`, `samples/CrossPlatformSample/NativeMessageBox.CrossPlatformSample.Android/NativeMessageBoxActivityTracker.cs`, `src/dotnet/NativeMessageBox/Interop/NativeRuntimeMessageBoxHost.cs`)
- [x] 12.4 Package the Android artifacts as an AAR with CMake/NDK builds and integrate loading hooks in the managed layer. (See `build/scripts/package-android-aar.sh`, `docs/android-packaging.md`, `src/dotnet/NativeMessageBox/Interop/NativeLibraryLoader.cs`)
- [x] 12.5 Produce Android sample (Avalonia.Android or MAUI head) and extend documentation for platform setup, permissions, and limitations. (See `samples/CrossPlatformSample/README.md`, `samples/CrossPlatformSample/NativeMessageBox.CrossPlatformSample.Android`, `docs/android-packaging.md`)

## Phase 13 — WebAssembly (Browser) Support
- [x] 13.1 Analyze browser dialog capabilities (`alert`, `confirm`, custom modal overlays) and capture UX, accessibility, and security constraints for WebAssembly hosts. (Document in `docs/web-dialog-ux-analysis.md`)
- [x] 13.2 Add WebAssembly toolchain configuration (Emscripten/CMake presets) to compile the native core to `libnative_message_box.wasm` with the shared C ABI surface. (Update `CMakePresets.json`, `build/scripts/package-wasm.sh`)
- [x] 13.3 Implement JavaScript ↔️ WASM glue code exposing the message box API, ensuring async handling and localization via the browser runtime. (See `src/native/web/wasm_message_box.cpp`, `src/native/web/message_box.js`)
- [x] 13.4 Extend the managed loader to detect browser/WebAssembly runtime and route calls through `JSExport`/`JSImport` interop, maintaining parity with native platforms. (Update `src/dotnet/NativeMessageBox/Interop/NativeLibraryLoader.cs`, add `NativeMessageBoxBrowserHost.cs`)
- [x] 13.5 Integrate the WebAssembly artifacts into the sample pipeline and wire up `samples/CrossPlatformSample/NativeMessageBox.CrossPlatformSample.Browser` to exercise the new host end-to-end. (Update project file, resource bundling, and Avalonia UI bindings)
- [x] 13.6 Document Web usage, deployment instructions, and caveats (HTTPS requirements, iframe policies) in `samples/CrossPlatformSample/README.md`, `docs/browser-deployment.md`, and align build/CI coverage for the browser workflow.

---

### Repository Layout (Proposed)
- `docs/` — Planning, architecture, API documentation.
- `include/` — Public C headers for the native ABI.
- `src/native/{windows,macos,linux}/` — Platform-specific implementations.
- `src/shared/` — Cross-platform utilities for native code.
- `src/dotnet/NativeMessageBox/` — Managed library source.
- `src/dotnet/NativeMessageBox.Tests/` — Managed tests.
- `samples/` — Avalonia sample solutions and projects.
- `build/` — Scripts, CMake files, and packaging metadata.
- `.github/workflows/` — CI/CD pipelines.

### Guiding Principles
- Preserve API stability and ABI compatibility.
- Prefer opt-in advanced features while keeping basic usage simple.
- Embrace modern interop (LibraryImport, source generation) and avoid legacy `DllImport` where practical.
- Ensure accessibility, localization, and internationalization considerations from the start.
- Automate everything: builds, tests, docs, packaging, and releases.
