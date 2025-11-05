using System.Collections.Generic;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using NativeMessageBox;

namespace DialogPlayground;

public class MainWindow : Window
{
    private readonly TextBox _titleTextBox;
    private readonly TextBox _messageTextBox;
    private readonly ComboBox _iconComboBox;
    private readonly CheckBox _verificationCheckBox;
    private readonly CheckBox _inputCheckBox;
    private readonly CheckBox _asyncCheckBox;
    private readonly TextBox _primaryButtonTextBox;
    private readonly TextBox _secondaryButtonTextBox;
    private readonly TextBlock _resultBlock;

    private const uint PrimaryButtonId = 1;
    private const uint SecondaryButtonId = 2;

    public MainWindow()
    {
        Title = "Dialog Playground";
        Width = 720;
        Height = 520;

        var container = new StackPanel
        {
            Spacing = 16,
            Margin = new Thickness(16)
        };

        container.Children.Add(new TextBlock { Text = "Configure a dialog and preview the result.", FontWeight = FontWeight.Bold });

        var configurationPanel = new StackPanel { Spacing = 12 };
        container.Children.Add(configurationPanel);

        _titleTextBox = new TextBox { Watermark = "Title" };
        configurationPanel.Children.Add(_titleTextBox);

        _messageTextBox = new TextBox
        {
            Watermark = "Message",
            AcceptsReturn = true,
            Height = 100,
            TextWrapping = TextWrapping.Wrap
        };
        configurationPanel.Children.Add(_messageTextBox);

        var optionsRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 12 };
        _iconComboBox = new ComboBox
        {
            Width = 160,
            ItemsSource = new[] { "Information", "Warning", "Error", "Question", "Shield" },
            SelectedIndex = 0
        };
        optionsRow.Children.Add(_iconComboBox);

        _verificationCheckBox = new CheckBox { Content = "Include verification checkbox" };
        _inputCheckBox = new CheckBox { Content = "Include text input" };
        _asyncCheckBox = new CheckBox { Content = "Run asynchronously" };
        optionsRow.Children.Add(_verificationCheckBox);
        optionsRow.Children.Add(_inputCheckBox);
        optionsRow.Children.Add(_asyncCheckBox);
        configurationPanel.Children.Add(optionsRow);

        var buttonRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 12 };
        _primaryButtonTextBox = new TextBox { Width = 160, Watermark = "Primary button label" };
        _secondaryButtonTextBox = new TextBox { Width = 160, Watermark = "Secondary button label (optional)" };
        buttonRow.Children.Add(_primaryButtonTextBox);
        buttonRow.Children.Add(_secondaryButtonTextBox);
        configurationPanel.Children.Add(buttonRow);

        var showButton = new Button
        {
            Content = "Show Dialog",
            HorizontalAlignment = HorizontalAlignment.Left
        };
        showButton.Click += OnShowDialogClick;
        configurationPanel.Children.Add(showButton);

        _resultBlock = new TextBlock { TextWrapping = TextWrapping.Wrap };
        var resultHost = new Border
        {
            BorderBrush = Brushes.LightGray,
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(4),
            Padding = new Thickness(12),
            Child = _resultBlock
        };
        container.Children.Add(resultHost);

        Content = new ScrollViewer { Content = container };

        _titleTextBox.Text = "Native Message Box";
        _messageTextBox.Text = "This dialog is powered by the native message box host.";
        _primaryButtonTextBox.Text = "OK";
    }

    private async void OnShowDialogClick(object? sender, RoutedEventArgs e)
    {
        _resultBlock.Text = string.Empty;

        var buttons = BuildButtons();
        var inputOptions = _inputCheckBox.IsChecked == true
            ? new MessageBoxInputOptions(MessageBoxInputMode.Text, prompt: "Enter a value", placeholder: "Type here")
            : null;

        var verificationText = _verificationCheckBox.IsChecked == true ? "Remember my choice" : null;
        var options = new MessageBoxOptions(
            message: string.IsNullOrWhiteSpace(_messageTextBox.Text) ? "Hello from Dialog Playground." : _messageTextBox.Text!,
            buttons: buttons,
            title: string.IsNullOrWhiteSpace(_titleTextBox.Text) ? null : _titleTextBox.Text,
            icon: ParseIcon(),
            severity: MessageBoxSeverity.Info,
            inputOptions: inputOptions,
            verificationText: verificationText,
            showSuppressCheckbox: _verificationCheckBox.IsChecked == true);

        MessageBoxResult result;
        if (_asyncCheckBox.IsChecked == true)
        {
            _resultBlock.Text = "Awaiting asynchronous dialog result...";
            result = await NativeMessageBoxClient.ShowAsync(options);
        }
        else
        {
            result = NativeMessageBoxClient.Show(options);
        }

        _resultBlock.Text = FormatResult(result);
    }

    private IReadOnlyList<MessageBoxButton> BuildButtons()
    {
        var primaryLabel = string.IsNullOrWhiteSpace(_primaryButtonTextBox.Text) ? "OK" : _primaryButtonTextBox.Text!;
        var buttons = new List<MessageBoxButton>
        {
            new MessageBoxButton(PrimaryButtonId, primaryLabel, MessageBoxButtonKind.Primary, isDefault: true)
        };

        if (!string.IsNullOrWhiteSpace(_secondaryButtonTextBox.Text))
        {
            buttons.Add(new MessageBoxButton(SecondaryButtonId, _secondaryButtonTextBox.Text!, MessageBoxButtonKind.Secondary, isCancel: true));
        }

        return buttons;
    }

    private MessageBoxIcon ParseIcon()
    {
        return _iconComboBox.SelectedIndex switch
        {
            1 => MessageBoxIcon.Warning,
            2 => MessageBoxIcon.Error,
            3 => MessageBoxIcon.Question,
            4 => MessageBoxIcon.Shield,
            _ => MessageBoxIcon.Information
        };
    }

    private static string FormatResult(MessageBoxResult result)
    {
        var parts = new List<string>
        {
            $"ButtonId={result.ButtonId}",
            $"Outcome={result.Outcome}",
            $"Checked={result.CheckboxChecked}"
        };

        if (!string.IsNullOrEmpty(result.InputValue))
        {
            parts.Add($"Input='{result.InputValue}'");
        }

        if (result.WasTimeout)
        {
            parts.Add("Timeout=true");
        }

        parts.Add($"NativeCode={result.NativeResultCode}");
        return string.Join(", ", parts);
    }
}
