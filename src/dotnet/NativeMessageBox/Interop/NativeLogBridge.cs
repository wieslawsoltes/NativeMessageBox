using System;
using System.Runtime.InteropServices;

namespace NativeMessageBox.Interop;

internal static unsafe class NativeLogBridge
{
    private static Action<string>? s_handler;

    [UnmanagedCallersOnly]
    private static void Log(IntPtr userData, IntPtr message)
    {
        if (message == IntPtr.Zero)
        {
            return;
        }

        var text = Marshal.PtrToStringUTF8(message);
        s_handler?.Invoke(text ?? string.Empty);
    }

    internal static void Configure(Action<string>? handler, out IntPtr callback, out IntPtr userData)
    {
        s_handler = handler;
        userData = IntPtr.Zero;
        callback = handler != null ? (IntPtr)(delegate* unmanaged<IntPtr, IntPtr, void>)&Log : IntPtr.Zero;
    }
}

