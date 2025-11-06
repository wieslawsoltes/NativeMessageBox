using System;
using Android.App;
using NativeMessageBox;

namespace NativeMessageBox.CrossPlatformSample.Android;

internal static class NativeMessageBoxActivityTracker
{
    private static readonly object Sync = new();
    private static WeakReference<Activity>? s_currentActivity;
    private static bool s_configured;

    public static void ConfigureHost()
    {
        lock (Sync)
        {
            if (s_configured)
            {
                return;
            }

            NativeMessageBoxClient.ConfigureHost(options =>
            {
                options.Android.ActivityReferenceProvider = AcquireActivityReference;
            });

            s_configured = true;
        }
    }

    public static void OnActivityResumed(Activity activity)
    {
        lock (Sync)
        {
            s_currentActivity = new WeakReference<Activity>(activity);
        }
    }

    public static void OnActivityPaused(Activity activity)
    {
        lock (Sync)
        {
            if (s_currentActivity is not null &&
                s_currentActivity.TryGetTarget(out var tracked) &&
                ReferenceEquals(tracked, activity))
            {
                s_currentActivity = null;
            }
        }
    }

    private static AndroidActivityReference AcquireActivityReference()
    {
#if ANDROID
        lock (Sync)
        {
            if (s_currentActivity is not null &&
                s_currentActivity.TryGetTarget(out var activity) &&
                activity is not null)
            {
                var globalRef = Android.Runtime.JNIEnv.NewGlobalRef(activity.Handle);
                return new AndroidActivityReference(globalRef, ownsHandle: true);
            }
        }
#endif

        return AndroidActivityReference.None;
    }
}
