# Architecture Overview

## Components
- **Native libraries** (`nativemessagebox`): per-platform dynamic library exposing stable C ABI defined in `include/native_message_box.h`.
- **Shared runtime utilities**: logging bridge, allocator helpers, and sanity tests shared among native targets.
- **Managed wrapper** (`NativeMessageBox`): .NET 8 library providing high-level API, host abstraction, and diagnostics integration.
- **Test infrastructure**: xUnit suite for managed layer; CTest sanity harness ensuring ABI validity.
- **Build tooling**: CMake for native compilation; cross-platform scripts orchestrating native + managed builds and packaging.

## Flow
1. Managed client resolves host (default `NativeRuntimeMessageBoxHost`).
2. Host configures logging callbacks and runtime options, invoking `nmb_initialize` as needed.
3. Options are marshaled into native structs; host validates threading rules.
4. Native layer dispatches to platform-specific implementation, logging fallbacks.
5. Result returned to managed layer, mapped to `MessageBoxResult` and raising exceptions when necessary.

## Extensibility
- `INativeMessageBoxHost` enables custom hosting strategies (e.g., UI dispatcher integration, telemetry wrappers).
- ABI uses struct size/version fields for forward compatibility; new features added non-breaking.
- Diagnostics hooks allow runtime to plug logging and analytics.

## Packaging
- Build scripts output NuGet package and RID-specific native ZIP with manifest and symbol artifacts.
- CI validates formatting (`dotnet format`, `clang-format`), native sanity tests, managed tests, and multi-OS builds.

