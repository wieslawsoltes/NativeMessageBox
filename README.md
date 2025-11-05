# NativeMessageBox

Cross-platform native message box library exposing a stable C ABI and a modern .NET 8 managed wrapper. The project targets Windows, macOS, and Linux, and includes Avalonia sample applications, comprehensive documentation, and fully automated build and release pipelines.

## Project Status
- Planning: see `docs/project-plan.md`.
- Development: scaffolding in progress.

## High-Level Components
- Native C/C++/Objective-C implementations backed by each OS message box API.
- Shared C ABI header located in `include/native_message_box.h`.
- Managed `.NET 8.0` library using `LibraryImport` source generators.
- Configurable host abstraction with pluggable implementations and thread-safety validation helpers.
- Avalonia-based sample applications showcasing all features.
- Build scripts and CI pipelines for packaging and releases.

## Getting Started
1. Review the roadmap: `docs/project-plan.md`.
2. Ensure toolchains are installed (Visual Studio Build Tools, Xcode Command Line Tools, GCC/Clang, .NET 8 SDK).
3. Explore the documentation set:
   - `docs/design/platform-capabilities.md`
   - `docs/design/user-experience-requirements.md`
   - `docs/architecture.md`
   - `docs/managed-api.md`
   - `docs/quickstart.md`
   - `docs/troubleshooting.md`
   - `docs/release-policy.md`
   - `docs/roadmap.md`
4. Use `build/build.sh` (macOS/Linux) or `build/build.ps1` (Windows) to produce native binaries and NuGet packages under `artifacts/`.
5. Run the Avalonia samples via `samples/AvaloniaSamples.sln` to experiment with the feature set.
6. Follow progress in repository issues and pull requests.

## License
This project is released under the MIT License. See `LICENSE`.
