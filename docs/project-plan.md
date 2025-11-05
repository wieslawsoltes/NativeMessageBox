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
