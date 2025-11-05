# User Experience Requirements

## Dialog Composition
- Title, headline, and body text with UTF-8 support and markdown-like line breaks.
- Support for minimum of three standard button presets (`OK`, `Cancel`, `Yes/No`) plus custom labels.
- Optional verification checkbox ("Do not show again"), with state returned to caller.
- Secondary content region supporting informative text, expandable sections, and footers with help links.
- Optional accessory inputs: single-line text, password, combo box, and checkbox.

## Behavior
- Configurable modality: window modal (parent handle), application modal, and system modal (where platform allows).
- Escape key cancellation and close-button suppression options.
- Optional timeout with designated button result; should surface timeout flag in result.
- Threading constraints documented per platform and validated at runtime.
- Localization support via UTF-8 strings and custom locale hint for future resource integration.

## Accessibility
- Provide descriptive labels for controls and accessible descriptions for buttons.
- Expose severity levels to map to platform accessibility cues (warning/error semantics).
- Ensure focus order per platform guidelines; default button indicated and invoked by Enter return key.

## Diagnostics & Telemetry
- Configurable logging callback with platform-level messages for fallbacks and errors.
- Future provision for event hooks (e.g., before show/after close) to integrate analytics or instrumentation.

## Error Surfaces
- Managed layer returns `MessageBoxResult` with native result code and outcome enumeration.
- Exceptions thrown for initialization errors or invalid threading contexts, with actionable messages.

