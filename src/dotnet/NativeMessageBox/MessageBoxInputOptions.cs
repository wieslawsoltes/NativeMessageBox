using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;

namespace NativeMessageBox;

public sealed class MessageBoxInputOptions
{
    public MessageBoxInputOptions(
        MessageBoxInputMode mode,
        string? prompt = null,
        string? placeholder = null,
        string? defaultValue = null,
        IReadOnlyList<string>? comboItems = null)
    {
        if (mode == MessageBoxInputMode.Combo && (comboItems == null || comboItems.Count == 0))
        {
            throw new ArgumentException("Combo box mode requires at least one item.", nameof(comboItems));
        }

        Mode = mode;
        Prompt = prompt;
        Placeholder = placeholder;
        DefaultValue = defaultValue;
        ComboItems = comboItems != null ? new ReadOnlyCollection<string>(comboItems.ToArray()) : Array.Empty<string>();
    }

    public MessageBoxInputMode Mode { get; }

    public string? Prompt { get; }

    public string? Placeholder { get; }

    public string? DefaultValue { get; }

    public IReadOnlyList<string> ComboItems { get; }
}
