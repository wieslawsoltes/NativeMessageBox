# Contributing Guide

Thanks for your interest in contributing!

## Getting Started
1. **Fork and clone** the repository.
2. Install dependencies (CMake, Ninja, GTK, .NET 8 SDK).
3. Run the setup build:
   ```bash
   ./build/build.sh
   dotnet build samples/AvaloniaSamples.sln
   ```

## Development Workflow
- Follow the documented architecture (`docs/architecture.md`) and coding guidelines.
- Run `dotnet format` and `build/scripts/verify-clang-format.sh` before submitting a PR.
- Ensure `dotnet test` and `ctest` succeed.
- Update documentation when adding features or fixing bugs.

## Pull Requests
- Describe the motivation and changes clearly.
- Reference roadmap items or issues when applicable.
- Include tests or sample updates to demonstrate behavior.

## Code Style
- C#/XAML: rely on `dotnet format` defaults with nullable reference types enabled.
- C/C++/Objective-C: follow `.clang-format` (Allman braces, 4-space indent).

## Reporting Issues
Use the issue templates in `.github/ISSUE_TEMPLATE`. Provide platform info, repro steps, and logs when possible.

## Communication
Join discussions via GitHub issues or discussions (planned). Please be respectful and follow the Code of Conduct.

