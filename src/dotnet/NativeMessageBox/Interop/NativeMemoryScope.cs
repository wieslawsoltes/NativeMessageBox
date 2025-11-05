using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace NativeMessageBox.Interop;

internal sealed class NativeMemoryScope : IDisposable
{
    private readonly List<IntPtr> _allocations = new();

    public IntPtr AllocUtf8(string? value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return IntPtr.Zero;
        }

        var ptr = Marshal.StringToCoTaskMemUTF8(value);
        _allocations.Add(ptr);
        return ptr;
    }

    public IntPtr AllocStructArray<T>(ReadOnlySpan<T> data) where T : unmanaged
    {
        if (data.IsEmpty)
        {
            return IntPtr.Zero;
        }

        var size = Unsafe.SizeOf<T>() * data.Length;
        var ptr = Marshal.AllocCoTaskMem(size);
        unsafe
        {
            data.CopyTo(new Span<T>((void*)ptr, data.Length));
        }

        _allocations.Add(ptr);
        return ptr;
    }

    public IntPtr AllocPointerArray(ReadOnlySpan<IntPtr> data)
    {
        if (data.IsEmpty)
        {
            return IntPtr.Zero;
        }

        var size = IntPtr.Size * data.Length;
        var ptr = Marshal.AllocCoTaskMem(size);
        unsafe
        {
            data.CopyTo(new Span<IntPtr>((void*)ptr, data.Length));
        }

        _allocations.Add(ptr);
        return ptr;
    }

    public void Dispose()
    {
        foreach (var ptr in _allocations)
        {
            Marshal.FreeCoTaskMem(ptr);
        }

        _allocations.Clear();
    }
}

