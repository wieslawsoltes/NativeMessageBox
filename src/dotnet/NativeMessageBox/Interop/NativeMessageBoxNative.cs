using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace NativeMessageBox.Interop;

internal static partial class NativeMessageBoxNative
{
    private const string LibraryName = "nativemessagebox";

    [LibraryImport(LibraryName, EntryPoint = "nmb_initialize", StringMarshalling = StringMarshalling.Utf8)]
    internal static partial NmbResultCode Initialize(ref NmbInitializeOptions options);

    [LibraryImport(LibraryName, EntryPoint = "nmb_show_message_box", StringMarshalling = StringMarshalling.Utf8)]
    internal static partial NmbResultCode ShowMessageBox(ref NmbMessageBoxOptions options, ref NmbMessageBoxResult result);

    [LibraryImport(LibraryName, EntryPoint = "nmb_shutdown")]
    internal static partial void Shutdown();

    [LibraryImport(LibraryName, EntryPoint = "nmb_get_abi_version")]
    internal static partial uint GetAbiVersion();

    [LibraryImport(LibraryName, EntryPoint = "nmb_set_log_callback")]
    internal static partial void SetLogCallback(IntPtr logCallback, IntPtr userData);

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    internal static bool IsAbiCompatible(uint expected) => GetAbiVersion() == expected;
}

[StructLayout(LayoutKind.Sequential)]
internal unsafe struct NmbAllocator
{
    internal delegate* unmanaged<IntPtr, nuint, nuint, IntPtr> Allocate;
    internal delegate* unmanaged<IntPtr, IntPtr, void> Deallocate;
    internal IntPtr UserData;
}

internal enum NmbResultCode : uint
{
    Ok = 0,
    InvalidArgument = 1,
    Uninitialized = 2,
    NotSupported = 3,
    PlatformFailure = 4,
    Cancelled = 5,
    OutOfMemory = 6
}

[StructLayout(LayoutKind.Sequential)]
internal struct NmbInitializeOptions
{
    internal uint StructSize;
    internal uint AbiVersion;
    internal IntPtr RuntimeName;
    internal IntPtr Allocator;
    [MarshalAs(UnmanagedType.U1)]
    internal bool EnableAsyncDispatch;
    internal IntPtr LogCallback;
    internal IntPtr LogUserData;
}

[StructLayout(LayoutKind.Sequential)]
internal struct NmbMessageBoxOptions
{
    internal uint StructSize;
    internal uint AbiVersion;
    internal IntPtr TitleUtf8;
    internal IntPtr MessageUtf8;
    internal IntPtr Buttons;
    internal nuint ButtonCount;
    internal NmbIcon Icon;
    internal NmbSeverity Severity;
    internal NmbDialogModality Modality;
    internal IntPtr ParentWindow;
    internal IntPtr Input;
    internal IntPtr Secondary;
    internal IntPtr VerificationTextUtf8;
    [MarshalAs(UnmanagedType.U1)]
    internal bool AllowCancelViaEscape;
    [MarshalAs(UnmanagedType.U1)]
    internal bool ShowSuppressCheckbox;
    [MarshalAs(UnmanagedType.U1)]
    internal bool RequiresExplicitAck;
    internal uint TimeoutMilliseconds;
    internal NmbButtonId TimeoutButtonId;
    internal IntPtr LocaleUtf8;
    internal IntPtr Allocator;
    internal IntPtr UserContext;
}

[StructLayout(LayoutKind.Sequential)]
internal struct NmbMessageBoxResult
{
    internal uint StructSize;
    internal NmbButtonId Button;
    [MarshalAs(UnmanagedType.U1)]
    internal bool CheckboxChecked;
    internal IntPtr InputValueUtf8;
    [MarshalAs(UnmanagedType.U1)]
    internal bool WasTimeout;
    internal NmbResultCode ResultCode;
}

[StructLayout(LayoutKind.Sequential)]
internal struct NmbButtonOption
{
    internal uint StructSize;
    internal NmbButtonId Id;
    internal IntPtr LabelUtf8;
    internal IntPtr DescriptionUtf8;
    internal NmbButtonKind Kind;
    [MarshalAs(UnmanagedType.U1)]
    internal bool IsDefault;
    [MarshalAs(UnmanagedType.U1)]
    internal bool IsCancel;
}

[StructLayout(LayoutKind.Sequential)]
internal struct NmbInputOption
{
    internal uint StructSize;
    internal NmbInputMode Mode;
    internal IntPtr PromptUtf8;
    internal IntPtr PlaceholderUtf8;
    internal IntPtr DefaultValueUtf8;
    internal IntPtr ComboItemsUtf8;
}

[StructLayout(LayoutKind.Sequential)]
internal struct NmbSecondaryContentOption
{
    internal uint StructSize;
    internal IntPtr InformativeTextUtf8;
    internal IntPtr ExpandedTextUtf8;
    internal IntPtr FooterTextUtf8;
    internal IntPtr HelpLinkUtf8;
}

internal enum NmbButtonKind : uint
{
    Default = 0,
    Primary = 1,
    Secondary = 2,
    Destructive = 3,
    Help = 4
}

internal enum NmbButtonId : uint
{
    None = 0,
    Ok = 1,
    Cancel = 2,
    Yes = 3,
    No = 4,
    Retry = 5,
    Continue = 6,
    Ignore = 7,
    Abort = 8,
    Close = 9,
    Help = 10,
    TryAgain = 11,
    CustomBase = 1000
}

internal enum NmbIcon : uint
{
    None = 0,
    Information = 1,
    Warning = 2,
    Error = 3,
    Question = 4,
    Shield = 5
}

internal enum NmbSeverity : uint
{
    Info = 0,
    Warning = 1,
    Error = 2,
    Critical = 3
}

internal enum NmbDialogModality : uint
{
    App = 0,
    Window = 1,
    System = 2
}

internal enum NmbInputMode : uint
{
    None = 0,
    Checkbox = 1,
    Text = 2,
    Password = 3,
    Combo = 4
}
