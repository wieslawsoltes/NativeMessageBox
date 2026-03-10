---
title: "Feature Matrix"
---

# Feature Matrix

This table summarizes the runtime behavior that matters most when you design a cross-platform dialog flow.

| Capability | Windows | macOS | Linux (GTK) | iOS | Android | Web |
| --- | --- | --- | --- | --- | --- | --- |
| Multi-button dialogs | Yes | Yes | Yes | Yes | Partial | Yes |
| Custom button text and IDs | Yes | Yes | Yes | Yes | Yes | Yes |
| Default/cancel/destructive hints | Yes | Yes | Partial | Yes | Partial | Yes |
| Standard icons | Yes | Yes | Yes | No | No | No |
| Verification checkbox | Yes | Yes | Yes | No | No | Yes |
| Text/password input | No | Yes | Yes | Yes | No | Yes |
| Combo box input | No | Yes | Yes | No | No | Yes |
| Secondary content | Yes | Yes | Yes | No | No | Yes |
| Help links | Yes | Yes | Yes | No | No | No |
| Timeout support | Yes | Yes | Yes | Yes | No | Yes |

## Artifact Matrix

| Output | Producer |
| --- | --- |
| NuGet package | `dotnet pack` |
| RID runtime zip | Native build + packaging scripts |
| Android AAR | `build/scripts/package-android-aar.sh` |
| iOS XCFramework | `build/scripts/package-ios-xcframework.sh` |
| Browser package | `build/scripts/package-wasm.sh` |

## Related

- [Platform Capabilities](../concepts/platform-capabilities.md)
- [Building and Packaging](../guides/building-and-packaging.md)
