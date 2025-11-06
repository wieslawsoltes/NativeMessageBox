using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices.JavaScript;
using System.Runtime.Versioning;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;
using NativeMessageBox;

namespace NativeMessageBox.Interop;

[SupportedOSPlatform("browser")]
internal sealed class NativeMessageBoxBrowserHost : INativeMessageBoxHost, INativeRuntimeHostSupport
{
    private readonly object _sync = new();
    private readonly NativeMessageBoxHostOptions _options = new();
    private bool _initialized;
    private Action<string>? _logHandler;
    private Action<string>? _logForwarder;
    private string? _runtimeName;

    private static readonly JsonSerializerOptions s_jsonOptions = new(JsonSerializerDefaults.Web)
    {
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

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
        // Browser host relies on JS interop; explicit native probing paths are not applicable.
        if (!string.IsNullOrWhiteSpace(path))
        {
            _logHandler?.Invoke($"NativeMessageBox browser host ignoring native path registration: {path}.");
        }
    }

    public void RegisterLogHandler(Action<string>? handler)
    {
        lock (_sync)
        {
            _logHandler = handler;
            _logForwarder = handler is null ? null : message => handler(message);

            if (_initialized)
            {
                NativeMessageBoxBrowserInterop.ConfigureLogForwarder(_logForwarder);
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

            _runtimeName ??= AppDomain.CurrentDomain.FriendlyName;
            NativeMessageBoxBrowserInterop.Initialize(_runtimeName);
            NativeMessageBoxBrowserInterop.ConfigureLogForwarder(_logForwarder);
            _initialized = true;
            _logHandler?.Invoke("NativeMessageBox browser host initialized.");
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

            NativeMessageBoxBrowserInterop.ConfigureLogForwarder(null);
            NativeMessageBoxBrowserInterop.Shutdown();
            _initialized = false;
            _logHandler?.Invoke("NativeMessageBox browser host shutdown.");
        }
    }

    public MessageBoxResult Show(MessageBoxOptions options)
    {
        ArgumentNullException.ThrowIfNull(options);
        EnsureInitialized();

        try
        {
            var response = ExecuteShowAsync(options, CancellationToken.None).GetAwaiter().GetResult();
            return response;
        }
        catch (JSException ex)
        {
            throw new NativeMessageBoxException("Browser message box host invocation failed.", NmbResultCode.PlatformFailure, ex);
        }
    }

    public bool TryShow(MessageBoxOptions options, out MessageBoxResult result)
    {
        try
        {
            result = Show(options);
            return result.Outcome is MessageBoxOutcome.Success or MessageBoxOutcome.Cancelled;
        }
        catch (NativeMessageBoxException ex)
        {
            result = ex.Result ?? new MessageBoxResult(0, false, null, false, ex.Outcome, options.Tag, ex.NativeResultCode);
            return false;
        }
        catch (JSException)
        {
            result = new MessageBoxResult(0, false, null, false, MessageBoxOutcome.PlatformFailure, options.Tag, (uint)NmbResultCode.PlatformFailure);
            return false;
        }
    }

    public Task<MessageBoxResult> ShowAsync(MessageBoxOptions options, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(options);
        cancellationToken.ThrowIfCancellationRequested();
        EnsureInitialized();
        return ExecuteShowAsync(options, cancellationToken);
    }

    public async Task<(bool Success, MessageBoxResult Result)> TryShowAsync(MessageBoxOptions options, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(options);
        cancellationToken.ThrowIfCancellationRequested();
        EnsureInitialized();

        try
        {
            var result = await ExecuteShowAsync(options, cancellationToken).ConfigureAwait(false);
            return (result.Outcome is MessageBoxOutcome.Success or MessageBoxOutcome.Cancelled, result);
        }
        catch (NativeMessageBoxException ex)
        {
            var fallback = ex.Result ?? new MessageBoxResult(0, false, null, false, ex.Outcome, options.Tag, ex.NativeResultCode);
            return (false, fallback);
        }
        catch (JSException)
        {
            var fallback = new MessageBoxResult(0, false, null, false, MessageBoxOutcome.PlatformFailure, options.Tag, (uint)NmbResultCode.PlatformFailure);
            return (false, fallback);
        }
    }

    private static string SerializeRequest(MessageBoxOptions options)
    {
        var request = BrowserMessageBoxRequest.FromOptions(options);
        return JsonSerializer.Serialize(request, s_jsonOptions);
    }

    private static MessageBoxResult ParseResponse(string json, MessageBoxOptions options)
    {
        if (string.IsNullOrWhiteSpace(json))
        {
            throw new NativeMessageBoxException("Browser message box returned an empty response.", NmbResultCode.PlatformFailure);
        }

        BrowserMessageBoxResponse? response;
        try
        {
            response = JsonSerializer.Deserialize<BrowserMessageBoxResponse>(json, s_jsonOptions);
        }
        catch (JsonException ex)
        {
            throw new NativeMessageBoxException("Browser message box returned an invalid payload.", NmbResultCode.PlatformFailure, ex);
        }

        if (response is null)
        {
            throw new NativeMessageBoxException("Browser message box returned a null payload.", NmbResultCode.PlatformFailure);
        }

        var resultCode = (NmbResultCode)response.ResultCode;
        var outcome = ResultMapper.ToOutcome(resultCode);
        return new MessageBoxResult(
            buttonId: response.ButtonId,
            checkboxChecked: response.CheckboxChecked,
            inputValue: response.InputValue,
            wasTimeout: response.WasTimeout,
            outcome: outcome,
            tag: options.Tag,
            nativeResultCode: response.ResultCode);
    }

    private async Task<MessageBoxResult> ExecuteShowAsync(MessageBoxOptions options, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        var requestJson = SerializeRequest(options);
        var responseJson = await NativeMessageBoxBrowserInterop.ShowMessageBox(requestJson).ConfigureAwait(false);
        return ParseResponse(responseJson, options);
    }

    private sealed class BrowserMessageBoxRequest
    {
        public string? Title { get; set; }
        public string Message { get; set; } = string.Empty;
        public List<BrowserMessageBoxButton> Buttons { get; set; } = new();
        public uint Icon { get; set; }
        public uint Severity { get; set; }
        public uint Modality { get; set; }
        public string? VerificationText { get; set; }
        public bool AllowEscape { get; set; }
        public bool ShowSuppressCheckbox { get; set; }
        public bool RequiresExplicitAck { get; set; }
        public uint TimeoutMilliseconds { get; set; }
        public uint TimeoutButtonId { get; set; }
        public string? Locale { get; set; }
        public BrowserMessageBoxInput? Input { get; set; }
        public BrowserMessageBoxSecondary? Secondary { get; set; }

        public static BrowserMessageBoxRequest FromOptions(MessageBoxOptions options)
        {
            var request = new BrowserMessageBoxRequest
            {
                Title = string.IsNullOrWhiteSpace(options.Title) ? null : options.Title,
                Message = options.Message ?? string.Empty,
                Icon = (uint)options.Icon,
                Severity = (uint)options.Severity,
                Modality = options.Modality switch
                {
                    MessageBoxDialogModality.System => (uint)NmbDialogModality.System,
                    MessageBoxDialogModality.Window => (uint)NmbDialogModality.Window,
                    _ => (uint)NmbDialogModality.App
                },
                VerificationText = string.IsNullOrWhiteSpace(options.VerificationText) ? null : options.VerificationText,
                AllowEscape = options.AllowCancelViaEscape,
                ShowSuppressCheckbox = options.ShowSuppressCheckbox,
                RequiresExplicitAck = options.RequiresExplicitAcknowledgement,
                TimeoutMilliseconds = options.Timeout.HasValue && options.Timeout.Value > TimeSpan.Zero
                    ? (uint)Math.Clamp(options.Timeout.Value.TotalMilliseconds, 0, uint.MaxValue)
                    : 0,
                TimeoutButtonId = options.TimeoutButtonId.HasValue ? options.TimeoutButtonId.Value : 0,
                Locale = string.IsNullOrWhiteSpace(options.Locale) ? null : options.Locale
            };

            if (options.Buttons.Count == 0)
            {
                request.Buttons.Add(BrowserMessageBoxButton.DefaultOk());
            }
            else
            {
                request.Buttons.AddRange(options.Buttons.Select(BrowserMessageBoxButton.FromOption));
            }

            if (options.InputOptions is { Mode: not MessageBoxInputMode.None } input)
            {
                request.Input = BrowserMessageBoxInput.FromOptions(input);
            }

            if (options.SecondaryContent is { } secondary)
            {
                request.Secondary = BrowserMessageBoxSecondary.FromOptions(secondary);
            }

            return request;
        }
    }

    private sealed class BrowserMessageBoxButton
    {
        public uint Id { get; set; }
        public string Label { get; set; } = string.Empty;
        public string? Description { get; set; }
        public uint Kind { get; set; }
        public bool IsDefault { get; set; }
        public bool IsCancel { get; set; }

        public static BrowserMessageBoxButton FromOption(MessageBoxButton button)
        {
            return new BrowserMessageBoxButton
            {
                Id = button.Id,
                Label = button.Label ?? string.Empty,
                Description = string.IsNullOrWhiteSpace(button.Description) ? null : button.Description,
                Kind = (uint)button.Kind,
                IsDefault = button.IsDefault,
                IsCancel = button.IsCancel
            };
        }

        public static BrowserMessageBoxButton DefaultOk() =>
            new()
            {
                Id = (uint)NmbButtonId.Ok,
                Label = "OK",
                Kind = (uint)NmbButtonKind.Primary,
                IsDefault = true
            };
    }

    private sealed class BrowserMessageBoxInput
    {
        public uint Mode { get; set; }
        public string? Prompt { get; set; }
        public string? Placeholder { get; set; }
        public string? DefaultValue { get; set; }
        public List<string>? ComboItems { get; set; }

        public static BrowserMessageBoxInput FromOptions(MessageBoxInputOptions options)
        {
            var input = new BrowserMessageBoxInput
            {
                Mode = (uint)options.Mode,
                Prompt = string.IsNullOrWhiteSpace(options.Prompt) ? null : options.Prompt,
                Placeholder = string.IsNullOrWhiteSpace(options.Placeholder) ? null : options.Placeholder,
                DefaultValue = string.IsNullOrWhiteSpace(options.DefaultValue) ? null : options.DefaultValue
            };

            if (options.Mode == MessageBoxInputMode.Combo && options.ComboItems.Count > 0)
            {
                input.ComboItems = options.ComboItems.Select(item => item ?? string.Empty).ToList();
            }

            return input;
        }
    }

    private sealed class BrowserMessageBoxSecondary
    {
        public string? InformativeText { get; set; }
        public string? ExpandedText { get; set; }
        public string? FooterText { get; set; }
        public string? HelpLink { get; set; }

        public static BrowserMessageBoxSecondary FromOptions(MessageBoxSecondaryContent options) =>
            new()
            {
                InformativeText = string.IsNullOrWhiteSpace(options.InformativeText) ? null : options.InformativeText,
                ExpandedText = string.IsNullOrWhiteSpace(options.ExpandedText) ? null : options.ExpandedText,
                FooterText = string.IsNullOrWhiteSpace(options.FooterText) ? null : options.FooterText,
                HelpLink = string.IsNullOrWhiteSpace(options.HelpLink) ? null : options.HelpLink
            };
    }

    private sealed class BrowserMessageBoxResponse
    {
        public uint ResultCode { get; set; }
        public uint ButtonId { get; set; }
        public bool CheckboxChecked { get; set; }
        public bool WasTimeout { get; set; }
        public string? InputValue { get; set; }
    }
}
