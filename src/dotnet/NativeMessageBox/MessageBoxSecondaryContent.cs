namespace NativeMessageBox;

public sealed class MessageBoxSecondaryContent
{
    public MessageBoxSecondaryContent(string? informativeText = null, string? expandedText = null, string? footerText = null, string? helpLink = null)
    {
        InformativeText = informativeText;
        ExpandedText = expandedText;
        FooterText = footerText;
        HelpLink = helpLink;
    }

    public string? InformativeText { get; }

    public string? ExpandedText { get; }

    public string? FooterText { get; }

    public string? HelpLink { get; }
}

