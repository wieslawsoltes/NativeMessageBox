# Quick Start Guide

## .NET Consumers
1. **Install the package** (once published):
   ```bash
   dotnet add package NativeMessageBox
   ```
2. **Configure the host** (optional) and display a dialog:
   ```csharp
   using NativeMessageBox;

   NativeMessageBoxClient.ConfigureHost(opts => opts.RequireStaThreadForWindows = false);

   var options = new MessageBoxOptions(
       message: "Welcome to the native message box!",
       title: "Hello",
       icon: MessageBoxIcon.Information);

   var result = NativeMessageBoxClient.Show(options);
   if (result.Outcome == MessageBoxOutcome.Success)
   {
       Console.WriteLine($"Button {result.ButtonId} selected");
   }
   ```
3. For WPF/WinForms applications ensure calls happen on an STA thread (default host enforces this when advanced features are requested).

## Native C/C++ Consumers
1. **Include the header** and link against the platform-specific `nativemessagebox` library.
   ```c
   #include "native_message_box.h"
   ```
2. **Initialize and show a dialog**:
   ```c
   NmbInitializeOptions init = {0};
   init.struct_size = sizeof(init);
   init.abi_version = NMB_ABI_VERSION;
   nmb_initialize(&init);

   NmbMessageBoxOptions opts = {0};
   opts.struct_size = sizeof(opts);
   opts.abi_version = NMB_ABI_VERSION;
   opts.message_utf8 = "Operation completed successfully";
   opts.title_utf8 = "Status";
   opts.icon = NMB_ICON_INFORMATION;

   NmbMessageBoxResult result = {0};
   result.struct_size = sizeof(result);

   NmbResultCode rc = nmb_show_message_box(&opts, &result);
   if (rc == NMB_OK)
   {
       // Inspect result.button, result.checkbox_checked, etc.
   }

   nmb_shutdown();
   ```
3. **Packaging**: build scripts produce RID-specific ZIPs (`artifacts/native-<rid>.zip`) containing the shared library, optional symbol files, and `manifest.json` metadata.

## Running the Samples
- Build solution: `dotnet build samples/AvaloniaSamples.sln`
- Run showcase: `dotnet run --project samples/Showcase`
- Run playground: `dotnet run --project samples/DialogPlayground`

