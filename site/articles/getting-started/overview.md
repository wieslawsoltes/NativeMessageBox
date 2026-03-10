---
title: "Getting Started with NativeMessageBox"
---

# Getting Started with NativeMessageBox

NativeMessageBox gives you two integration surfaces:

- A high-level .NET client centered on <xref:NativeMessageBox.NativeMessageBoxClient>
- A stable C ABI exposed through `include/native_message_box.h`

Use the managed API when you are already shipping a .NET or Avalonia application. Use the C ABI when you need runtime-level integration from C, C++, Rust, Swift, Go, or another FFI consumer.

## What You Will Build

By the end of Getting Started, you will have:

- A working message box call in .NET or through the C ABI
- A clear understanding of which artifacts must ship with your app
- A mental model for buttons, optional input controls, secondary content, and result handling
- A path to desktop, mobile, and browser packaging

## Learning Path

1. [Installation](installation.md)
2. [Quickstart (.NET)](quickstart-dotnet.md)
3. [Quickstart (C ABI)](quickstart-native.md)
4. [Architecture and Request Flow](../concepts/architecture-and-flow.md)
5. [Dialog Options and Results](../concepts/dialog-options-and-results.md)
6. [Platform Capabilities](../concepts/platform-capabilities.md)

## Choose the Right Surface

| Surface | Best for | Main entry points |
| --- | --- | --- |
| .NET wrapper | Avalonia, desktop, mobile, browser, and general .NET applications | <xref:NativeMessageBox.NativeMessageBoxClient>, <xref:NativeMessageBox.MessageBoxOptions>, <xref:NativeMessageBox.MessageBoxResult> |
| C ABI | Native applications or custom interop layers | `nmb_initialize`, `nmb_show_message_box`, `nmb_shutdown` |

## Key Repository Artifacts

| Artifact | Purpose |
| --- | --- |
| `src/dotnet/NativeMessageBox` | Managed wrapper, host abstraction, marshaling, and diagnostics |
| `include/native_message_box.h` | Public ABI contract for native/FFI consumers |
| `src/native` | Per-platform implementations for Windows, macOS, Linux, iOS, Android, and browser |
| `artifacts/` | Generated runtime zips, AAR/XCFramework outputs, browser package, and NuGet package |
| `samples/` | Avalonia samples for desktop, mobile, and browser flows |

## First Recommendation

If you are evaluating the library, start with the [.NET quickstart](quickstart-dotnet.md) and then review [Platform Capabilities](../concepts/platform-capabilities.md). That path will show you the full feature envelope and where each platform narrows it.

## API Coverage Checklist

- <xref:NativeMessageBox.NativeMessageBoxClient>
- <xref:NativeMessageBox.MessageBoxOptions>
- <xref:NativeMessageBox.MessageBoxResult>
- <xref:NativeMessageBox.INativeMessageBoxHost>

## Related

- [Installation](installation.md)
- [Quickstart (.NET)](quickstart-dotnet.md)
- [Quickstart (C ABI)](quickstart-native.md)
- [Architecture and Request Flow](../concepts/architecture-and-flow.md)
