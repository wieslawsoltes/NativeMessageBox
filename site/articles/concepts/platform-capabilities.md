---
title: "Platform Capabilities"
---

# Platform Capabilities

NativeMessageBox aims for a shared dialog model across platforms, but each backend keeps its native constraints.

## Capability Matrix

| Capability | Windows | macOS | Linux (GTK) | iOS | Android | Browser |
| --- | --- | --- | --- | --- | --- | --- |
| Multiple buttons | Yes | Yes | Yes | Yes | Partial (3) | Yes |
| Custom button labels | Yes | Yes | Yes | Yes | Yes | Yes |
| Verification checkbox | Yes | Yes | Yes | No | No | Yes |
| Text/password input | No | Yes | Yes | Yes | No | Yes |
| Combo box input | No | Yes | Yes | No | No | Yes |
| Informative / expanded secondary text | Yes | Yes | Yes | No | No | Yes |
| Help link | Yes | Yes | Yes | No | No | No |
| Timeout auto-close | Yes | Yes | Yes | Yes | No | Yes |
| Parent-window modality | Yes | Yes | Yes | Presenter-based | Activity-based | Overlay-based |

## Reading the Matrix

- Windows uses `TaskDialogIndirect` for advanced dialogs and falls back when possible.
- macOS uses `NSAlert` plus accessory views.
- Linux uses GTK and may downgrade to `zenity` in constrained environments.
- iOS and Android intentionally expose a smaller feature surface because system dialog APIs are narrower.
- Browser support is implemented with a custom overlay host rather than the blocking `alert`/`confirm` APIs.

## Practical Implication

Design your dialog requests around the most constrained platform you must support. If your application depends on text input or secondary content everywhere, Android will require an alternate UX path.

## Related

- [Desktop Platforms](../platforms/desktop-platforms.md)
- [Mobile Platforms](../platforms/mobile-platforms.md)
- [Browser Platform](../platforms/browser-platform.md)
