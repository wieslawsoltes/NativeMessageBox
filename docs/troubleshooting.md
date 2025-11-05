# Troubleshooting

## Native library not found
- Ensure the native runtime is packaged with your application.
- Call `NativeMessageBoxClient.RegisterNativeLibraryPath` with the directory containing `nativemessagebox`.
- Set the `NMB_NATIVE_PATH` environment variable during development.

## Windows STA requirement
If exceptions indicate an STA thread is required, run dialogs on the UI thread or disable validation:
```csharp
NativeMessageBoxClient.ConfigureHost(opts => opts.RequireStaThreadForWindows = false);
```
(Only do this when you are certain dialogs execute on a thread compatible with Task Dialog APIs.)

## GTK display errors
- Verify that the application is running in a graphical session and that `DISPLAY` is set.
- Install `libgtk-3` (or GTK 4) on Linux systems.
- For headless automation, ensure `zenity` is available for fallback behavior.

## macOS main thread warnings
Native dialogs must execute on the main thread. Ensure message boxes are invoked via the main application dispatcher.

## Timeout or cancellation unexpected
Inspect `MessageBoxResult.WasTimeout` to differentiate between user dismissal and automatic timeout. Set `TimeoutButtonId` to a value matching one of the configured buttons.

## Logging
Use `NativeMessageBoxClient.RegisterLogHandler` to capture diagnostics emitted by the native runtime. Logs help identify unsupported features or fallbacks.

