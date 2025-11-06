using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.Marshalling;
using global::NativeMessageBox;

namespace NativeMessageBox.Interop;

internal static class NativeMessageBoxMarshaller
{
    internal static NmbMessageBoxOptions CreateNativeOptions(MessageBoxOptions options, NativeMemoryScope scope, IntPtr parentOverride = default)
    {
        var native = new NmbMessageBoxOptions
        {
            StructSize = (uint)Unsafe.SizeOf<NmbMessageBoxOptions>(),
            AbiVersion = NativeConstants.AbiVersion,
            TitleUtf8 = scope.AllocUtf8(options.Title),
            MessageUtf8 = scope.AllocUtf8(options.Message),
            Icon = (NmbIcon)options.Icon,
            Severity = (NmbSeverity)options.Severity,
            ParentWindow = parentOverride != IntPtr.Zero ? parentOverride : options.ParentWindow,
            VerificationTextUtf8 = scope.AllocUtf8(options.VerificationText),
            AllowCancelViaEscape = options.AllowCancelViaEscape,
            ShowSuppressCheckbox = options.ShowSuppressCheckbox,
            RequiresExplicitAck = options.RequiresExplicitAcknowledgement,
            TimeoutMilliseconds = options.Timeout.HasValue ? (uint)Math.Clamp(options.Timeout.Value.TotalMilliseconds, 0, uint.MaxValue) : 0,
            TimeoutButtonId = options.TimeoutButtonId.HasValue ? (NmbButtonId)options.TimeoutButtonId.Value : 0,
            LocaleUtf8 = scope.AllocUtf8(options.Locale),
            Allocator = IntPtr.Zero,
            UserContext = IntPtr.Zero
        };

        var allocator = NativeAllocator.Create();
        native.Allocator = scope.AllocStructArray<NmbAllocator>(stackalloc NmbAllocator[] { allocator });

        native.Modality = MapModality(options.Modality);

        var nativeButtons = new List<NmbButtonOption>(options.Buttons.Count);
        foreach (var managedButton in options.Buttons)
        {
            var button = new NmbButtonOption
            {
                StructSize = (uint)Unsafe.SizeOf<NmbButtonOption>(),
                Id = (NmbButtonId)managedButton.Id,
                LabelUtf8 = scope.AllocUtf8(managedButton.Label),
                DescriptionUtf8 = scope.AllocUtf8(managedButton.Description),
                Kind = (NmbButtonKind)managedButton.Kind,
                IsDefault = managedButton.IsDefault,
                IsCancel = managedButton.IsCancel
            };
            nativeButtons.Add(button);
        }

        native.Buttons = scope.AllocStructArray<NmbButtonOption>(CollectionsMarshal.AsSpan(nativeButtons));
        native.ButtonCount = (nuint)nativeButtons.Count;

        if (options.InputOptions is { } inputOptions && inputOptions.Mode != MessageBoxInputMode.None)
        {
            var input = new NmbInputOption
            {
                StructSize = (uint)Unsafe.SizeOf<NmbInputOption>(),
                Mode = (NmbInputMode)inputOptions.Mode,
                PromptUtf8 = scope.AllocUtf8(inputOptions.Prompt),
                PlaceholderUtf8 = scope.AllocUtf8(inputOptions.Placeholder),
                DefaultValueUtf8 = scope.AllocUtf8(inputOptions.DefaultValue)
            };

            if (inputOptions.Mode == MessageBoxInputMode.Combo)
            {
                var pointers = new List<IntPtr>(inputOptions.ComboItems.Count + 1);
                foreach (var item in inputOptions.ComboItems)
                {
                    pointers.Add(scope.AllocUtf8(item));
                }

                pointers.Add(IntPtr.Zero);
                input.ComboItemsUtf8 = scope.AllocPointerArray(CollectionsMarshal.AsSpan(pointers));
            }

            var array = new[] { input };
            native.Input = scope.AllocStructArray<NmbInputOption>(array);
        }

        if (options.SecondaryContent is { } secondary)
        {
            var secondaryNative = new NmbSecondaryContentOption
            {
                StructSize = (uint)Unsafe.SizeOf<NmbSecondaryContentOption>(),
                InformativeTextUtf8 = scope.AllocUtf8(secondary.InformativeText),
                ExpandedTextUtf8 = scope.AllocUtf8(secondary.ExpandedText),
                FooterTextUtf8 = scope.AllocUtf8(secondary.FooterText),
                HelpLinkUtf8 = scope.AllocUtf8(secondary.HelpLink)
            };

            var array = new[] { secondaryNative };
            native.Secondary = scope.AllocStructArray<NmbSecondaryContentOption>(array);
        }

        return native;
    }

    internal static NmbMessageBoxResult CreateNativeResult()
    {
        return new NmbMessageBoxResult
        {
            StructSize = (uint)Unsafe.SizeOf<NmbMessageBoxResult>(),
            ResultCode = NmbResultCode.Ok
        };
    }

    internal static MessageBoxResult ToManagedResult(ref NmbMessageBoxResult nativeResult, MessageBoxOptions options)
    {
        string? input = null;
        if (nativeResult.InputValueUtf8 != IntPtr.Zero)
        {
            input = Marshal.PtrToStringUTF8(nativeResult.InputValueUtf8);
            NativeAllocator.Release(nativeResult.InputValueUtf8);
        }

        return new MessageBoxResult(
            buttonId: (uint)nativeResult.Button,
            checkboxChecked: nativeResult.CheckboxChecked,
            inputValue: input,
            wasTimeout: nativeResult.WasTimeout,
            outcome: ResultMapper.ToOutcome(nativeResult.ResultCode),
            tag: options.Tag,
            nativeResultCode: (uint)nativeResult.ResultCode);
    }

    private static NmbDialogModality MapModality(MessageBoxDialogModality modality)
    {
        return modality switch
        {
            MessageBoxDialogModality.System => NmbDialogModality.System,
            MessageBoxDialogModality.Window => NmbDialogModality.Window,
            _ => NmbDialogModality.App
        };
    }
}
