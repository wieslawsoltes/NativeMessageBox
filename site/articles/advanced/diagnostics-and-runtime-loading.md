---
title: "Diagnostics and Runtime Loading"
---

# Diagnostics and Runtime Loading

NativeMessageBox exposes a small but useful diagnostic surface for startup and production issues.

## Key APIs

| API | Purpose |
| --- | --- |
| <xref:NativeMessageBox.NativeMessageBoxClient.RegisterLogHandler(System.Action{System.String})> | Receive native runtime log messages |
| <xref:NativeMessageBox.NativeMessageBoxClient.RegisterNativeLibraryPath(System.String)> | Add custom probing directories |
| <xref:NativeMessageBox.NativeMessageBoxClient.EnsureInitialized> | Force runtime initialization early |
| <xref:NativeMessageBox.NativeMessageBoxClient.VerifyAbiCompatibility> | Check that the managed layer can talk to the loaded native runtime |

## Recommended Startup Pattern

1. Register a log handler early.
2. Register custom runtime directories if packaging extracts files away from the default layout.
3. Call `EnsureInitialized` during startup if you want failures to surface before the first user dialog.
4. Optionally run `VerifyAbiCompatibility` in diagnostics or support builds.

## What to Log

- Platform fallback messages
- Native library probing paths
- Unsupported feature requests
- ABI mismatch or initialization failures

## Common Failure Modes

- Wrong architecture runtime deployed with the app
- Missing mobile/browser runtime sidecar files
- Requesting features unsupported by the active platform
- Calling into the runtime from an invalid UI context

## Related

- [Troubleshooting](../guides/troubleshooting.md)
- [C ABI and Versioning](c-abi-and-versioning.md)
