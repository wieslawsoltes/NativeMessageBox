# Managed API Overview

## Core Entry Points
- **`NativeMessageBoxClient`** — Static façade for displaying dialogs. Provides sync/async show methods, host configuration, log registration, and native library probing.
- **`INativeMessageBoxHost`** — Contract for pluggable hosts (e.g., dispatcher-aware wrapper). Default implementation is `NativeRuntimeMessageBoxHost`.
- **`NativeMessageBoxHostOptions`** — Configuration options for the runtime host (e.g., STA enforcement on Windows).

## Dialog Configuration
- **`MessageBoxOptions`** — Primary configuration record containing message text, title, icon, modality, list of `MessageBoxButton`s, input/secondary content, timeout, and localization hints.
- **`MessageBoxButton`** — Describes a button (identifier, label, kind, default/cancel flags, accessible description).
- **`MessageBoxInputOptions`** — Enables optional input controls (checkbox, text, password, combo box) with prompts and lists.
- **`MessageBoxSecondaryContent`** — Supplies informative text, expandable details, footers, and help links.

## Results & Errors
- **`MessageBoxResult`** — Returned payload with selected button identifier, checkbox/input values, timeout indicator, outcome, and native result code.
- **`MessageBoxOutcome`** — Enumerates success, cancellation, not-supported, platform failures, etc., mapped from native result codes.
- **`NativeMessageBoxException`** — Exception thrown when initialization or dialog display fails; includes outcome and raw native result code.

## Diagnostic Hooks
- `NativeMessageBoxClient.RegisterLogHandler(Action<string>)` — Receives native runtime log messages.
- `NativeMessageBoxClient.RegisterNativeLibraryPath(string)` — Adds custom probing directories for the native library.
- `NativeMessageBoxClient.ConfigureHost(Action<NativeMessageBoxHostOptions>)` — Adjusts host configuration such as STA validation.

## Usage Pattern
1. Optionally register logs/paths and configure the host.
2. Instantiate `MessageBoxOptions` with desired buttons, inputs, and content.
3. Call `NativeMessageBoxClient.Show` or `ShowAsync`.
4. Inspect `MessageBoxResult` for button IDs, checkbox/input states, and outcomes.
5. Handle exceptions for unsupported features or initialization failures.

