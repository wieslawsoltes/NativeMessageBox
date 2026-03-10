---
title: "Installation"
---

# Installation

NativeMessageBox can be consumed as a .NET package, a native runtime package, or a platform-specific mobile/browser artifact set.

## .NET Package

```bash
dotnet add package NativeMessageBox
```

The NuGet package contains the managed API plus runtime folders for supported targets. If you package your application manually, verify the native runtime assets remain next to the app or in a location registered through <xref:NativeMessageBox.NativeMessageBoxClient.RegisterNativeLibraryPath(System.String)>.

## Native C / C++

For native consumers:

1. Include `include/native_message_box.h`.
2. Ship the matching `nativemessagebox` runtime binary for your platform.
3. Call `nmb_initialize` once at startup if you want logging or allocator hooks.

The build pipeline produces RID-specific runtime archives under `artifacts/`.

## Mobile Artifacts

| Platform | Artifact | Notes |
| --- | --- | --- |
| Android | `NativeMessageBox.aar` | Includes the Java bridge plus native `.so` binaries |
| iOS | `NativeMessageBox.xcframework` | Contains simulator and device slices |
| Browser | `native-message-box.js` and optional `libnativemessagebox.wasm` | Used by the custom browser host |

## First Integration Checks

- The application can locate the native runtime.
- The platform restrictions are understood before advanced dialogs are used.
- Mobile projects provide the required host context.
- Browser deployments copy the JavaScript host file into the published output.

## When to Register a Custom Native Path

Use <xref:NativeMessageBox.NativeMessageBoxClient.RegisterNativeLibraryPath(System.String)> when:

- You extract the native runtime to a custom cache directory
- Your packaging system does not preserve the default NuGet runtime layout
- You probe different runtime folders at startup

## Next

- Continue to [Quickstart (.NET)](quickstart-dotnet.md) for the most common integration path.
- Use [Quickstart (C ABI)](quickstart-native.md) if you are wiring a native or FFI caller.
- See [Building and Packaging](../guides/building-and-packaging.md) when you want to produce artifacts from source.
