# Build Tooling Stack

| Area | Tooling | Notes |
| --- | --- | --- |
| Native build | CMake + Ninja | Generates shared library per platform; integrates CTest for sanity.
| Managed build | .NET SDK 8.0 | `dotnet build/test/pack` workflow.
| Packaging | Custom scripts (`build/build.sh`, `build/build.ps1`) | Produce NuGet packages and RID-specific native ZIPs with manifests and symbols.
| Versioning | Nerdbank.GitVersioning | Automatic semantic versioning derived from Git history.
| Formatting | `dotnet format`, `clang-format` | Enforced in CI across managed and native code.
| CI | GitHub Actions | Multi-OS matrix (Windows, macOS, Linux) with native/managed builds and tests.
| Diagnostics | Logging callback & host options | Configured via managed API; recorded for future telemetry.

## Setup Checklist
- Install CMake, Ninja, and platform SDKs (GTK 3/4, Xcode tools, Windows Build Tools).
- Ensure `.NET 8` SDK is available.
- CI uses package managers (apt/brew/choco) to provision dependencies.

