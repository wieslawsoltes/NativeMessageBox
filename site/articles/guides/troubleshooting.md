---
title: "Troubleshooting"
---

# Troubleshooting

## Native library not found

Symptoms:
The managed client throws a load failure or reports that ABI verification failed.

Checks:

- Confirm the runtime binary for the current architecture ships with the app.
- Register a custom folder with <xref:NativeMessageBox.NativeMessageBoxClient.RegisterNativeLibraryPath(System.String)> if you extract runtimes to a nonstandard location.
- Verify the package output still contains the `runtimes/` layout.

## Windows STA requirement

Symptoms:
Advanced dialogs fail on Windows or report thread apartment issues.

Fix:

- Run the call on an STA-compatible UI thread.
- Only disable `RequireStaThreadForWindows` when you fully control the calling context.

## GTK or display initialization issues

Symptoms:
Dialogs do not appear on Linux or the process reports display errors.

Checks:

- Confirm a graphical session is available.
- Confirm GTK dependencies are installed.
- Expect reduced behavior when the environment falls back to `zenity`.

## Android activity not available

Symptoms:
Android dialogs cannot be shown or resolve a null/invalid presenter.

Fix:

- Provide `AndroidHostOptions.ActivityReferenceProvider`.
- Track the foreground `Activity` rather than caching a stale instance.

## Unexpected timeout or cancellation

Checks:

- Inspect `WasTimeout` to separate timeout from user dismissal.
- Verify `TimeoutButtonId` maps to one of the configured buttons.

## Related

- [Diagnostics and Runtime Loading](../advanced/diagnostics-and-runtime-loading.md)
- [Mobile Platforms](../platforms/mobile-platforms.md)
