# Web Dialog UX Analysis

## Browser Modal Capabilities — Phase 13.1

### Native Dialog APIs (`alert`, `confirm`, `prompt`)
- Available in all evergreen browsers; they block the UI thread and suspend timers/event dispatch until dismissed.
- Button labels are browser controlled (`OK`, `Cancel`, locale specific) and cannot be customized beyond message text.
- Messages accept plain text only; line breaks are supported, but markup, icons, and keyboard shortcuts are disallowed.
- Each dialog gains implicit screen reader support, but the synchronous pause can confuse assistive tech that expects non-blocking flows.
- Browsers throttle or suppress repeated invocations and surface the page origin to mitigate phishing/spam.

### Custom Modal Overlays (`<dialog>`, ARIA pattern)
- `<dialog>` provides native focus management, ESC close handling, and `showModal()` semantics; older browsers require a polyfill.
- Div-based overlays (e.g., libraries such as Material UI, Fluent, Tailwind) need manual focus trapping, scroll locking, and layering (`z-index`, backdrop).
- Allows full control over layout, theming, iconography, button labels/order, checkbox inputs, text areas, and rich content.
- Must preserve responsive layouts (small screens, landscape) and respect `prefers-reduced-motion` media queries for transitions.
- Requires explicit cleanup when the hosting DOM node is removed to avoid detached overlays remaining in the accessibility tree.

## Accessibility Considerations
- Use `role="dialog"` or `role="alertdialog"` with `aria-modal="true"`, `aria-labelledby`, and `aria-describedby` on custom overlays.
- Move focus to the first interactive control on open and restore the invoking element on close; treat ESC key and backdrop click as explicit cancel pathways.
- Apply `inert` or `aria-hidden="true"` to background content to prevent screen readers from escaping the modal; polyfill `inert` where unsupported.
- Provide keyboard-accessible affordances (tab order, accelerators) and large hit targets for touch. Validate contrast ratios for text/icons/outline states.
- Offer alternatives for non-pointer users (e.g., `button` elements rather than `div` click handlers) and announce async status updates with `aria-live`.

## Security & Abuse Prevention Constraints
- Browsers limit synchronous dialogs triggered without a trusted user gesture (e.g., after `setTimeout` or during unload) to reduce disruption.
- Repeated dialog spam can trigger browser-level suppression banners (“This page is preventing you from leaving”) and block further prompts.
- Custom overlays must handle click-jacking concerns: avoid covering browser UI, respect CSP/sandbox policies, and ensure escape hatches (`Cancel`, close button).
- HTTPS is required for advanced capabilities (service workers, clipboard, notifications) often paired with dialogs; document fallback messaging when insecure.
- Sandboxed iframes may require `allow-modals` to show native dialogs; same-origin isolation affects ability to brand overlays with shared CSS/JS.

## WebAssembly Host Guidance
- WASM modules execute on the browser’s main thread by default; calling blocking APIs (`alert`) freezes rendering and input, so prefer async custom overlays.
- Bridge through JavaScript using `Promise`-based APIs exposed to the managed layer (e.g., `JSExport`/`JSImport` in .NET 8) to mirror async native patterns.
- Queue modal requests to avoid overlapping overlays; ensure re-entrancy by resolving previous promises before presenting the next dialog.
- Normalize button result enums and input payloads so the managed layer maintains parity with native platforms (OK/Cancel, custom buttons, checkbox state).
- Surface telemetry hooks to capture rejection reasons (user dismissed, browser suppressed) and bubble them back to the .NET layer for consistent error handling.
- Provide a default overlay host (`Module.nativeMessageBox`) that can be overridden by consumers; expose shared constants (`Module.NmbResultCode`, `Module.NmbInputMode`) to keep parity with native interop semantics.
- Managed consumers should default to the browser-aware host (`NativeMessageBoxBrowserHost`), which relies on `NativeMessageBoxManaged.*` JS entry points to initialize, register log callbacks, and dispatch modal workflows without loading native shared libraries.

## Next Steps
- Codify the findings in implementation guidelines for Phase 13.3 (`src/native/web/wasm_message_box.c`, `src/native/web/message_box.js`).
- Reference this analysis within `docs/browser-deployment.md` once authored (Phase 13.6) to inform hosting and security guidance.
