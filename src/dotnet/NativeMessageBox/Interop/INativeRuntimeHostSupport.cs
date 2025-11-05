using System;

namespace NativeMessageBox.Interop;

internal interface INativeRuntimeHostSupport
{
    void Configure(Action<NativeMessageBoxHostOptions> configure);
    void RegisterNativeLibraryPath(string path);
    void RegisterLogHandler(Action<string>? handler);
}

