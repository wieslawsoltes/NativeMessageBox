using System;
using System.Runtime.InteropServices.JavaScript;
using System.Runtime.Versioning;
using System.Threading.Tasks;

namespace NativeMessageBox.Interop;

[SupportedOSPlatform("browser")]
internal static partial class NativeMessageBoxBrowserInterop
{
    [JSImport("globalThis.NativeMessageBoxManaged.initialize")]
    internal static partial void Initialize([JSMarshalAs<JSType.String>] string? runtimeName);

    [JSImport("globalThis.NativeMessageBoxManaged.enableLogging")]
    internal static partial void EnableLogging();

    [JSImport("globalThis.NativeMessageBoxManaged.disableLogging")]
    internal static partial void DisableLogging();

    [JSImport("globalThis.NativeMessageBoxManaged.shutdown")]
    internal static partial void Shutdown();

    [JSImport("globalThis.NativeMessageBoxManaged.showMessageBox")]
    internal static partial Task<string> ShowMessageBox([JSMarshalAs<JSType.String>] string requestJson);

    private static Action<string>? s_logForwarder;

    internal static void ConfigureLogForwarder(Action<string>? handler)
    {
        s_logForwarder = handler;
        if (handler is null)
        {
            DisableSafe();
        }
        else
        {
            EnableSafe();
        }
    }

    [JSExport]
    internal static void DispatchLog([JSMarshalAs<JSType.String>] string message)
    {
        s_logForwarder?.Invoke(message);
    }

    private static void EnableSafe()
    {
        try
        {
            EnableLogging();
        }
        catch (JSException)
        {
            // Ignore logging setup failures; browser host will fall back to console.
        }
    }

    private static void DisableSafe()
    {
        try
        {
            DisableLogging();
        }
        catch (JSException)
        {
            // Swallow shutdown failures for logging disable.
        }
    }
}
