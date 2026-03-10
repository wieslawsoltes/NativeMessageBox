---
title: "Threading and Host Customization"
---

# Threading and Host Customization

Threading requirements are part of the product surface because the native dialog APIs are not uniform across platforms.

## Runtime Host Model

The default managed path routes calls through <xref:NativeMessageBox.INativeMessageBoxHost>. By default, <xref:NativeMessageBox.NativeMessageBoxClient> selects a runtime-backed host for native targets and a browser host when running in the browser.

## Host Configuration

<xref:NativeMessageBox.NativeMessageBoxHostOptions> exposes the main default-host knobs:

- `RequireStaThreadForWindows`
- Android activity resolution through <xref:NativeMessageBox.AndroidHostOptions>

## Platform Requirements

| Platform | Requirement |
| --- | --- |
| Windows | Advanced dialogs may require STA |
| macOS | Main-thread execution |
| Linux | GTK-compatible UI context |
| iOS | Main-thread presenter |
| Android | UI-thread activity presentation |
| Browser | Main-thread overlay flow |

## Custom Host Scenarios

Implement <xref:NativeMessageBox.INativeMessageBoxHost> when you need:

- Dispatcher-aware scheduling
- App-specific telemetry or logging
- Alternate error or retry policy
- A fake host for tests

## Related

- [Architecture and Request Flow](../concepts/architecture-and-flow.md)
- [Diagnostics and Runtime Loading](diagnostics-and-runtime-loading.md)
