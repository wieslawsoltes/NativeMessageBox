using System;

namespace NativeMessageBox;

public sealed class MessageBoxResult
{
    public MessageBoxResult(uint buttonId, bool checkboxChecked, string? inputValue, bool wasTimeout, MessageBoxOutcome outcome, object? tag, uint nativeResultCode = 0)
    {
        ButtonId = buttonId;
        CheckboxChecked = checkboxChecked;
        InputValue = inputValue;
        WasTimeout = wasTimeout;
        Outcome = outcome;
        Tag = tag;
        NativeResultCode = nativeResultCode;
    }

    public uint ButtonId { get; }

    public bool CheckboxChecked { get; }

    public string? InputValue { get; }

    public bool WasTimeout { get; }

    public MessageBoxOutcome Outcome { get; }

    public object? Tag { get; }

    public uint NativeResultCode { get; }
}

public enum MessageBoxOutcome
{
    Success,
    Cancelled,
    NotSupported,
    PlatformFailure,
    OutOfMemory,
    InvalidArgument,
    Uninitialized,
    Unknown
}
