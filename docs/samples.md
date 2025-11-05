# Samples Overview

The repository ships with two Avalonia-based sample applications located in `samples/`.

## Build Instructions
```bash
dotnet build samples/AvaloniaSamples.sln
```

## Showcase
- Path: `samples/Showcase`
- Purpose: quick entry points for common dialog configurations (information, confirmation, custom buttons, input collection, timeouts).
- Run:
  ```bash
  ./samples/run-showcase.sh        # macOS/Linux
  powershell -File samples/run-showcase.ps1   # Windows
  ```
- Try toggling `NativeMessageBoxClient.ConfigureHost` parameters to observe host enforcement behaviors.

## Dialog Playground
- Path: `samples/DialogPlayground`
- Purpose: sandbox for experimenting with message text, icons, inputs, and async flows.
- Run:
  ```bash
  ./samples/run-playground.sh
  powershell -File samples/run-playground.ps1
  ```
- Use the UI controls to adjust button labels, include inputs or verification checkbox, and toggle async display.

Screenshots can be captured cross-platform once dialogs are implemented; add them to this document in future iterations for quick visual reference.

