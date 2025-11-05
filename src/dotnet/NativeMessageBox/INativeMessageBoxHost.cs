using System.Threading;
using System.Threading.Tasks;

namespace NativeMessageBox;

public interface INativeMessageBoxHost
{
    void EnsureInitialized();
    void Shutdown();
    MessageBoxResult Show(MessageBoxOptions options);
    bool TryShow(MessageBoxOptions options, out MessageBoxResult result);
    Task<MessageBoxResult> ShowAsync(MessageBoxOptions options, CancellationToken cancellationToken = default);
    Task<(bool Success, MessageBoxResult Result)> TryShowAsync(MessageBoxOptions options, CancellationToken cancellationToken = default);
}

