# Android Lifecycle Integration

For packaging instructions (including producing the Android AAR), see `docs/android-packaging.md`.

To surface the native message box on Android, the runtime needs a handle to the foreground `Activity`. Because activities can be recreated during configuration changes or background transitions, the managed host exposes `AndroidHostOptions.ActivityReferenceProvider` to acquire a valid JNI reference on demand.

## Tracking the Foreground Activity

The cross-platform sample includes `NativeMessageBoxActivityTracker`, which maintains a weak reference to the active activity and produces a JNI global reference for each call:

```csharp
public static void ConfigureHost()
{
    NativeMessageBoxClient.ConfigureHost(options =>
    {
        options.Android.ActivityReferenceProvider = () =>
        {
            var activity = TryGetForegroundActivity();
            if (activity is null)
            {
                return AndroidActivityReference.None;
            }

#if ANDROID
            var handle = Android.Runtime.JNIEnv.NewGlobalRef(activity.Handle);
            return new AndroidActivityReference(handle, ownsHandle: true);
#else
            return AndroidActivityReference.None;
#endif
        };
    });
}
```

The tracker listens to `OnResume`/`OnPause` to keep the weak reference in sync:

```csharp
protected override void OnResume()
{
    base.OnResume();
    NativeMessageBoxActivityTracker.OnActivityResumed(this);
}

protected override void OnPause()
{
    NativeMessageBoxActivityTracker.OnActivityPaused(this);
    base.OnPause();
}
```

The managed host automatically releases global references after each native call, so apps do not need to perform manual cleanup.

## UI Thread Dispatch

`NativeMessageBoxBridge` posts dialog creation to the main looper using `Handler`, guaranteeing that `AlertDialog` instances are constructed on the UI thread even when `NativeMessageBoxClient.Show` is invoked from a worker thread.

## Smoke Testing

The native layer still respects the existing test harness (`NMB_TESTING`) so instrumentation projects can verify Android plumbing without rendering UI. For example, a test can supply `NmbTestHarness` via `options.user_context` to exercise the managed host’s lifecycle guard while running headless.

For end-to-end validation, the sample’s instrumentation target can install a test callback on `NativeMessageBoxBridge` and assert that completion is signalled when the dialog auto-dismisses, ensuring the JNI bridge remains responsive through activity lifecycle transitions.
