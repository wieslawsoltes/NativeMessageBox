using System;
using System.Threading;
using System.Threading.Tasks;
using NativeMessageBox.Interop;

namespace NativeMessageBox;

/// <summary>
/// High-level entry point for displaying cross-platform message boxes using a configurable host pipeline.
/// </summary>
public static class NativeMessageBoxClient
{
    private static readonly object s_hostLock = new();
    private static INativeMessageBoxHost s_host = CreateDefaultHost();

    public static INativeMessageBoxHost CurrentHost
    {
        get
        {
            lock (s_hostLock)
            {
                return s_host;
            }
        }
    }

    public static void UseHost(INativeMessageBoxHost host)
    {
        if (host == null)
        {
            throw new ArgumentNullException(nameof(host));
        }

        lock (s_hostLock)
        {
            s_host = host;
        }
    }

    public static void ConfigureHost(Action<NativeMessageBoxHostOptions> configure)
    {
        if (configure == null)
        {
            throw new ArgumentNullException(nameof(configure));
        }

        var runtimeSupport = GetRuntimeHostSupport();
        if (runtimeSupport == null)
        {
            throw new InvalidOperationException("The current host does not support runtime configuration.");
        }

        runtimeSupport.Configure(configure);
    }

    public static void RegisterNativeLibraryPath(string path)
    {
        var runtimeSupport = GetRuntimeHostSupport();
        if (runtimeSupport == null)
        {
            throw new InvalidOperationException("The current host does not support runtime library registration.");
        }

        runtimeSupport.RegisterNativeLibraryPath(path);
    }

    public static void RegisterLogHandler(Action<string>? handler)
    {
        var runtimeSupport = GetRuntimeHostSupport();
        if (runtimeSupport == null)
        {
            throw new InvalidOperationException("The current host does not support log handlers.");
        }

        runtimeSupport.RegisterLogHandler(handler);
    }

    public static void EnsureInitialized() => CurrentHost.EnsureInitialized();

    public static void Shutdown() => CurrentHost.Shutdown();

    public static MessageBoxResult Show(MessageBoxOptions options) => CurrentHost.Show(options);

    public static MessageBoxResult ShowOrThrow(MessageBoxOptions options)
    {
        var result = CurrentHost.Show(options);
        if (result.Outcome == MessageBoxOutcome.Success || result.Outcome == MessageBoxOutcome.Cancelled)
        {
            return result;
        }

        throw new NativeMessageBoxException("Native message box returned an error outcome.", result);
    }

    public static bool TryShow(MessageBoxOptions options, out MessageBoxResult result) => CurrentHost.TryShow(options, out result);

    public static Task<MessageBoxResult> ShowAsync(MessageBoxOptions options, CancellationToken cancellationToken = default) => CurrentHost.ShowAsync(options, cancellationToken);

    public static Task<(bool Success, MessageBoxResult Result)> TryShowAsync(MessageBoxOptions options, CancellationToken cancellationToken = default) => CurrentHost.TryShowAsync(options, cancellationToken);

    public static bool VerifyAbiCompatibility()
    {
        if (OperatingSystem.IsBrowser())
        {
            return true;
        }

        try
        {
            return NativeMessageBoxNative.GetAbiVersion() == NativeConstants.AbiVersion;
        }
        catch (DllNotFoundException)
        {
            return false;
        }
    }

    private static INativeRuntimeHostSupport? GetRuntimeHostSupport()
    {
        lock (s_hostLock)
        {
            return s_host as INativeRuntimeHostSupport;
        }
    }

    private static INativeMessageBoxHost CreateDefaultHost()
    {
        return OperatingSystem.IsBrowser()
            ? new NativeMessageBoxBrowserHost()
            : new NativeRuntimeMessageBoxHost();
    }
}
