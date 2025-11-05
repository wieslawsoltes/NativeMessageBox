using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using NativeMessageBox;

namespace Showcase;

public class MainWindow : Window
{
    private readonly TextBlock _resultBlock;

    private const uint ButtonYes = 3;
    private const uint ButtonNo = 4;
    private const uint ButtonRetry = 5;
    private const uint ButtonCancel = 2;

    public MainWindow()
    {
        Title = "Native Message Box Showcase";
        Width = 640;
        Height = 480;

        var container = new StackPanel
        {
            Spacing = 12,
            Margin = new Thickness(20)
        };

        container.Children.Add(new TextBlock
        {
            Text = "Explore various configurations of the native message box API.",
            TextWrapping = TextWrapping.Wrap
        });

        container.Children.Add(CreateButton("Information", OnInformationClick));
        container.Children.Add(CreateButton("Confirmation", OnConfirmationClick));
        container.Children.Add(CreateButton("Custom Buttons", OnCustomButtonsClick));
        container.Children.Add(CreateButton("Input with Verification", OnInputWithVerificationClick));
        container.Children.Add(CreateButton("Timeout", OnTimeoutClick));

        _resultBlock = new TextBlock
        {
            FontStyle = FontStyle.Italic,
            TextWrapping = TextWrapping.Wrap
        };
        container.Children.Add(_resultBlock);

        Content = new ScrollViewer { Content = container };

        NativeMessageBoxClient.RegisterLogHandler(message => Console.WriteLine($"[NativeMessageBox] {message}"));
    }

    private Button CreateButton(string text, EventHandler<RoutedEventArgs> handler)
    {
        var button = new Button { Content = text, HorizontalAlignment = HorizontalAlignment.Left };
        button.Click += handler;
        return button;
    }

    private void OnInformationClick(object? sender, RoutedEventArgs e)
    {
        var options = new MessageBoxOptions(
            message: "All subsystems are operational.",
            title: "System Status",
            icon: MessageBoxIcon.Information,
            severity: MessageBoxSeverity.Info);

        var result = NativeMessageBoxClient.Show(options);
        _resultBlock.Text = $"Information dialog returned {result.ButtonId} with outcome {result.Outcome}.";
    }

    private void OnConfirmationClick(object? sender, RoutedEventArgs e)
    {
        var buttons = new[]
        {
            new MessageBoxButton(ButtonYes, "Yes", MessageBoxButtonKind.Primary, isDefault: true),
            new MessageBoxButton(ButtonNo, "No", MessageBoxButtonKind.Secondary, isCancel: true)
        };

        var options = new MessageBoxOptions(
            message: "Do you want to synchronize settings across devices?",
            title: "Synchronize",
            icon: MessageBoxIcon.Question,
            buttons: buttons,
            severity: MessageBoxSeverity.Warning,
            verificationText: "Remember my decision",
            showSuppressCheckbox: true);

        var result = NativeMessageBoxClient.Show(options);
        _resultBlock.Text = $"Confirmation result: {(result.ButtonId == ButtonYes ? "Yes" : "No")} (checkbox={result.CheckboxChecked}).";
    }

    private void OnCustomButtonsClick(object? sender, RoutedEventArgs e)
    {
        var buttons = new[]
        {
            new MessageBoxButton(ButtonRetry, "Retry", MessageBoxButtonKind.Primary, isDefault: true),
            new MessageBoxButton(ButtonCancel, "Cancel", MessageBoxButtonKind.Secondary, isCancel: true)
        };

        var secondary = new MessageBoxSecondaryContent(
            informativeText: "Package upload failed.",
            expandedText: "Check your network connection and retry. You can view logs for more diagnostics.");

        var options = new MessageBoxOptions(
            message: "The last upload did not complete successfully.",
            title: "Deployment",
            icon: MessageBoxIcon.Warning,
            buttons: buttons,
            secondaryContent: secondary,
            allowCancelViaEscape: false,
            requiresExplicitAcknowledgement: true);

        var result = NativeMessageBoxClient.Show(options);
        _resultBlock.Text = $"Custom buttons result: {(result.ButtonId == ButtonRetry ? "Retry" : "Cancel")}";
    }

    private void OnInputWithVerificationClick(object? sender, RoutedEventArgs e)
    {
        var input = new MessageBoxInputOptions(
            mode: MessageBoxInputMode.Text,
            prompt: "Provide a label",
            placeholder: "Enter label",
            defaultValue: "Release v1.0.0");

        var options = new MessageBoxOptions(
            message: "Please confirm the label to assign to this release.",
            title: "Release Label",
            icon: MessageBoxIcon.Shield,
            inputOptions: input,
            verificationText: "Mark release as production-ready",
            showSuppressCheckbox: true);

        var result = NativeMessageBoxClient.Show(options);
        _resultBlock.Text = $"Input result: '{result.InputValue}' (checkbox={result.CheckboxChecked}).";
    }

    private void OnTimeoutClick(object? sender, RoutedEventArgs e)
    {
        var options = new MessageBoxOptions(
            message: "Session will automatically sign out if no action is taken.",
            title: "Idle Session",
            icon: MessageBoxIcon.Warning,
            timeout: TimeSpan.FromSeconds(5),
            timeoutButtonId: ButtonCancel,
            buttons: new[]
            {
                new MessageBoxButton(ButtonCancel, "Dismiss", MessageBoxButtonKind.Secondary, isDefault: true)
            });

        var result = NativeMessageBoxClient.Show(options);
        _resultBlock.Text = result.WasTimeout
            ? "Dialog timed out and closed automatically."
            : "Dialog closed by user action.";
    }
}
