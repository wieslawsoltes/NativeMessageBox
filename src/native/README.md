# Native Implementations

This directory hosts platform-specific implementations of the C ABI declared in `include/native_message_box.h`.

- `windows/` — Modern C++ implementation using Win32 APIs (`MessageBoxExW`, `TaskDialogIndirect`).
- `macos/` — Objective-C++ bridge around `NSAlert` and related AppKit dialogs.
- `linux/` — GTK-based implementation with headless fallbacks (GTK 4 preferred, GTK 3 fallback, optional zenity/kdialog).

Shared cross-platform code (string conversions, diagnostics, utilities) will be located in `src/shared/`.

