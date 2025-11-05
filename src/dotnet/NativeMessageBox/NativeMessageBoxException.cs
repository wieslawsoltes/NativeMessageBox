using System;
using NativeMessageBox.Interop;

namespace NativeMessageBox;

public class NativeMessageBoxException : Exception
{
    internal NativeMessageBoxException(string message, NmbResultCode resultCode, Exception? innerException = null)
        : base(message, innerException)
    {
        Outcome = ResultMapper.ToOutcome(resultCode);
        NativeResultCode = (uint)resultCode;
    }

    internal NativeMessageBoxException(string message, MessageBoxResult result, Exception? innerException = null)
        : base(message, innerException)
    {
        Outcome = result.Outcome;
        NativeResultCode = result.NativeResultCode;
        Result = result;
    }

    public MessageBoxOutcome Outcome { get; }

    public uint NativeResultCode { get; }

    public MessageBoxResult? Result { get; }
}

public sealed class NativeMessageBoxInitializationException : NativeMessageBoxException
{
    internal NativeMessageBoxInitializationException(string message, NmbResultCode code, Exception? innerException = null)
        : base(message, code, innerException)
    {
    }

    internal NativeMessageBoxInitializationException(string message, MessageBoxResult result, Exception? innerException = null)
        : base(message, result, innerException)
    {
    }
}

