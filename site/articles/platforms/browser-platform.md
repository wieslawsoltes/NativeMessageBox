---
title: "Browser Platform"
---

# Browser Platform

The browser backend is implemented as a custom overlay host instead of relying on blocking browser dialogs.

## Why a Custom Overlay

Native browser dialogs such as `alert`, `confirm`, and `prompt` are intentionally limited:

- Button text is browser-controlled
- Content is plain text only
- Styling and layout are fixed
- Repeated usage may be throttled

The custom overlay keeps button labels, optional input, and richer secondary content under application control.

## Browser Backend Shape

- JavaScript host file: `src/native/web/message_box.js`
- Optional native WASM module: `src/native/web/wasm_message_box.cpp`
- Managed integration: browser host path in the .NET client

## Constraints

- The dialog runs on the browser main thread.
- Accessibility behavior depends on the overlay implementation, not on browser-native alert semantics.
- Deployment must copy the JavaScript host into the published site output.

## Related

- [Browser Deployment](../guides/browser-deployment.md)
- [Samples](../guides/samples.md)
