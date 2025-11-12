# Browser Deployment Guide

This guide explains how to build, package, and host the WebAssembly/browser
experience for **NativeMessageBox**, including the optional `libnativemessagebox.wasm`
artifact, JavaScript overlay host, and Avalonia sample application.

## Prerequisites
- .NET 8 SDK (`8.0.x`) with browser workload (`dotnet workload install wasm-tools` if not already installed).
- Emscripten SDK (only required when you want to regenerate `libnativemessagebox.wasm`).
- Node.js/npm are *not* required; hosting can be static.

## Packaging Workflow

1. Build the browser sample (includes managed host):
   ```bash
   dotnet build samples/CrossPlatformSample/NativeMessageBox.CrossPlatformSample.Browser
   ```
   This copies `src/native/web/message_box.js` into
   `wwwroot/native-message-box.js`, ensuring the JavaScript overlay is always present.

2. *(Optional)* Compile the native WASM module:
   ```bash
   ./build/scripts/package-wasm.sh
   ```
   If `artifacts/web/` exists the browser project automatically adds:
   - `wwwroot/native/libnativemessagebox.wasm`
   - `wwwroot/native/libnativemessagebox.js`
   - `wwwroot/native/libnativemessagebox.wasm.map`

   These files are experimental until the native runtime integrates with
   JavaScript glue in a future phase, but publishing them alongside the sample
   allows inspection or manual loading.

3. Publish the web app:
   ```bash
   dotnet publish samples/CrossPlatformSample/NativeMessageBox.CrossPlatformSample.Browser -c Release
   ```
   The publish output under `bin/Release/net8.0-browser/publish/wwwroot/` is a
   static site ready for deployment.

## Hosting Considerations

- **HTTPS Required**: Browsers block modals triggered from insecure origins in many scenarios. Serve the app over HTTPS (or `localhost`) to avoid mixed-content issues.
- **Content-Security Policy**: Ensure the host allows inline scripts or reference the generated JS files explicitly (`native-message-box.js`, `_framework/dotnet.js`).
- **Caching**: The `libnativemessagebox.*` files are versioned only by timestamp.
  Configure cache headers or versioned URLs if you plan to update them frequently.
- **IFrames / Embeds**: When embedding in an iframe, include `allow-modals` and
  `allow-popups` so the overlay can appear and `confirm/alert` fallbacks can run.
- **Localization**: The overlay respects `options.Locale` when set. Provide localized button labels and text in your caller.
- **Accessibility**: The JavaScript host traps focus and returns focus to the invoking element. Avoid overriding the markup structure without replacing `Module.nativeMessageBox`.

## Customization Hooks

- Override `Module.nativeMessageBox` (set before `dotnet.runMain(...)`) to use a custom overlay implementation. See `src/native/web/message_box.js` for reference.
- Call `NativeMessageBoxClient.RegisterLogHandler(message => /* ... */)` from managed code to forward logs; the browser bridge relays these to the console by default.
- Set `Module.nmbManagedHostFactory` to supply a bespoke host object with a `showMessageBox(request)` function returning a `Promise`.

## Troubleshooting

- **"NativeMessageBoxManaged bridge not loaded"**: Ensure `native-message-box.js`
  is copied to `wwwroot/` and referenced before `main.js`.
- **Dialogs suppressed**: Browsers throttle repeated modal invocations.
  Queue requests with `NativeMessageBoxClient.TryShowAsync` and avoid opening
  additional dialogs until the previous promise resolves.
- **Timeout button not respected**: When specifying a timeout, include a matching
  button in the `Buttons` collection. The JS host reuses the cancel button when no explicit timeout button is provided.

Deploy the published `wwwroot/` folder to any static host (GitHub Pages,
Azure Static Web Apps, S3 + CloudFront, etc.), ensuring the files above are present.
