using System;
using Xunit;

namespace NativeMessageBox.Tests;

public class MessageBoxOptionsTests
{
    [Fact]
    public void ConstructorAssignsDefaultButtonWhenNoneProvided()
    {
        var options = new MessageBoxOptions("Hello");

        Assert.Single(options.Buttons);
        Assert.Equal(1u, options.Buttons[0].Id);
        Assert.Equal("OK", options.Buttons[0].Label);
    }

    [Fact]
    public void ComboInputRequiresItems()
    {
        Assert.Throws<ArgumentException>(() =>
        {
            _ = new MessageBoxInputOptions(MessageBoxInputMode.Combo);
        });
    }

    [Fact]
    public void TryShowReturnsFalseWhenNativeLibraryMissing()
    {
        var options = new MessageBoxOptions("Hello from tests");
        var success = NativeMessageBoxClient.TryShow(options, out var result);

        Assert.False(success);
        Assert.NotNull(result);
        Assert.NotEqual(MessageBoxOutcome.Success, result.Outcome);
    }
}

