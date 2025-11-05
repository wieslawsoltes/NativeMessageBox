using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;

namespace NativeMessageBox;

public sealed class MessageBoxOptions
{
    public MessageBoxOptions(
        string message,
        IEnumerable<MessageBoxButton>? buttons = null,
        string? title = null,
        MessageBoxIcon icon = MessageBoxIcon.None,
        MessageBoxSeverity severity = MessageBoxSeverity.Info,
        MessageBoxDialogModality modality = MessageBoxDialogModality.Application,
        IntPtr parentWindow = default,
        MessageBoxInputOptions? inputOptions = null,
        MessageBoxSecondaryContent? secondaryContent = null,
        string? verificationText = null,
        bool allowCancelViaEscape = true,
        bool showSuppressCheckbox = false,
        bool requiresExplicitAcknowledgement = false,
        TimeSpan? timeout = null,
        uint? timeoutButtonId = null,
        string? locale = null,
        object? tag = null)
    {
        if (string.IsNullOrWhiteSpace(message))
        {
            throw new ArgumentException("Message text must be provided.", nameof(message));
        }

        var buttonList = buttons?.ToList() ?? new List<MessageBoxButton>
        {
            new(NativeButtonIds.Ok, "OK", MessageBoxButtonKind.Primary, isDefault: true)
        };

        if (buttonList.Count == 0)
        {
            throw new ArgumentException("At least one button must be specified.", nameof(buttons));
        }

        Message = message;
        Buttons = new ReadOnlyCollection<MessageBoxButton>(buttonList);
        Title = title;
        Icon = icon;
        Severity = severity;
        Modality = modality;
        ParentWindow = parentWindow;
        InputOptions = inputOptions;
        SecondaryContent = secondaryContent;
        VerificationText = verificationText;
        AllowCancelViaEscape = allowCancelViaEscape;
        ShowSuppressCheckbox = showSuppressCheckbox;
        RequiresExplicitAcknowledgement = requiresExplicitAcknowledgement;
        Timeout = timeout;
        TimeoutButtonId = timeoutButtonId;
        Locale = locale;
        Tag = tag;

        Capabilities = new PlatformCapabilities(this);
    }

    public string? Title { get; }

    public string Message { get; }

    public IReadOnlyList<MessageBoxButton> Buttons { get; }

    public MessageBoxIcon Icon { get; }

    public MessageBoxSeverity Severity { get; }

    public MessageBoxDialogModality Modality { get; }

    public IntPtr ParentWindow { get; }

    public MessageBoxInputOptions? InputOptions { get; }

    public MessageBoxSecondaryContent? SecondaryContent { get; }

    public string? VerificationText { get; }

    public bool AllowCancelViaEscape { get; }

    public bool ShowSuppressCheckbox { get; }

    public bool RequiresExplicitAcknowledgement { get; }

    public TimeSpan? Timeout { get; }

    public uint? TimeoutButtonId { get; }

    public string? Locale { get; }

    public object? Tag { get; }

    public PlatformCapabilities Capabilities { get; }

    public sealed class PlatformCapabilities
    {
        internal PlatformCapabilities(MessageBoxOptions options)
        {
            RequiresStaOnWindows = options.RequiresExplicitAcknowledgement ||
                                   options.InputOptions is { Mode: not MessageBoxInputMode.None } ||
                                   options.SecondaryContent != null ||
                                   (options.Timeout.HasValue && options.Timeout.Value > TimeSpan.Zero);

            SupportsWindowsInput = options.InputOptions is null ||
                                   options.InputOptions.Mode is MessageBoxInputMode.None or MessageBoxInputMode.Checkbox;

            LocaleSupported = false;
        }

        public bool RequiresStaOnWindows { get; }

        public bool SupportsWindowsInput { get; }

        public bool LocaleSupported { get; }
    }
}

internal static class NativeButtonIds
{
    internal const uint Ok = (uint)Interop.NmbButtonId.Ok;
}
