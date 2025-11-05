# Native/Managed Interop Review

This review covers the native implementations (`src/native`) and the managed .NET host (`src/dotnet/NativeMessageBox`). Findings are grouped by severity and area, with concrete remediation suggestions for each item.

## Critical Findings (High Severity)

1. [x] **ABI validation gaps** – Added shared guards so every native entry point now verifies `struct_size` and `abi_version` before dereferencing option/result structs (`src/native/windows/message_box.cpp:22-86`, `src/native/linux/message_box.cpp:23-91`, `src/native/macos/MessageBox.mm:15-83`). This prevents mismatched client builds from corrupting memory.  
   **Fix**: Guard functions return `NMB_E_INVALID_ARGUMENT` and log a platform-specific message when the struct is truncated or the ABI version mismatches.

2. [x] **Windows custom button mismatch** – Added a button capability gate so any non-standard IDs, labels, descriptions, or unsupported combinations trigger Task Dialog usage, and the runtime now refuses to fall back when that information would be lost (`src/native/windows/message_box.cpp:34-205`). The MessageBox fallback only runs for the handful of native button layouts it can faithfully render, otherwise the call returns `NMB_E_NOT_SUPPORTED` when Task Dialogs are unavailable (`src/native/windows/message_box.cpp:794-833`).  
   **Fix**: Preserve managed button semantics by requiring Task Dialog for custom sets and propagating `NMB_E_NOT_SUPPORTED` if the platform cannot show them.

3. [x] **Linux expanded content never renders** – `gtk_expander_new` is created without a child widget, so expanded text is empty (`src/native/linux/message_box.cpp:248-252`).  
   **Fix**: Create a wrapped `GtkLabel`, set it as the expander child (`gtk_expander_set_child`), and ensure it is marked as non-editable.

4. [x] **Linux dialog close produces ambiguous result** – Closing the window via the title bar or ESC (when allowed) yields `GTK_RESPONSE_DELETE_EVENT`, which is not mapped; callers see `button = NMB_BUTTON_ID_NONE` with an apparent success outcome (`src/native/linux/message_box.cpp:407-428`).  
   **Fix**: Detect unmapped responses and translate them to `NMB_E_CANCELLED` with `button = NMB_BUTTON_ID_CANCEL`.

5. [x] **macOS default button result incorrect** – When the caller omits explicit buttons, the native layer adds a UI button but returns `NMB_BUTTON_ID_NONE` (no mapping) (`src/native/macos/MessageBox.mm:271-309`).  
   **Fix**: Special-case zero buttons by returning `NMB_BUTTON_ID_OK`, or synthesize a temporary button option entry for mapping.

6. [x] **macOS sheet invocation is unsafe** – Calling `beginSheetModalForWindow` followed by `runModal` mixes async and modal flows, causing re-entrancy problems on Monterey+ (`src/native/macos/MessageBox.mm:291-297`).  
   **Fix**: Either run synchronously (`runModal`) without `beginSheetModalForWindow`, or implement a modal sheet pattern using `dispatch_semaphore`/`NSApp runModalForWindow`.

7. [x] **macOS advanced flags ignored** – Timeout, `allow_cancel_via_escape`, and `requires_explicit_ack` are unused, so managed expectations are violated (`src/native/macos/MessageBox.mm:223-324`).  
   **Fix**: Wire timers via `dispatch_after`, disable close shortcuts when explicit acknowledgement is required, and respect the escape key flag by subclassing `NSWindow`.

8. [x] **Zenity fallback unsafe** – The Linux `RunZenityFallback` routine builds a shell command with unsanitised user strings (`src/native/linux/message_box.cpp:169-206`), exposing command-injection risk.  
   **Fix**: Replace `std::system` with `GSubprocess`/`g_spawn_async` and pass arguments as a vector; escape or reject unsafe characters if a shell must be used.

## Moderate Findings

9. [x] **Windows shield icon mapping** – `NMB_ICON_SHIELD` maps to `TD_WARNING_ICON`, losing the shield glyph (`src/native/windows/message_box.cpp:66-82`). Use `TD_SHIELD_ICON`.  

10. [x] **Windows fallback button IDs incomplete** – The simple MessageBox path never maps `NMB_BUTTON_ID_CLOSE`/`HELP` (and any custom IDs) back to managed IDs (`src/native/windows/message_box.cpp:195-216`). Either extend the mapping or fail fast when unsupported IDs reach the fallback.

11. [x] **Windows input limitations** – Non-checkbox input modes return `NMB_E_NOT_SUPPORTED` before Task Dialog dispatch (`src/native/windows/message_box.cpp:540-548`). Document this limitation in the managed layer and consider creating a custom dialog template to support text/combo inputs.

12. [x] **Linux keyboard escape handling** – Setting `allowClose` only intercepts window delete events; the ESC accelerator still dismisses the dialog even when `allow_cancel_via_escape == NMB_FALSE` (`src/native/linux/message_box.cpp:381-415`). Connect to `key-press-event` and consume `GDK_KEY_Escape` when escape cancellation is disabled or explicit acknowledgement is required.

13. [x] **Linux/Mac verification checkbox semantics** – Windows shows the verification checkbox whenever text is provided, whereas Linux/macOS require `show_suppress_checkbox == true` (`src/native/windows/message_box.cpp:328-357`, `src/native/linux/message_box.cpp:260-264`, `src/native/macos/MessageBox.mm:274-313`). Align the behaviour (either gate on the flag across platforms or update the managed API contract).

14. [x] **macOS informative text overwrite** – Setting secondary informative text replaces the primary message (`src/native/macos/MessageBox.mm:239-245`). Preserve the main message in `messageText` and move secondary content either into `informativeText` (when empty) or the accessory view.

15. [x] **macOS secondary footer unused** – `secondary->footer_text_utf8` is never surfaced in the UI (`src/native/macos/MessageBox.mm:82-188`). Add a read-only label (or `NSTextField` in the accessory view) for footer text.

16. [x] **macOS timeout button not honoured** – Even if `timeout_milliseconds` and `timeout_button_id` are provided, no timer is armed. Implement via `dispatch_after` that calls `-[NSApp stopModalWithCode:]`.

17. [x] **Managed STA validation asymmetry** – The managed host treats advanced Windows features specially (`src/dotnet/NativeMessageBox/Interop/NativeRuntimeMessageBoxHost.cs:174-226`) but exposes options like `RequiresExplicitAcknowledgement` on macOS/Linux where the native layers currently ignore them. Add documentation or guardrails in `MessageBoxOptions` (e.g., platform capability checks) to avoid surprising callers.

18. [x] **Locale hint unused** – None of the native backends consume `locale_utf8`. If locale-sensitive formatting is a roadmap item, note the gap or remove the option until supported.

## Low-Severity & Enhancements

19. [ ] Add structured logging when features are silently downgraded (e.g., Windows falling back from Task Dialog to MessageBox) so managed consumers can surface telemetry.
20. [ ] Extend the native test suite (`src/native/tests`) to include round-trip tests for every standard button ID, timeout behaviour, and verification checkbox across all platforms.
21. [ ] Consider exposing a capability query in the public API so the managed layer can adapt (for example, reporting whether text inputs or timeouts are supported on the current platform).

## Suggested Next Steps

22. [ ] Patch the critical issues (ABI validation, Windows custom button handling, Linux expander/content fixes, macOS button mapping & sheet handling) and add regression tests.  
23. [ ] Align checkbox/escape semantics across platforms and document unsupported features to managed callers.  
24. [ ] Harden fallbacks (zenity) and improve platform capability detection so future features can be negotiated cleanly.
