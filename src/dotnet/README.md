# .NET Managed Layer

The managed `NativeMessageBox` library will be implemented here. Key components include:

- `NativeMessageBox` class library targeting `.NET 8.0` (with potential additional targets for compatibility).
- Source-generated `LibraryImport` declarations for the cross-platform native library.
- Managed abstractions for message box options, results, diagnostics, and asynchronous workflows.
- Unit tests verifying marshaling behavior and error-handling semantics.

