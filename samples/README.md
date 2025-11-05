# Samples

Avalonia sample applications demonstrating the native message box API live here.

## Solution

- `AvaloniaSamples.sln` — Aggregates the sample applications.
  - `Showcase` — Interactive gallery covering information, confirmation, custom buttons, and timeout scenarios.
  - `DialogPlayground` — Configurable playground for experimenting with message text, icons, inputs, and async display.

Build and run (from repository root):

```bash
dotnet build samples/AvaloniaSamples.sln
dotnet run --project samples/Showcase
```

Both projects reference the managed `NativeMessageBox` library and demonstrate runtime host configuration.
