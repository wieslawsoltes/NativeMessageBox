---
title: "Desktop Platforms"
---

# Desktop Platforms

Desktop backends expose the richest feature surface in NativeMessageBox.

## Windows

- Uses `TaskDialogIndirect` for advanced features and `MessageBoxW` when a simpler fallback is sufficient.
- Supports icons, checkbox verification, secondary content, help links, and timeout handling.
- Advanced requests may require an STA thread.

## macOS

- Uses `NSAlert` with accessory views for text, password, combo, and checkbox input.
- Supports informative and expanded content, help links, and timeout-driven close behavior.
- Must execute on the main thread.

## Linux

- Uses GTK dialogs for the primary path.
- Supports multiple buttons, inputs, checkbox state, and secondary content.
- Depends on a usable display session; constrained environments may fall back to `zenity`.

## Choosing a Common Denominator

If your app must behave identically across desktop operating systems, build around:

- Explicit buttons
- Basic icons
- Optional checkbox state
- Timeout behavior you have tested on all three backends

Then layer text input or help links where they add value.

## Related

- [Platform Capabilities](../concepts/platform-capabilities.md)
- [Threading and Host Customization](../advanced/threading-and-hosts.md)
