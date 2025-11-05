# Error Handling Strategy

## Native Layer
- Functions return `NmbResultCode`; `NMB_OK` indicates success.
- Errors logged via runtime callback to aid diagnosis (e.g., unsupported features, thread violations).
- Struct size/version fields validated to guard against ABI mismatches.
- Timeout conditions flagged via `NmbMessageBoxResult.was_timeout` with distinct button result.

## Managed Layer
- `MessageBoxResult` surfaces `Outcome` enumeration plus raw native result code.
- `NativeMessageBoxException` (and `NativeMessageBoxInitializationException`) thrown for initialization failures, host validation errors, or when `ShowOrThrow` encounters non-success outcomes.
- `TryShow` and `TryShowAsync` return graceful failure results without throwing.
- Thread apartment validation on Windows ensures advanced features (Task Dialog, accessory controls) run on STA thread unless explicitly disabled.

## Logging
- Unified callback pipeline; native implementations invoke `nmb_runtime_log` to push messages through managed handler.
- Clients register log handlers using `NativeMessageBoxClient.RegisterLogHandler` for diagnostics.

## Future Considerations
- Structured logging categories (info/warning/error) for easier parsing.
- Optional event hooks (pre-show/post-show) for instrumentation.

