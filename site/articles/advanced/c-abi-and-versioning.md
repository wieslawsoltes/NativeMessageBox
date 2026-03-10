---
title: "C ABI and Versioning"
---

# C ABI and Versioning

The ABI exposed through `include/native_message_box.h` is designed to stay stable across additive evolution.

## Versioning Rules

- `NMB_ABI_VERSION` encodes major, minor, and patch.
- Callers must pass the ABI version on structs that require it.
- The runtime rejects mismatched major versions.

## Struct Size Rule

Every public struct carries a `struct_size` field. Callers must initialize it with `sizeof(struct)`.

That enables two important things:

- Detection of truncated callers
- Forward-compatible expansion of public structs

## Memory Model

- Input strings are UTF-8 and must stay alive for the duration of the call.
- Output strings are allocator-owned and must be released through the owning allocator.
- `NmbAllocator` allows the caller to override allocation policy.

## Core Native Calls

| Function | Purpose |
| --- | --- |
| `nmb_initialize` | Optional runtime initialization and logging setup |
| `nmb_show_message_box` | Show a dialog and write the result |
| `nmb_shutdown` | Release runtime state |

## Result Handling

Inspect both:

- The returned `NmbResultCode`
- The `NmbMessageBoxResult` payload for button, input, checkbox, timeout, and result code details

## Related

- [Quickstart (C ABI)](../getting-started/quickstart-native.md)
- [Dialog Options and Results](../concepts/dialog-options-and-results.md)
