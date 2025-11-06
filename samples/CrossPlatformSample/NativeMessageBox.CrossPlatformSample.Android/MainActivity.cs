using Android.App;
using Android.Content.PM;
using Android.OS;
using Avalonia;
using Avalonia.Android;

namespace NativeMessageBox.CrossPlatformSample.Android;

[Activity(
    Label = "NativeMessageBox.CrossPlatformSample.Android",
    Theme = "@style/MyTheme.NoActionBar",
    Icon = "@drawable/icon",
    MainLauncher = true,
    ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize | ConfigChanges.UiMode)]
public class MainActivity : AvaloniaMainActivity<App>
{
    protected override void OnCreate(Bundle? savedInstanceState)
    {
        base.OnCreate(savedInstanceState);

        NativeMessageBoxActivityTracker.ConfigureHost();
    }

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

    protected override AppBuilder CustomizeAppBuilder(AppBuilder builder)
    {
        return base.CustomizeAppBuilder(builder)
            .WithInterFont();
    }
}
