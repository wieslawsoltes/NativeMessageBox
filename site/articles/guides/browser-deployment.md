---
title: "Browser Deployment"
---

# Browser Deployment

NativeMessageBox supports browser-hosted dialogs through a custom JavaScript overlay host and an optional native WASM module.

## Typical Workflow

1. Build or publish the browser sample.
2. Ensure `native-message-box.js` is copied into the published output.
3. Optionally build the native WASM artifact when you need the full browser runtime package.
4. Host the output as static files.

## Commands

```bash
dotnet build samples/CrossPlatformSample/NativeMessageBox.CrossPlatformSample.Browser
./build/scripts/package-wasm.sh
dotnet publish samples/CrossPlatformSample/NativeMessageBox.CrossPlatformSample.Browser -c Release
```

## Deployment Notes

- The browser host is non-blocking and behaves like a custom modal overlay.
- Hosting can be static; no Node.js service is required.
- If you customize output copying, verify `native-message-box.js` remains in `wwwroot`.

## When to Use the Browser Host

Use it when you want consistent button labels, optional input, and richer content than `alert`, `confirm`, or `prompt` can provide.

## Related

- [Browser Platform](../platforms/browser-platform.md)
- [Samples](samples.md)
