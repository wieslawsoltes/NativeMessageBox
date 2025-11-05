using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using NativeMessageBox.Interop;
using Xunit;

namespace NativeMessageBox.Tests;

public class InteropTests
{
    [Fact]
    public void CreateNativeOptionsSetsStructMetadata()
    {
        var options = new MessageBoxOptions("Interop test");
        using var scope = new NativeMemoryScope();
        var native = NativeMessageBoxMarshaller.CreateNativeOptions(options, scope);

        Assert.Equal((uint)Unsafe.SizeOf<NmbMessageBoxOptions>(), native.StructSize);
        Assert.Equal(NativeConstants.AbiVersion, native.AbiVersion);
        Assert.NotEqual(IntPtr.Zero, native.Buttons);
        Assert.NotEqual((nuint)0, native.ButtonCount);
    }

    [Theory]
    [InlineData((uint)NmbResultCode.Ok, MessageBoxOutcome.Success)]
    [InlineData((uint)NmbResultCode.Cancelled, MessageBoxOutcome.Cancelled)]
    [InlineData((uint)NmbResultCode.NotSupported, MessageBoxOutcome.NotSupported)]
    [InlineData((uint)NmbResultCode.PlatformFailure, MessageBoxOutcome.PlatformFailure)]
    [InlineData((uint)NmbResultCode.OutOfMemory, MessageBoxOutcome.OutOfMemory)]
    [InlineData((uint)NmbResultCode.InvalidArgument, MessageBoxOutcome.InvalidArgument)]
    [InlineData((uint)NmbResultCode.Uninitialized, MessageBoxOutcome.Uninitialized)]
    public void ResultMapperCoversExpectedCodes(uint nativeCode, MessageBoxOutcome expected)
    {
        Assert.Equal(expected, ResultMapper.ToOutcome((NmbResultCode)nativeCode));
    }

    [Fact]
    public void RuntimeFallbacksIncludeCurrentRid()
    {
        var fallbacks = NativeLibraryLoader.GetRuntimeFallbacks();
        Assert.Contains(RuntimeInformation.RuntimeIdentifier, fallbacks);
    }
}
