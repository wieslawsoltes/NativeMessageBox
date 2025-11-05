using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using NativeMessageBox;

namespace NativeMessageBox.Interop;

internal sealed class NativeRuntimeMessageBoxHost : INativeMessageBoxHost, INativeRuntimeHostSupport
{
    private readonly object _sync = new();
    private readonly NativeMessageBoxHostOptions _options = new();
    private bool _initialized;
    private Action<string>? _logHandler;
    private IntPtr _logCallback;
    private IntPtr _logUserData;

    static NativeRuntimeMessageBoxHost()
    {
        NativeLibrary.SetDllImportResolver(typeof(NativeRuntimeMessageBoxHost).Assembly, NativeLibraryLoader.Resolve);
    }

    public void Configure(Action<NativeMessageBoxHostOptions> configure)
    {
        if (configure == null)
        {
            throw new ArgumentNullException(nameof(configure));
        }

        lock (_sync)
        {
            configure(_options);
        }
    }

    public void RegisterNativeLibraryPath(string path)
    {
        NativeLibraryLoader.RegisterProbingPath(path);
    }

    public void RegisterLogHandler(Action<string>? handler)
    {
        lock (_sync)
        {
            _logHandler = handler;
            NativeLogBridge.Configure(_logHandler, out _logCallback, out _logUserData);
            if (_initialized)
            {
                NativeMessageBoxNative.SetLogCallback(_logCallback, _logUserData);
            }
        }
    }

    public void EnsureInitialized()
    {
        if (_initialized)
        {
            return;
        }

        lock (_sync)
        {
            if (_initialized)
            {
                return;
            }

            var options = new NmbInitializeOptions
            {
                StructSize = (uint)Marshal.SizeOf<NmbInitializeOptions>(),
                AbiVersion = NativeConstants.AbiVersion
            };

            NativeLogBridge.Configure(_logHandler, out _logCallback, out _logUserData);
            options.LogCallback = _logCallback;
            options.LogUserData = _logUserData;

            NativeLibraryLoader.RegisterDevelopmentProbingPaths();

            try
            {
                var result = NativeMessageBoxNative.Initialize(ref options);
                if (result != NmbResultCode.Ok && result != NmbResultCode.PlatformFailure)
                {
                    throw new NativeMessageBoxInitializationException($"Native initialization failed with status {result}.", result);
                }

                _initialized = true;
            }
            catch (DllNotFoundException ex)
            {
                throw new NativeMessageBoxInitializationException("Native message box library not found on the probing path.", NmbResultCode.PlatformFailure, ex);
            }
            catch (EntryPointNotFoundException ex)
            {
                throw new NativeMessageBoxInitializationException("Native message box library is incompatible with the expected ABI.", NmbResultCode.NotSupported, ex);
            }
        }
    }

    public void Shutdown()
    {
        lock (_sync)
        {
            if (!_initialized)
            {
                return;
            }

            NativeMessageBoxNative.Shutdown();
            _initialized = false;
        }
    }

    public MessageBoxResult Show(MessageBoxOptions options)
    {
        ArgumentNullException.ThrowIfNull(options);
        EnsureInitialized();
        ValidateThread(options);
        ValidateCapabilities(options);

        using var scope = new NativeMemoryScope();
        var nativeOptions = NativeMessageBoxMarshaller.CreateNativeOptions(options, scope);
        var nativeResult = NativeMessageBoxMarshaller.CreateNativeResult();

        var status = NativeMessageBoxNative.ShowMessageBox(ref nativeOptions, ref nativeResult);
        if (status != NmbResultCode.Ok)
        {
            nativeResult.ResultCode = status;
        }

        return NativeMessageBoxMarshaller.ToManagedResult(ref nativeResult, options);
    }

    public bool TryShow(MessageBoxOptions options, out MessageBoxResult result)
    {
        try
        {
            result = Show(options);
            return result.Outcome == MessageBoxOutcome.Success || result.Outcome == MessageBoxOutcome.Cancelled;
        }
        catch (NativeMessageBoxException ex)
        {
            result = ex.Result ?? new MessageBoxResult(0, false, null, false, ex.Outcome, options.Tag, ex.NativeResultCode);
            return false;
        }
        catch (DllNotFoundException)
        {
            result = new MessageBoxResult(0, false, null, false, MessageBoxOutcome.PlatformFailure, options.Tag, (uint)NmbResultCode.PlatformFailure);
            return false;
        }
        catch (EntryPointNotFoundException)
        {
            result = new MessageBoxResult(0, false, null, false, MessageBoxOutcome.NotSupported, options.Tag, (uint)NmbResultCode.NotSupported);
            return false;
        }
    }

    public Task<MessageBoxResult> ShowAsync(MessageBoxOptions options, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(options);
        return Task.Run(() => Show(options), cancellationToken);
    }

    public Task<(bool Success, MessageBoxResult Result)> TryShowAsync(MessageBoxOptions options, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(options);
        return Task.Run(() =>
        {
            var success = TryShow(options, out var result);
            return (success, result);
        }, cancellationToken);
    }

    private void ValidateThread(MessageBoxOptions options)
    {
        if (!OperatingSystem.IsWindows())
        {
            return;
        }

        bool requireSta;
        lock (_sync)
        {
            requireSta = _options.RequireStaThreadForWindows;
        }

        if (!requireSta || !RequiresAdvancedWindowsFeatures(options))
        {
            return;
        }

        var apartment = Thread.CurrentThread.GetApartmentState();
        if (apartment != ApartmentState.STA)
        {
            throw new NativeMessageBoxException("Advanced Windows dialogs require an STA thread. Call NativeMessageBoxClient.ConfigureHost to disable this validation if necessary.", NmbResultCode.InvalidArgument);
        }
    }

    private void ValidateCapabilities(MessageBoxOptions options)
    {
        if (!string.IsNullOrWhiteSpace(options.Locale))
        {
            throw new NativeMessageBoxException(
                "Locale selection is not currently supported by the native backends.",
                NmbResultCode.NotSupported);
        }

        if (OperatingSystem.IsWindows())
        {
            if (options.InputOptions is { Mode: MessageBoxInputMode mode } &&
                mode is MessageBoxInputMode.Text or MessageBoxInputMode.Password or MessageBoxInputMode.Combo)
            {
                throw new NativeMessageBoxException(
                    "The Windows native message box only supports checkbox input. Use a custom dialog implementation for text, password, or combo inputs.",
                    NmbResultCode.NotSupported);
            }

            if (options.RequiresExplicitAcknowledgement && !options.AllowCancelViaEscape)
            {
                var apartment = Thread.CurrentThread.GetApartmentState();
                if (apartment != ApartmentState.STA)
                {
                    throw new NativeMessageBoxException(
                        "Explicit acknowledgement dialogs on Windows require STA threads.",
                        NmbResultCode.InvalidArgument);
                }
            }
        }
    }

    private static bool RequiresAdvancedWindowsFeatures(MessageBoxOptions options)
    {
        if (options.InputOptions is { Mode: not MessageBoxInputMode.None })
        {
            return true;
        }

        if (options.SecondaryContent != null)
        {
            return true;
        }

        if (!string.IsNullOrWhiteSpace(options.VerificationText) || options.ShowSuppressCheckbox || options.RequiresExplicitAcknowledgement)
        {
            return true;
        }

        if (options.Timeout.HasValue && options.Timeout.Value > TimeSpan.Zero)
        {
            return true;
        }

        if (options.TimeoutButtonId.HasValue)
        {
            return true;
        }

        return options.Buttons.Count > 3;
    }
}
