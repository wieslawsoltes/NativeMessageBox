# Advanced Usage & Platform Notes

This guide expands on `docs/abi-spec.md` with practical guidance for building richer experiences with the native message box runtime and managed wrapper.

## Threading Requirements
- **Windows**: UI calls may originate from any thread. The runtime marshals to Task Dialog APIs when advanced features are requested. When `RequiresExplicitAcknowledgement` is true, the ESC key is disabled. Use `NativeMessageBoxClient.ConfigureHost(opts => opts.RequireStaThreadForWindows = false)` if you intentionally support non-STA contexts (defaults to enforcing STA when advanced features are requested).
- **macOS**: Message boxes must be invoked on the main thread. The native layer automatically dispatches to the main queue if required. Consumers embedding in macOS menu bar apps or background agents should call `nmb_initialize` early on the main thread.
- **Linux**: GTK requires an initialized event loop. The runtime calls `gtk_init_check` lazily and falls back to `zenity` when GTK cannot be initialized (e.g., headless environments). Parent window handles should be `GtkWindow*` pointers.

## Inputs & Secondary Content
- **Windows**: Task Dialogs provide secondary content, verification checkboxes, hyperlinks, and auto-dismiss timers. Checkbox inputs are supported via the verification control. Text/password inputs are not yet available on Windows and return `NMB_E_NOT_SUPPORTED`.
- **macOS**: Accessory views host text/password fields, combo boxes, and checkbox inputs. Expanded content is rendered as wrapped labels, and help buttons open URLs using the default browser.
- **Linux (GTK)**: Text/password inputs use `GtkEntry`; combo boxes use `GtkComboBoxText`; checkbox inputs leverage `GtkCheckButton`. Verification and input checkboxes are independent controls. When GTK is unavailable, a minimal `zenity` fallback handles single-button dialogs.

## Timeout & Cancellation
- **Windows**: Task dialogs support auto-dismiss timers. When `TimeoutButtonId` maps to a visible button, the dialog triggers that response and reports `was_timeout = true`.
- **macOS**: Auto-dismiss is not currently supported; requests with timeouts are treated as normal dialogs.
- **Linux**: GTK dialogs use `g_timeout_add` to fire button responses. Verification checkboxes and inputs remain valid on timeout.

## Asynchronous Patterns (.NET)
The managed API is synchronous by default. To integrate into asynchronous workflows:

```csharp
// Fire on a background thread to avoid blocking UI loops.
var result = await Task.Run(() => NativeMessageBoxClient.Show(options), cancellationToken);

if (result.Outcome == MessageBoxOutcome.Success && result.ButtonId == (uint)KnownButtonIds.Yes)
{
    // handle affirmative response
}
```

When targeting UI frameworks (e.g., Avalonia or WinUI), prefer scheduling on the appropriate dispatcher/main loop to maintain modality.

## Diagnostics & Logging
- Call `NativeMessageBoxClient.RegisterLogHandler` before `EnsureInitialized` to receive native log messages. The callback surfaces fallbacks (e.g., Task Dialog unavailability, GTK missing) and platform errors.
- You can update the log handler at runtime; the managed layer propagates the new delegate to the native runtime without requiring reinitialization.
- Swap in a custom implementation by calling `NativeMessageBoxClient.UseHost(...)` with your own `INativeMessageBoxHost` implementation when embedding the dialogs into bespoke environments.

## Native Library Probing
- `NativeMessageBoxClient` installs a custom `DllImportResolver` that probes the executing assembly directory followed by RID-specific folders such as `runtimes/win-x64/native`.
- Additional probing directories can be added via `NativeMessageBoxClient.RegisterNativeLibraryPath` or the `NMB_NATIVE_PATH` environment variable.
- Use the provided build scripts (`build/build.sh`, `build/build.ps1`) to produce native binaries and a NuGet package in `artifacts/nuget/` with per-platform outputs staged in the build tree and zipped per-RID (`artifacts/native-<rid>.zip`).

## Custom Hosts
The default runtime host is suitable for most scenarios, but you can supply your own `INativeMessageBoxHost` to integrate with custom dispatching models or telemetry pipelines.

```csharp
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Threading;

sealed class DispatcherMessageBoxHost : INativeMessageBoxHost
{
    private readonly INativeMessageBoxHost _inner;
    private readonly Dispatcher _dispatcher;

    public DispatcherMessageBoxHost(INativeMessageBoxHost inner, Dispatcher dispatcher)
    {
        _inner = inner;
        _dispatcher = dispatcher;
    }

    public void EnsureInitialized() => _dispatcher.Invoke(_inner.EnsureInitialized);
    public void Shutdown() => _dispatcher.Invoke(_inner.Shutdown);
    public MessageBoxResult Show(MessageBoxOptions options) => _dispatcher.Invoke(() => _inner.Show(options));
    public bool TryShow(MessageBoxOptions options, out MessageBoxResult result) =>
        _dispatcher.Invoke(() => _inner.TryShow(options, out result));
    public Task<MessageBoxResult> ShowAsync(MessageBoxOptions options, CancellationToken token = default) =>
        _dispatcher.InvokeAsync(() => _inner.ShowAsync(options, token)).Task.Unwrap();
    public Task<(bool Success, MessageBoxResult Result)> TryShowAsync(MessageBoxOptions options, CancellationToken token = default) =>
        _dispatcher.InvokeAsync(() => _inner.TryShowAsync(options, token)).Task.Unwrap();
}

// Capture the runtime host before replacing it, then wrap it.
var runtimeHost = NativeMessageBoxClient.CurrentHost;
NativeMessageBoxClient.UseHost(new DispatcherMessageBoxHost(runtimeHost, Dispatcher.CurrentDispatcher));
```

For simple tweaks (such as disabling STA validation), call `NativeMessageBoxClient.ConfigureHost` instead of writing a full wrapper.

## Memory Ownership
- Strings returned from the native layer are allocated via the caller-provided allocator. The managed wrapper supplies a `CoTaskMem` allocator so results can be released with `Marshal.FreeCoTaskMem`.
- Native consumers should set `NmbMessageBoxOptions::allocator` when custom allocation strategies (arena pools, tracking diagnostics) are required. When omitted, the runtime uses `CoTaskMemAlloc` on Windows and `malloc` elsewhere.

## Error Handling Recommendations
- Check the function return value (`NmbResultCode`) first. Non-`NMB_OK` values indicate platform issues (missing GTK, unsupported feature, cancelled operations).
- For managed callers, prefer `NativeMessageBoxClient.TryShow` to gracefully handle missing native binaries during development or in sandboxed environments.
- When `NMB_E_NOT_SUPPORTED` is returned, inspect the provided options and feature flags to determine fallback strategies (e.g., downgrade to simple informational dialog).
