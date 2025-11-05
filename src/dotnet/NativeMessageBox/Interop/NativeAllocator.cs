using System;
using System.Runtime.InteropServices;

namespace NativeMessageBox.Interop;

internal static unsafe class NativeAllocator
{
    [UnmanagedCallersOnly]
    private static IntPtr Allocate(IntPtr userData, nuint size, nuint alignment)
    {
        var byteCount = size == 0 ? 1 : size;
        if (byteCount > int.MaxValue)
        {
            byteCount = (nuint)int.MaxValue;
        }

        return Marshal.AllocCoTaskMem(checked((int)byteCount));
    }

    [UnmanagedCallersOnly]
    private static void Deallocate(IntPtr userData, IntPtr memory)
    {
        if (memory != IntPtr.Zero)
        {
            Marshal.FreeCoTaskMem(memory);
        }
    }

    internal static NmbAllocator Create()
    {
        return new NmbAllocator
        {
            Allocate = &Allocate,
            Deallocate = &Deallocate,
            UserData = IntPtr.Zero
        };
    }

    internal static void Release(IntPtr memory)
    {
        if (memory != IntPtr.Zero)
        {
            Marshal.FreeCoTaskMem(memory);
        }
    }
}
