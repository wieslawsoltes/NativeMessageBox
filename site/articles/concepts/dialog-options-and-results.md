---
title: "Dialog Options and Results"
---

# Dialog Options and Results

The managed and native APIs model the same dialog concepts with different shapes.

## Managed Types

| Type | Purpose |
| --- | --- |
| <xref:NativeMessageBox.MessageBoxOptions> | The full dialog request |
| <xref:NativeMessageBox.MessageBoxButton> | Button identifier, label, style hint, and default/cancel flags |
| <xref:NativeMessageBox.MessageBoxInputOptions> | Optional checkbox, text, password, or combo input |
| <xref:NativeMessageBox.MessageBoxSecondaryContent> | Informative text, expanded text, footer, and help link |
| <xref:NativeMessageBox.MessageBoxResult> | Outcome, selected button, returned input, checkbox state, timeout flag |
| <xref:NativeMessageBox.NativeMessageBoxException> | Error wrapper for failure paths |

## Native Types

| C ABI type | Managed equivalent |
| --- | --- |
| `NmbMessageBoxOptions` | <xref:NativeMessageBox.MessageBoxOptions> |
| `NmbButtonOption` | <xref:NativeMessageBox.MessageBoxButton> |
| `NmbInputOption` | <xref:NativeMessageBox.MessageBoxInputOptions> |
| `NmbSecondaryContentOption` | <xref:NativeMessageBox.MessageBoxSecondaryContent> |
| `NmbMessageBoxResult` | <xref:NativeMessageBox.MessageBoxResult> |

## Modeling Rules

- At least one button is always present.
- The managed API synthesizes a default `OK` button when none are supplied.
- Input and secondary content are optional and may be downgraded by platform capabilities.
- Timeout and cancel behavior are represented explicitly rather than inferred from button IDs alone.

## Result Semantics

When a dialog completes, inspect:

- `Outcome` for success, cancellation, unsupported feature, or failure
- `ButtonId` for the selected button
- `InputValue` when text/password/combo input was present
- `CheckboxChecked` for verification/suppress state
- `WasTimeout` to distinguish automatic dismissal from user choice

## Capability Hints

<xref:NativeMessageBox.MessageBoxOptions.PlatformCapabilities> provides a small set of precomputed hints such as:

- Whether the request requires STA on Windows
- Whether the request uses Windows-unsupported input modes

These hints are not the full platform matrix, but they are useful for deciding whether a call should be scheduled differently.

## Related

- [Platform Capabilities](platform-capabilities.md)
- [Quickstart (.NET)](../getting-started/quickstart-dotnet.md)
- [C ABI and Versioning](../advanced/c-abi-and-versioning.md)
