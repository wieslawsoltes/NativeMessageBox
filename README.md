# NativeMessageBox

[![NuGet](https://img.shields.io/nuget/v/NativeMessageBox.svg)](https://www.nuget.org/packages/NativeMessageBox/)
[![NuGet (Downloads)](https://img.shields.io/nuget/dt/NativeMessageBox.svg)](https://www.nuget.org/packages/NativeMessageBox/)

NativeMessageBox is a production-ready native dialog runtime that ships a stable C ABI, high-level .NET 8 wrapper, and first-class tooling for Windows, macOS, Linux, iOS, and Android. The project focuses on predictable behaviour, strong diagnostics, and packaging that fits both managed and native distribution pipelines.

## Contents
- [Feature Summary](#feature-summary)
- [Feature Matrix](#feature-matrix)
- [Installation](#installation)
- [Usage](#usage)
- [Platform Implementations](#platform-implementations)
- [Building From Source](#building-from-source)
- [Samples](#samples)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

## Feature Summary

| Feature | Description |
| --- | --- |
| Stable C ABI | `include/native_message_box.h` exposes a forward-compatible ABI with explicit struct sizing, version negotiation, and allocator hooks. |
| Native implementations | Dedicated Windows (Task Dialog / MessageBox), macOS (NSAlert), Linux (GTK 3/4 with zenity fallback), iOS (UIKit), Android (AlertDialog), plus a WebAssembly browser overlay host. |
| Managed .NET 8 wrapper | `NativeMessageBox` NuGet package with source-generated interop, async APIs, configurable host abstraction, and logging hooks. |
| Rich dialog options | Multiple buttons, custom IDs, icons, verification checkboxes, timeouts, secondary content, and optional text/password/combo inputs (platform-dependent). |
| Mobile packaging | Automated AAR (Android) and XCFramework (iOS) outputs with manifests describing ABIs, architectures, and build metadata. |
| Tooling and CI | Cross-platform `build.sh`/`build.ps1`, native tests via `ctest`, managed unit tests, and packaging jobs suitable for CI/CD pipelines. |
| Samples | Avalonia desktop and mobile samples demonstrating host integration, lifecycle management, and advanced dialog scenarios. |
| Documentation | DocFX site under `docs/` covering architecture, API reference, troubleshooting, and platform-specific guidance. |

## Feature Matrix

| Capability | Windows | macOS | Linux (GTK) | iOS | Android | Web (Browser) |
| --- | --- | --- | --- | --- | --- | --- |
| Multi-button dialogs | Yes (Task Dialog supports 8+) | Yes | Yes | Yes | Partial (AlertDialog: 3 buttons) | Yes |
| Custom button text/IDs | Yes | Yes | Yes | Yes | Yes (first 3 buttons) | Yes |
| Button roles (default/cancel/destructive/help) | Yes | Yes | Partial (default/cancel) | Yes | Partial (positive/negative/neutral) | Yes (primary/cancel/destructive) |
| Standard icons | Yes | Yes | Yes | No (ignored) | No (ignored) | No (style via CSS) |
| Verification checkbox | Yes | Yes | Yes | No | No | Yes |
| Text/password input | No (planned) | Yes | Yes | Yes (text/password) | No | Yes |
| Combo box input | No | Yes | Yes | No | No | Yes |
| Secondary informative/expanded content | Yes | Yes | Yes | No | No | Yes |
| Help links / hyperlinks | Yes (Task Dialog hyperlink events) | Yes (opens via `NSWorkspace`) | Yes (GtkLinkButton) | No | No | No (render text only) |
| Auto-close timeout | Yes | Yes | Yes | Yes | No | Yes |
| Threading requirements | STA enforced for advanced dialogs | Must run on main thread | GTK main loop required | Must be called on main thread | Requires `Activity` on UI thread | Browser main thread (async overlay) |

> Notes: iOS ignores icons and secondary content but supports buttons, timeout, and single-line text/password input. Android is backed by `AlertDialog` and therefore limited to three buttons and no accessory controls. Windows falls back to `MessageBoxW` if Task Dialog APIs are unavailable.

## Installation

### .NET
```bash
dotnet add package NativeMessageBox
```

### Native C / C++
1. Download the appropriate runtime archive from `artifacts/native-<rid>.zip` (produced by the build).  
2. Add `include/native_message_box.h` to your project.  
3. Link against `nativemessagebox` for your runtime identifier (RID).  

### Mobile
- **Android**: Consume `artifacts/android/NativeMessageBox.aar` (or the published artifact) as an `<AndroidLibrary>` or Gradle dependency.  
- **iOS**: Add `artifacts/ios/NativeMessageBox.xcframework` as a native reference in Xcode or the .NET for iOS project system.  

## Usage

### .NET example

```csharp
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using NativeMessageBox;

static async Task<MessageBoxResult> ShowExportPromptAsync()
{
    NativeMessageBoxClient.ConfigureHost(options =>
    {
        // Allow background threads while still ensuring STA when required.
        options.RequireStaThreadForWindows = true;
    });

    NativeMessageBoxClient.RegisterLogHandler(message =>
    {
        Console.WriteLine($"[NativeMessageBox] {message}");
    });

    var buttons = new[]
    {
        new MessageBoxButton(100, "Export", MessageBoxButtonKind.Primary, isDefault: true),
        new MessageBoxButton(200, "Export && Open", MessageBoxButtonKind.Secondary),
        new MessageBoxButton(0, "Cancel", MessageBoxButtonKind.Secondary, isCancel: true)
    };

    var input = new MessageBoxInputOptions(
        MessageBoxInputMode.Text,
        prompt: "File name:",
        placeholder: "report.pdf",
        defaultValue: "report.pdf");

    var secondary = new MessageBoxSecondaryContent(
        informativeText: "Select how you would like to export the report.",
        expandedText: "Exports use the system temporary directory unless a custom path is provided.",
        footerText: "Need automation? Configure auto-export from Settings.",
        helpLink: "https://github.com/NativeMessageBox/NativeMessageBox/wiki/Export");

    var options = new MessageBoxOptions(
        message: "Export completed successfully. What would you like to do next?",
        buttons: buttons,
        title: "Export Finished",
        icon: MessageBoxIcon.Information,
        inputOptions: input,
        secondaryContent: secondary,
        verificationText: "Remember my choice",
        showSuppressCheckbox: true,
        timeout: TimeSpan.FromSeconds(30),
        timeoutButtonId: 0);

    return await NativeMessageBoxClient.ShowAsync(options);
}
```

The returned `MessageBoxResult` exposes `Outcome`, the selected `ButtonId`, any `InputValue`, `CheckboxChecked`, and whether the dialog timed out. Use `NativeMessageBoxClient.ShowOrThrow` when failure conditions should surface as exceptions.

### Native C example

```c
#include "native_message_box.h"

int main(void)
{
    NmbInitializeOptions init = {0};
    init.struct_size = sizeof(init);
    init.abi_version = NMB_ABI_VERSION;
    init.runtime_name_utf8 = "demo-app";
    nmb_initialize(&init);

    NmbButtonOption buttons[2] = {};
    buttons[0].struct_size = sizeof(NmbButtonOption);
    buttons[0].id = NMB_BUTTON_ID_OK;
    buttons[0].label_utf8 = "Retry";
    buttons[0].is_default = NMB_TRUE;

    buttons[1].struct_size = sizeof(NmbButtonOption);
    buttons[1].id = NMB_BUTTON_ID_CANCEL;
    buttons[1].label_utf8 = "Cancel";
    buttons[1].is_cancel = NMB_TRUE;

    NmbMessageBoxOptions options = {0};
    options.struct_size = sizeof(options);
    options.abi_version = NMB_ABI_VERSION;
    options.title_utf8 = "Connection lost";
    options.message_utf8 = "The remote endpoint is unavailable.";
    options.buttons = buttons;
    options.button_count = 2;
    options.icon = NMB_ICON_WARNING;
    options.timeout_milliseconds = 15000;
    options.timeout_button_id = NMB_BUTTON_ID_CANCEL;

    NmbMessageBoxResult result = {0};
    result.struct_size = sizeof(result);

    NmbResultCode rc = nmb_show_message_box(&options, &result);
    if (rc == NMB_OK)
    {
        // Inspect result.button, result.was_timeout, etc.
    }

    nmb_shutdown();
    return 0;
}
```

## Platform Implementations

### Windows
- Uses `TaskDialogIndirect` when available (Windows Vista+ with `comctl32` v6).  
- Falls back to `MessageBoxW` when advanced features are not requested or Task Dialog is unavailable.  
- Supports icons, verification checkbox, hyperlink footer, auto-close timers, and ESC/close policy controls.  
- Advanced scenarios require running on an STA thread; the managed host enforces this unless explicitly disabled.

### macOS
- Backed by `NSAlert`, accessory views, and `NSStackView` compositions.  
- Supports checkboxes, text/password fields, combo boxes, secondary informative text, footers, help buttons, and auto-close timers.  
- Requires invocation on the main thread. Timeout handling uses `dispatch_source_t` to trigger button actions safely.

### Linux (GTK 3/4)
- Implements dialogs via `GtkMessageDialog` and custom content areas.  
- Supports multiple buttons, checkbox verification, text/password/combo inputs, secondary/expanded text, help links, and timeouts via `g_timeout_add`.  
- Respects modality flags and ESC handling. When GTK is unavailable, the fallback shell path uses `zenity`.

### iOS
- Implements dialogs through `UIAlertController`.  
- Supports custom button labels, default/cancel/destructive roles, single text/password input, and timeouts using `dispatch_after`.  
- Ignores secondary content, verification checkboxes, and icon hints (these limitations are logged via the runtime callback). Requires a presenter `UIViewController`.

### Android
- Uses a lightweight Java bridge around `AlertDialog`.  
- Supports up to three buttons (positive/negative/neutral) with custom labels and IDs.  
- Does not support accessory input, verification checkboxes, icons, or auto-close timers.  
- Requires an `Activity` reference supplied through `MessageBoxOptions.ParentWindow`.

## Building From Source
- macOS / Linux: `./build/build.sh --all`  
- Windows / PowerShell 7+: `pwsh build/build.ps1 -All`  
- WebAssembly-only packaging: `./build/build.sh --wasm` (requires an Emscripten environment)  
- See `docs/building.md` for prerequisites, optional flags (`--skip-tests`, `--config Debug`, `-Targets android,ios,wasm`), and environment variables used by the Android/iOS packaging scripts.

## Samples
- `samples/Showcase` demonstrates feature coverage on desktop platforms.  
- `samples/DialogPlayground` enables experimenting with different button layouts, icons, and inputs.  
- `samples/CrossPlatformSample` targets desktop, Android, iOS, and the browser. Run `dotnet publish samples/CrossPlatformSample/NativeMessageBox.CrossPlatformSample.Browser -c Release` (optionally after `./build/scripts/package-wasm.sh`) to exercise the Web overlay.  
- Mobile samples consume the generated AAR/XCFramework to illustrate lifecycle integration. Build the solution via `dotnet build samples/AvaloniaSamples.sln`.

## Documentation
- Run `docs/build-docs.sh` to generate the DocFX site under `docs/docfx/_site`.  
- Key entry points: `docs/quickstart.md`, `docs/managed-api.md`, `docs/advanced-usage.md`, `docs/architecture.md`, `docs/android-packaging.md`, `docs/ios-packaging.md`, and `docs/browser-deployment.md`.

## Contributing
- Review `CONTRIBUTING.md`, `MAINTENANCE.md`, and `SECURITY.md`.  
- Use topic branches and include unit tests when extending native or managed functionality.  
- File issues with platform details, reproduction steps, and diagnostics captured via `NativeMessageBoxClient.RegisterLogHandler`.

## License

This project is licensed under the MIT License. See `LICENSE` for full details.
