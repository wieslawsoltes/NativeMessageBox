using NativeMessageBox;

namespace NativeMessageBox.Interop;

internal static class ResultMapper
{
    internal static MessageBoxOutcome ToOutcome(NmbResultCode code) =>
        code switch
        {
            NmbResultCode.Ok => MessageBoxOutcome.Success,
            NmbResultCode.Cancelled => MessageBoxOutcome.Cancelled,
            NmbResultCode.NotSupported => MessageBoxOutcome.NotSupported,
            NmbResultCode.PlatformFailure => MessageBoxOutcome.PlatformFailure,
            NmbResultCode.OutOfMemory => MessageBoxOutcome.OutOfMemory,
            NmbResultCode.InvalidArgument => MessageBoxOutcome.InvalidArgument,
            NmbResultCode.Uninitialized => MessageBoxOutcome.Uninitialized,
            _ => MessageBoxOutcome.Unknown
        };
}

