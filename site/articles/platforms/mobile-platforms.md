---
title: "Mobile Platforms"
---

# Mobile Platforms

Mobile support focuses on native system dialogs and the host information required to present them safely.

## iOS

- Implemented with `UIAlertController`.
- Supports custom button labels, default/cancel/destructive roles, and basic text/password input.
- Ignores desktop-style secondary content and checkbox affordances.
- Requires a visible presenter on the main thread.

## Android

- Implemented with a lightweight Java bridge around `AlertDialog`.
- Supports the standard positive/negative/neutral button model.
- Does not support accessory input, secondary content, or timeout auto-close.
- Requires an `Activity` reference supplied through <xref:NativeMessageBox.AndroidHostOptions>.

## Activity Tracking

For Android, provide `ActivityReferenceProvider` so the runtime can acquire a valid foreground activity at call time. Do not store a stale activity reference across configuration changes.

## Practical Guidance

- Keep mobile button labels short.
- Prefer a reduced option set when a dialog must behave similarly on iOS and Android.
- Treat mobile dialogs as presentation-bound UI, not background-worker infrastructure.

## Related

- [Building and Packaging](../guides/building-and-packaging.md)
- [Troubleshooting](../guides/troubleshooting.md)
