using System;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NativeMessageBox;

namespace NativeMessageBox.CrossPlatformSample.ViewModels;

public partial class MainViewModel : ViewModelBase
{
    private const uint OkButtonId = 1;
    private const uint CancelButtonId = 2;

    [ObservableProperty]
    private string _status = "Tap the button to invoke the native message box.";

    [ObservableProperty]
    private bool _isBusy;

    [RelayCommand(CanExecute = nameof(CanShowNativeDialog))]
    private async Task ShowNativeDialogAsync()
    {
        if (IsBusy)
        {
            return;
        }

        try
        {
            IsBusy = true;

            var buttons = new[]
            {
                new MessageBoxButton(OkButtonId, "OK", MessageBoxButtonKind.Primary, isDefault: true),
                new MessageBoxButton(CancelButtonId, "Cancel", MessageBoxButtonKind.Secondary, isCancel: true)
            };

            var options = new MessageBoxOptions(
                message: "This dialog is rendered using the platform-native APIs.",
                buttons: buttons,
                title: "NativeMessageBox Sample",
                icon: MessageBoxIcon.Information,
                severity: MessageBoxSeverity.Info);

            var (success, result) = await NativeMessageBoxClient.TryShowAsync(options);

            if (success)
            {
                var outcome = result.Outcome == MessageBoxOutcome.Success ? "Success" : "Cancelled";
                Status = $"Native dialog returned {outcome} (ButtonId={result.ButtonId}).";
            }
            else
            {
                Status = $"Native dialog failed with outcome {result.Outcome} (code {result.NativeResultCode}).";
            }
        }
        catch (NativeMessageBoxException ex)
        {
            Status = $"Native API error: {ex.Message} (code {ex.NativeResultCode}).";
        }
        catch (Exception ex)
        {
            Status = $"Unexpected error: {ex.Message}.";
        }
        finally
        {
            IsBusy = false;
        }
    }

    private bool CanShowNativeDialog() => !IsBusy;

    partial void OnIsBusyChanged(bool value) => ShowNativeDialogCommand.NotifyCanExecuteChanged();
}
