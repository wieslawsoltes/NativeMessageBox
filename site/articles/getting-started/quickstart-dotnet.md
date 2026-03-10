---
title: "Quickstart (.NET)"
---

# Quickstart (.NET)

This example shows the managed API path built around <xref:NativeMessageBox.NativeMessageBoxClient>.

## Minimal Async Flow

```csharp
using System;
using System.Threading.Tasks;
using NativeMessageBox;

static async Task<int> Main()
{
    NativeMessageBoxClient.ConfigureHost(options =>
    {
        options.RequireStaThreadForWindows = true;
    });

    NativeMessageBoxClient.RegisterLogHandler(message =>
    {
        Console.WriteLine($"[NativeMessageBox] {message}");
    });

    var options = new MessageBoxOptions(
        message: "Delete generated files before rebuilding?",
        buttons:
        [
            new MessageBoxButton(100, "Delete", MessageBoxButtonKind.Destructive, isDefault: true),
            new MessageBoxButton(0, "Cancel", MessageBoxButtonKind.Secondary, isCancel: true)
        ],
        title: "Clean Output",
        icon: MessageBoxIcon.Warning,
        verificationText: "Do not ask again",
        showSuppressCheckbox: true,
        timeout: TimeSpan.FromSeconds(20),
        timeoutButtonId: 0);

    MessageBoxResult result = await NativeMessageBoxClient.ShowAsync(options);

    if (result.Outcome == MessageBoxOutcome.Success && result.ButtonId == 100)
    {
        Console.WriteLine("Proceed with cleanup.");
    }

    return 0;
}
```

## What the Example Uses

- <xref:NativeMessageBox.MessageBoxOptions> to describe the dialog
- <xref:NativeMessageBox.MessageBoxButton> for explicit button identifiers and roles
- <xref:NativeMessageBox.NativeMessageBoxHostOptions> to configure host behavior
- <xref:NativeMessageBox.MessageBoxResult> to inspect the outcome

## Common Extensions

- Add <xref:NativeMessageBox.MessageBoxInputOptions> when you need text, password, combo, or checkbox input
- Add <xref:NativeMessageBox.MessageBoxSecondaryContent> when the platform supports informative or expandable secondary text
- Use `ShowOrThrow` when non-success outcomes should be exceptional in your application flow

## Windows Note

On Windows, advanced dialog features may require an STA thread. The managed host exposes that through `RequireStaThreadForWindows`, and <xref:NativeMessageBox.MessageBoxOptions.PlatformCapabilities> lets you inspect whether a given request needs that path.

## API Coverage Checklist

- <xref:NativeMessageBox.NativeMessageBoxClient>
- <xref:NativeMessageBox.MessageBoxOptions>
- <xref:NativeMessageBox.MessageBoxButton>
- <xref:NativeMessageBox.MessageBoxResult>
- <xref:NativeMessageBox.NativeMessageBoxHostOptions>

## Related

- [Dialog Options and Results](../concepts/dialog-options-and-results.md)
- [Threading and Host Customization](../advanced/threading-and-hosts.md)
- [Troubleshooting](../guides/troubleshooting.md)
