using System.IO;
using System.Threading.Tasks;
using Xunit;

namespace NativeMessageBox.Tests;

public class NativeMessageBoxClientTests
{
    [Fact]
    public void ShowOrThrowThrowsWhenNativeLibraryMissing()
    {
        var options = new MessageBoxOptions("ShowOrThrow test");
        Assert.Throws<NativeMessageBoxInitializationException>(() => NativeMessageBoxClient.ShowOrThrow(options));
    }

    [Fact]
    public async Task TryShowAsyncReturnsFailureWhenNativeMissing()
    {
        var options = new MessageBoxOptions("Async test");
        var (success, result) = await NativeMessageBoxClient.TryShowAsync(options);

        Assert.False(success);
        Assert.NotNull(result);
        Assert.NotEqual(MessageBoxOutcome.Success, result.Outcome);
    }

    [Fact]
    public void RegisterLogHandlerDoesNotThrow()
    {
        NativeMessageBoxClient.RegisterLogHandler(_ => { });
        NativeMessageBoxClient.RegisterNativeLibraryPath(Path.GetTempPath());
    }
}
