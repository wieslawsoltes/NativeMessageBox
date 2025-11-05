# Native Message Box C ABI Specification

This document explains the binary contract exposed by `include/native_message_box.h`. The goal is to provide a stable, feature-rich interface that can be consumed from C, C++, Rust, Go, Swift, and other languages capable of interoperating with a C ABI.

## Versioning
- **ABI version** is encoded as `MAJOR << 16 | MINOR << 8 | PATCH`. The current version is `0.1.0`.
- Consumers must set `abi_version` fields to `NMB_ABI_VERSION`. The native library will reject mismatched major versions.
- Structs contain a `struct_size` field. Callers must pass `sizeof(struct)` from their build. The runtime uses this to detect truncated or extended structs and maintain forward compatibility.

## Memory Model
- Strings passed into the API must be UTF-8 encoded, null-terminated, and remain valid for the duration of the call.
- Strings returned by the runtime (e.g., `NmbMessageBoxResult::input_value_utf8`) are allocated via either the caller-provided allocator or the runtime default. Callers must free them using the provided deallocator.
- `NmbAllocator` supports aligned allocation. When not provided, platform-appropriate allocation is used (`CoTaskMemAlloc` on Windows, `malloc` elsewhere).

## Initialization
- `nmb_initialize` is optional but recommended. It accepts `NmbInitializeOptions` to configure logging and allocator hooks. Repeated calls are reference counted; each `nmb_initialize` must be paired with a final `nmb_shutdown`.
- If `enable_async_dispatch` is true, the runtime configures any platform requirements (e.g., Cocoa main thread dispatch) and may spawn helper threads as needed.

## Message Box Options
`NmbMessageBoxOptions` captures the desired dialog:

| Field | Purpose |
| --- | --- |
| `title_utf8` | Dialog title (window caption). Optional on macOS where sheets may omit titles. |
| `message_utf8` | Main message text (required). Supports multi-line content via `\n`. |
| `buttons` + `button_count` | Array of `NmbButtonOption`. At least one button is required. |
| `icon` | Preferred icon. Platforms may map to nearest equivalent based on severity. |
| `modality` | App/window/system modal. Parent window handle supplied via `parent_window`. |
| `input` | Optional `NmbInputOption` enabling text, password, combo box, or checkbox prompts. |
| `secondary` | Additional contextual content (informative text, expandable sections). |
| `verification_text_utf8` + `show_suppress_checkbox` | Enables a "Do not show again" checkbox. |
| `timeout_milliseconds` + `timeout_button_id` | Optional auto-dismiss with specific result id. |
| `allocator` | Overrides for per-call allocations. Falls back to initialize-level allocator otherwise. |

Unsupported features on a platform will return `NMB_E_NOT_SUPPORTED`.

## Results
`NmbMessageBoxResult` reports:

- `button`: the selected button identifier.
- `checkbox_checked`: state of the verification checkbox.
- `input_value_utf8`: optional response captured from `NMB_INPUT_TEXT/PASSWORD/COMBO`.
- `was_timeout`: indicates auto-dismiss due to timeout.
- `result_code`: overall status. If non-`NMB_OK`, other fields may be unset.

## Error Handling
- Errors are surfaced via the function return value (`NmbResultCode`) and mirrored in `NmbMessageBoxResult::result_code`.
- Detailed error logging flows through the log callback (if provided) with categorized messages.
- Platform-specific error codes are mapped to human-readable diagnostics for logging.

## Threading
- The API is thread-safe if `nmb_initialize` has completed successfully. The runtime marshals calls onto required UI threads (e.g., dispatching to the macOS main thread).
- Callers can opt into providing window handles to display sheets/modal dialogs relative to specific windows.

## Extensibility
- Future extensions may add new struct fields beyond the existing `struct_size`. The runtime treats missing fields as default-initialized.
- Additional functions (e.g., asynchronous display, progress dialogs) will follow the same versioning scheme.

## Example Usage (C)
```c
#include "native_message_box.h"

int main(void)
{
    NmbInitializeOptions init_opts = {0};
    init_opts.struct_size = sizeof(init_opts);
    init_opts.abi_version = NMB_ABI_VERSION;
    nmb_initialize(&init_opts);

    NmbButtonOption buttons[2] = {0};
    buttons[0].struct_size = sizeof(NmbButtonOption);
    buttons[0].id = NMB_BUTTON_ID_OK;
    buttons[0].label_utf8 = "OK";
    buttons[0].is_default = NMB_TRUE;

    buttons[1].struct_size = sizeof(NmbButtonOption);
    buttons[1].id = NMB_BUTTON_ID_CANCEL;
    buttons[1].label_utf8 = "Cancel";
    buttons[1].is_cancel = NMB_TRUE;

    NmbMessageBoxOptions options = {0};
    options.struct_size = sizeof(options);
    options.abi_version = NMB_ABI_VERSION;
    options.title_utf8 = "Hello";
    options.message_utf8 = "This is a cross-platform message box!";
    options.buttons = buttons;
    options.button_count = 2;
    options.icon = NMB_ICON_INFORMATION;

    NmbMessageBoxResult result = {0};
    result.struct_size = sizeof(result);

    NmbResultCode rc = nmb_show_message_box(&options, &result);
    if (rc == NMB_OK)
    {
        /* handle result.button / result.checkbox_checked */
    }

    if (result.input_value_utf8)
    {
        /* free using allocator if provided */
    }

    nmb_shutdown();
    return 0;
}
```

## Compliance Notes
- Consumers must be compiled with the same struct packing conventions (default platform alignment).
- All exported functions use `__stdcall` on Windows to align with common ABI expectations; other platforms use the default C calling convention.
- Shared libraries should define `NMB_SHARED` and `NMB_IMPLEMENTATION` when compiling the native implementation to ensure symbol visibility.

