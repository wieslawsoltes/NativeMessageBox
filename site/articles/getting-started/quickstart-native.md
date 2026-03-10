---
title: "Quickstart (C ABI)"
---

# Quickstart (C ABI)

The C ABI is the stable contract for native or FFI-based consumers.

## Minimal Example

```c
#include "native_message_box.h"

int main(void)
{
    NmbInitializeOptions init = {0};
    init.struct_size = sizeof(init);
    init.abi_version = NMB_ABI_VERSION;
    init.runtime_name_utf8 = "sample-app";

    nmb_initialize(&init);

    NmbButtonOption buttons[2] = {0};
    buttons[0].struct_size = sizeof(NmbButtonOption);
    buttons[0].id = NMB_BUTTON_ID_OK;
    buttons[0].label_utf8 = "Continue";
    buttons[0].is_default = NMB_TRUE;

    buttons[1].struct_size = sizeof(NmbButtonOption);
    buttons[1].id = NMB_BUTTON_ID_CANCEL;
    buttons[1].label_utf8 = "Cancel";
    buttons[1].is_cancel = NMB_TRUE;

    NmbMessageBoxOptions options = {0};
    options.struct_size = sizeof(options);
    options.abi_version = NMB_ABI_VERSION;
    options.title_utf8 = "NativeMessageBox";
    options.message_utf8 = "Continue the deployment?";
    options.buttons = buttons;
    options.button_count = 2;
    options.icon = NMB_ICON_INFORMATION;
    options.timeout_milliseconds = 15000;
    options.timeout_button_id = NMB_BUTTON_ID_CANCEL;

    NmbMessageBoxResult result = {0};
    result.struct_size = sizeof(result);

    NmbResultCode rc = nmb_show_message_box(&options, &result);
    if (rc == NMB_OK && result.button == NMB_BUTTON_ID_OK)
    {
        /* Proceed with the deployment. */
    }

    nmb_shutdown();
    return 0;
}
```

## Contract Rules

- Every public struct must have `struct_size` initialized.
- Callers must pass `NMB_ABI_VERSION` in the option structs that require it.
- UTF-8 strings must remain valid for the duration of the call.
- Returned strings must be released with the allocator that owns them.

## Good First Checks

- Confirm the runtime binary matches the consumer architecture.
- Confirm `rc` and `result.result_code` are both inspected.
- Pair `nmb_initialize` and `nmb_shutdown` when you enable shared runtime state.

## Related

- [C ABI and Versioning](../advanced/c-abi-and-versioning.md)
- [Platform Capabilities](../concepts/platform-capabilities.md)
- [Building and Packaging](../guides/building-and-packaging.md)
