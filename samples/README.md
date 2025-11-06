# Samples

Avalonia sample applications demonstrating the native message box API live here.

## Solutions

- `AvaloniaSamples.sln` — Aggregates the desktop-focused sample applications.
  - `Showcase` — Interactive gallery covering information, confirmation, custom buttons, and timeout scenarios.
  - `DialogPlayground` — Configurable playground for experimenting with message text, icons, inputs, and async display.
- `CrossPlatformSample/NativeMessageBox.CrossPlatformSample.sln` — Avalonia single-project template targeting Desktop, iOS, Android, and WebAssembly. The shared project references the managed `NativeMessageBox` library and reuses the native host via the new mobile implementations. See `samples/CrossPlatformSample/README.md` for full instructions.

Build and run (from repository root):

```bash
dotnet build samples/AvaloniaSamples.sln
dotnet run --project samples/Showcase
```

Both projects reference the managed `NativeMessageBox` library and demonstrate runtime host configuration.

### Cross-platform sample

The new cross-platform sample demonstrates invoking the native message box from a single Avalonia project.

- Desktop (macOS/Linux/Windows):
  ```bash
  dotnet run --project samples/CrossPlatformSample/NativeMessageBox.CrossPlatformSample.Desktop
  ```
- iOS (simulator):
  ```bash
  ./build/scripts/package-ios-xcframework.sh               # produces NativeMessageBox.xcframework
  dotnet build samples/CrossPlatformSample/NativeMessageBox.CrossPlatformSample.iOS -f net8.0-ios
  ```
- Android:
  ```bash
  ./build/scripts/package-android-aar.sh                   # produces NativeMessageBox.aar
  dotnet build samples/CrossPlatformSample/NativeMessageBox.CrossPlatformSample.Android -f net8.0-android
  ```

> The Android target now invokes the native bridge via JNI. Provide an emulator/device and ensure the activity tracker is wired (see `NativeMessageBoxActivityTracker`). The build automatically consumes the generated `NativeMessageBox.aar` when present. The iOS target consumes the packaged `NativeMessageBox.xcframework` generated in Phase 11.4.
