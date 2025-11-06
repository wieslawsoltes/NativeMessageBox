using System;

namespace NativeMessageBox;

public sealed class NativeMessageBoxHostOptions
{
    public bool RequireStaThreadForWindows { get; set; } = true;

    public AndroidHostOptions Android { get; } = new();
}

public sealed class AndroidHostOptions
{
    /// <summary>
    /// Provides a handle to the foreground Android <c>Activity</c>. The handle should be a JNI global reference when the provider owns it.
    /// </summary>
    public Func<AndroidActivityReference>? ActivityReferenceProvider { get; set; }
}

public readonly struct AndroidActivityReference : IDisposable
{
    public static AndroidActivityReference None => default;

    public AndroidActivityReference(IntPtr handle, bool ownsHandle)
    {
        Handle = handle;
        OwnsHandle = ownsHandle;
    }

    public IntPtr Handle { get; }

    public bool OwnsHandle { get; }

    public void Dispose()
    {
        if (!OwnsHandle || Handle == IntPtr.Zero)
        {
            return;
        }

        ReleaseHandle(Handle);
    }

    private static void ReleaseHandle(IntPtr handle)
    {
#if ANDROID
        Android.Runtime.JNIEnv.DeleteGlobalRef(handle);
#else
        _ = handle;
#endif
    }
}
