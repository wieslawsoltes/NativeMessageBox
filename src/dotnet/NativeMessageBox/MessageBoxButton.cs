using System;

namespace NativeMessageBox;

public sealed class MessageBoxButton
{
    public MessageBoxButton(uint id, string label, MessageBoxButtonKind kind = MessageBoxButtonKind.Default, bool isDefault = false, bool isCancel = false, string? description = null)
    {
        if (string.IsNullOrWhiteSpace(label))
        {
            throw new ArgumentException("Button label must be provided.", nameof(label));
        }

        Id = id;
        Label = label;
        Kind = kind;
        IsDefault = isDefault;
        IsCancel = isCancel;
        Description = description;
    }

    public uint Id { get; }

    public string Label { get; }

    public MessageBoxButtonKind Kind { get; }

    public bool IsDefault { get; }

    public bool IsCancel { get; }

    public string? Description { get; }
}

