# Platform Capabilities Matrix

| Capability | Windows | macOS | Linux (GTK) |
| --- | --- | --- | --- |
| Primary API | `TaskDialogIndirect` / `MessageBoxW` | `NSAlert` / `NSPanel` | `GtkMessageDialog` (GTK 3/4) |
| Multi-button support | Up to 8 buttons via Task Dialog; standard MessageBox limited to 3 | Unlimited buttons | Unlimited buttons |
| Custom button labels | Yes | Yes | Yes |
| Checkbox / verification control | Task Dialog verification checkbox | Suppression checkbox + accessory checkbox | Separate `GtkCheckButton` |
| Text input | Planned via accessory controls only (Task Dialog lacks native text input) | Supported via accessory view (`NSTextField`, `NSSecureTextField`) | Supported via `GtkEntry` |
| Combo box | Not native; emulate via accessory host | Supported via accessory view | Supported (`GtkComboBoxText`) |
| Timeout auto-close | Supported via Task Dialog timer | Not built-in | Supported via GTimeout/`g_timeout_add` |
| Icon support | System icons (information, warning, error, shield) | NSAlert icon levels | GTK stock icons / custom pixbuf |
| Hyperlink / Help link | Task Dialog hyperlink events | Accessory button opening `NSWorkspace` | `GtkLinkButton` |
| Parent window modality | App/window/global modal flags | Sheets vs. app modal | Modal to parent or application |
| Thread requirements | Advanced dialogs require STA thread; simple MessageBox is thread-agnostic | Must execute on main thread | GTK main loop required |
| Headless fallback | Console fallback (optional future) | Not applicable | `zenity` CLI fallback |
| Theming | Follows system theme | Follows system theme | GTK theme dependent |
| Accessibility | UI Automation via Task Dialog | VoiceOver support | ATK integration |

## Notes
- Windows: Task Dialog available on Vista+ with comctl32 v6. MessageBox remains for minimal features.
- macOS: Accessory views provide extensibility for inputs; main-thread enforcement is mandatory.
- Linux: GTK 4 preferred; fallback to GTK 3 when 4 is unavailable. CLI fallback ensures minimal functionality when no display server is accessible.
