# Mobile Dialog UX Analysis

## iOS — Phase 11.1

### UIKit (`UIAlertController`)
- Supports alert and action-sheet styles; action collection limited to buttons plus optional text fields.
- Must be presented from a visible `UIViewController`; presentation requires main-thread dispatch.
- Default button ordering places the most destructive action last; destructive buttons rendered in red.
- PreferredAction API highlights the recommended choice, mirroring TaskDialog defaults.
- Text input limited to basic `UITextField` instances (no secure toggle per field without extra setup).
- Accessibility: VoiceOver reads title/message/actions automatically when presented; use `UIAccessibility.post(notification: .screenChanged, argument: alertController.view)` for custom timing.
- Theming relies on system appearance; custom tinting requires overriding `view.tintColor` and does not permit full layout control.

### SwiftUI (`.alert` / `.confirmationDialog`)
- Declarative wrappers map to `UIAlertController` under the hood; payload restricted to max two buttons plus optional cancel/destructive roles (alerts) or a list of actions (confirmation dialogs).
- SwiftUI 17 introduces `Alert<Button>` supporting more than two actions, but still requires the view to drive the presentation state via bindings.
- Alerts require state-driven presentation; asynchronous completion must bridge back to imperative flows through state mutations.
- Accessibility is inherited from UIKit; ensure alerts are triggered on the main actor to avoid runtime warnings.

### Platform Constraints & Recommendations
- Ensure all invocations occur on the main thread; off-main calls crash in iOS 13+.
- Provide localized strings for `UIAlertAction` titles; avoid truncation by using concise labels (max ~20 characters for smaller devices).
- Dark Mode and Dynamic Type adapt automatically; verify custom iconography contrasts when using custom `tintColor`.
- For multitasking (iPadOS split-view), alerts center within the presenting scene; use popover-style confirmation dialogs when content relates to a UI element.
- Avoid presenting multiple alerts simultaneously; queue requests and dismiss before showing the next to prevent `Attempt to present ... whose view is not in the window hierarchy` errors.

## Android — Phase 12.1

### AlertDialog (AppCompat / Material)
- Primary modal pattern for confirmation; supports title, message, positive/negative/neutral buttons, custom views, and list adapters.
- `AlertDialog.Builder` requires an Activity/Context themed with Material Components for consistent styling.
- Buttons shown in order: positive (right), negative (left), neutral (center) on LTR layouts; mirror in RTL.
- Must be created and shown on the main/UI thread; use `runOnUiThread` or `Handler(Looper.getMainLooper())`.
- Accessibility: TalkBack reads the dialog contents automatically when `setCancelable(false)` is used judiciously; set `contentDescription` on custom views.

### Material Alert Dialog (`MaterialAlertDialogBuilder`)
- Adds Material Theming (shapes, colors, typography) and supports edge-to-edge mode alignment.
- Requires dependency `com.google.android.material:material` and a theme inheriting from `Theme.MaterialComponents`.
- Offers default icon slot via `setIcon` and supports `setBackground` for shape theming; still limited to three buttons.

### Compatibility Matrix Overview

| Feature | API ≤ 21 | API 22-28 | API 29+ |
| --- | --- | --- | --- |
| Material alert theming | Requires AppCompat, limited shape control | Full MaterialComponents support with theme overlay | Supports edge-to-edge, dark theme, dynamic color on Android 12+ |
| List dialogs | `AlertDialog` with `setItems`/`setSingleChoiceItems` | Same as ≤21; multi-choice stable | Same; ensure `RecyclerView` for large lists |
| Text input | Custom view embedding `TextInputLayout` | Same as ≤21 | Use `TextInputEditText` for IME hints & accessibility |
| Icon tinting | Manual tint via `DrawableCompat` | Theme attribute tinting | Dynamic color via `MaterialColors` |

### Platform Constraints & Recommendations
- Always pass an Activity context; using `applicationContext` prevents dialog window creation.
- Handle lifecycle: dismiss dialogs in `onStop` to avoid `WindowLeaked` warnings when Activity finishes.
- Respect system back button; set `setCancelable(true)` unless dialog blocks critical action.
- Localize button labels (e.g., `android.R.string.ok`) for consistent expectations.
- For Compose projects, use `AlertDialog` composable, but interop with JNI requires bridging back to the View system or using `Dialog` with `DialogProperties(usePlatformDefaultWidth = false)` to match Material overlays.
