#include "native_message_box.h"

#if defined(_WIN32)

#define WIN32_LEAN_AND_MEAN
#define _WIN32_IE 0x0600

#include <windows.h>
#include <CommCtrl.h>
#include <shellapi.h>
#include <string>
#include <vector>
#include <cstddef>
#include <cctype>

#include "../../shared/nmb_alloc.h"
#include "../../shared/nmb_runtime.h"
#if defined(NMB_TESTING)
#include "native_message_box_test.h"
#endif

namespace
{
    constexpr size_t kInitializeOptionsMinSize =
        offsetof(NmbInitializeOptions, log_user_data) + sizeof(void*);
    constexpr size_t kMessageBoxOptionsMinSize =
        offsetof(NmbMessageBoxOptions, user_context) + sizeof(void*);
    constexpr size_t kMessageBoxResultMinSize =
        offsetof(NmbMessageBoxResult, result_code) + sizeof(NmbResultCode);

    NmbResultCode LogInvalid(const char* message)
    {
        nmb_runtime_log(message);
        return NMB_E_INVALID_ARGUMENT;
    }

#if defined(NMB_TESTING)
    bool ApplyTestHarness(const NmbMessageBoxOptions* options, NmbMessageBoxResult* out_result)
    {
        if (!options || !options->user_context || !out_result)
        {
            return false;
        }

        const NmbTestHarness* harness = static_cast<const NmbTestHarness*>(options->user_context);
        if (!harness || harness->magic != NMB_TEST_HARNESS_MAGIC || harness->struct_size != sizeof(NmbTestHarness))
        {
            return false;
        }

        out_result->button = harness->scripted_button;
        out_result->checkbox_checked = harness->checkbox_checked;
        out_result->was_timeout = harness->simulate_timeout;
        out_result->result_code = harness->result_code;

        out_result->input_value_utf8 = nullptr;
        if (harness->input_value_utf8)
        {
            if (options->allocator)
            {
                NmbResultCode copy_rc = nmb_copy_string_to_allocator(options->allocator, harness->input_value_utf8, &out_result->input_value_utf8);
                if (copy_rc != NMB_OK)
                {
                    out_result->result_code = copy_rc;
                }
            }
            else
            {
                out_result->input_value_utf8 = harness->input_value_utf8;
            }
        }

        return true;
    }
#endif

    bool EqualsIgnoreCase(const char* lhs, const char* rhs)
    {
        if (lhs == rhs)
        {
            return true;
        }

        if (!lhs || !rhs)
        {
            return false;
        }

        while (*lhs && *rhs)
        {
            const unsigned char a = static_cast<unsigned char>(*lhs);
            const unsigned char b = static_cast<unsigned char>(*rhs);
            if (std::tolower(a) != std::tolower(b))
            {
                return false;
            }
            ++lhs;
            ++rhs;
        }

        return *lhs == '\0' && *rhs == '\0';
    }

    const char* DefaultLabelForButton(NmbButtonId id)
    {
        switch (id)
        {
        case NMB_BUTTON_ID_OK:
            return "OK";
        case NMB_BUTTON_ID_CANCEL:
            return "Cancel";
        case NMB_BUTTON_ID_YES:
            return "Yes";
        case NMB_BUTTON_ID_NO:
            return "No";
        case NMB_BUTTON_ID_RETRY:
            return "Retry";
        case NMB_BUTTON_ID_ABORT:
            return "Abort";
        case NMB_BUTTON_ID_IGNORE:
            return "Ignore";
        default:
            return nullptr;
        }
    }

    bool MatchesDefaultLabel(NmbButtonId id, const char* label)
    {
        if (!label)
        {
            return DefaultLabelForButton(id) != nullptr;
        }

        const char* expected = DefaultLabelForButton(id);
        if (!expected)
        {
            return false;
        }

        return EqualsIgnoreCase(label, expected);
    }

    bool ButtonsSupportedByMessageBox(const NmbMessageBoxOptions* options)
    {
        if (!options || !options->buttons || options->button_count == 0)
        {
            return true;
        }

        if (options->button_count > 3)
        {
            return false;
        }

        unsigned int okCount = 0;
        unsigned int cancelCount = 0;
        unsigned int yesCount = 0;
        unsigned int noCount = 0;
        unsigned int retryCount = 0;
        unsigned int abortCount = 0;
        unsigned int ignoreCount = 0;

        for (size_t i = 0; i < options->button_count; ++i)
        {
            const NmbButtonOption& button = options->buttons[i];
            if (button.description_utf8)
            {
                return false;
            }

            if (button.kind != NMB_BUTTON_KIND_DEFAULT)
            {
                return false;
            }

            switch (button.id)
            {
            case NMB_BUTTON_ID_OK:
                ++okCount;
                break;
            case NMB_BUTTON_ID_CANCEL:
                ++cancelCount;
                break;
            case NMB_BUTTON_ID_YES:
                ++yesCount;
                break;
            case NMB_BUTTON_ID_NO:
                ++noCount;
                break;
            case NMB_BUTTON_ID_RETRY:
                ++retryCount;
                break;
            case NMB_BUTTON_ID_ABORT:
                ++abortCount;
                break;
            case NMB_BUTTON_ID_IGNORE:
                ++ignoreCount;
                break;
            default:
                return false;
            }

            if (!MatchesDefaultLabel(button.id, button.label_utf8))
            {
                return false;
            }
        }

        const size_t count = options->button_count;
        if (count == 1)
        {
            return okCount == 1;
        }

        if (count == 2)
        {
            if (okCount == 1 && cancelCount == 1)
            {
                return true;
            }

            if (yesCount == 1 && noCount == 1)
            {
                return true;
            }

            if (retryCount == 1 && cancelCount == 1)
            {
                return true;
            }

            return false;
        }

        if (count == 3)
        {
            if (yesCount == 1 && noCount == 1 && cancelCount == 1)
            {
                return true;
            }

            if (abortCount == 1 && retryCount == 1 && ignoreCount == 1)
            {
                return true;
            }

            return false;
        }

        return false;
    }


    NmbResultCode ValidateInitializeOptions(const NmbInitializeOptions* options)
    {
        if (!options)
        {
            return NMB_OK;
        }

        if (options->struct_size < kInitializeOptionsMinSize)
        {
            return LogInvalid("Windows: NmbInitializeOptions.struct_size is smaller than expected.");
        }

        if (options->abi_version != NMB_ABI_VERSION)
        {
            return LogInvalid("Windows: NmbInitializeOptions.abi_version mismatch.");
        }

        return NMB_OK;
    }

    NmbResultCode ValidateMessageBoxOptions(const NmbMessageBoxOptions* options)
    {
        if (!options)
        {
            return NMB_E_INVALID_ARGUMENT;
        }

        if (options->struct_size < kMessageBoxOptionsMinSize)
        {
            return LogInvalid("Windows: NmbMessageBoxOptions.struct_size is smaller than expected.");
        }

        if (options->abi_version != NMB_ABI_VERSION)
        {
            return LogInvalid("Windows: NmbMessageBoxOptions.abi_version mismatch.");
        }

        return NMB_OK;
    }

    NmbResultCode ValidateMessageBoxResult(const NmbMessageBoxResult* result)
    {
        if (!result)
        {
            return NMB_E_INVALID_ARGUMENT;
        }

        if (result->struct_size < kMessageBoxResultMinSize)
        {
            return LogInvalid("Windows: NmbMessageBoxResult.struct_size is smaller than expected.");
        }

        return NMB_OK;
    }

    struct TaskDialogState
    {
        const NmbMessageBoxOptions* options;
        const NmbSecondaryContentOption* secondary;
        std::wstring help_link;
        DWORD timeout_ms;
        NmbButtonId timeout_button;
        bool timed_out;
    };

    using TaskDialogIndirectFn = HRESULT(WINAPI*)(const TASKDIALOGCONFIG*, int*, int*, BOOL*);

    TaskDialogIndirectFn LoadTaskDialog()
    {
        static TaskDialogIndirectFn proc = nullptr;
        static bool attempted = false;
        if (!attempted)
        {
            attempted = true;
            HMODULE hModule = LoadLibraryW(L"comctl32.dll");
            if (hModule)
            {
                proc = reinterpret_cast<TaskDialogIndirectFn>(GetProcAddress(hModule, "TaskDialogIndirect"));
            }
        }

        return proc;
    }

    std::wstring Utf8ToWide(const char* value)
    {
        if (!value)
        {
            return std::wstring();
        }

        const int length = MultiByteToWideChar(CP_UTF8, 0, value, -1, nullptr, 0);
        if (length <= 0)
        {
            return std::wstring();
        }

        std::wstring wide(static_cast<size_t>(length - 1), L'\0');
        MultiByteToWideChar(CP_UTF8, 0, value, -1, wide.data(), length);
        return wide;
    }

    PCWSTR MapIconResource(NmbIcon icon)
    {
        switch (icon)
        {
        case NMB_ICON_WARNING:
            return TD_WARNING_ICON;
        case NMB_ICON_SHIELD:
            return TD_SHIELD_ICON;
        case NMB_ICON_ERROR:
            return TD_ERROR_ICON;
        case NMB_ICON_INFORMATION:
            return TD_INFORMATION_ICON;
        case NMB_ICON_QUESTION:
            return TD_QUESTION_ICON;
        default:
            return nullptr;
        }
    }

    UINT MapMessageBoxIcon(NmbIcon icon)
    {
        switch (icon)
        {
        case NMB_ICON_INFORMATION:
            return MB_ICONINFORMATION;
        case NMB_ICON_WARNING:
        case NMB_ICON_SHIELD:
            return MB_ICONWARNING;
        case NMB_ICON_ERROR:
            return MB_ICONERROR;
        case NMB_ICON_QUESTION:
            return MB_ICONQUESTION;
        default:
            return 0;
        }
    }

    UINT ComposeButtonFlags(const NmbMessageBoxOptions* options, NmbButtonId* default_button)
    {
        if (default_button)
        {
            *default_button = NMB_BUTTON_ID_NONE;
        }

        if (!options || !options->buttons || options->button_count == 0)
        {
            return MB_OK;
        }

        bool hasOk = false;
        bool hasCancel = false;
        bool hasYes = false;
        bool hasNo = false;
        bool hasRetry = false;
        bool hasContinue = false;
        bool hasAbort = false;
        bool hasIgnore = false;

        for (size_t i = 0; i < options->button_count; ++i)
        {
            const NmbButtonOption& button = options->buttons[i];
            if (button.is_default && default_button)
            {
                *default_button = button.id;
            }

            switch (button.id)
            {
            case NMB_BUTTON_ID_OK:
                hasOk = true;
                break;
            case NMB_BUTTON_ID_CANCEL:
                hasCancel = true;
                break;
            case NMB_BUTTON_ID_YES:
                hasYes = true;
                break;
            case NMB_BUTTON_ID_NO:
                hasNo = true;
                break;
            case NMB_BUTTON_ID_RETRY:
                hasRetry = true;
                break;
            case NMB_BUTTON_ID_CONTINUE:
                hasContinue = true;
                break;
            case NMB_BUTTON_ID_ABORT:
                hasAbort = true;
                break;
            case NMB_BUTTON_ID_IGNORE:
                hasIgnore = true;
                break;
            default:
                break;
            }
        }

        if (hasAbort && hasRetry && hasIgnore)
        {
            return MB_ABORTRETRYIGNORE;
        }

        if (hasRetry && hasCancel)
        {
            return MB_RETRYCANCEL;
        }

        if (hasYes && hasNo && hasCancel)
        {
            return MB_YESNOCANCEL;
        }

        if (hasYes && hasNo)
        {
            return MB_YESNO;
        }

        if (hasOk && hasCancel)
        {
            return MB_OKCANCEL;
        }

        if (hasContinue && hasCancel)
        {
            return MB_OKCANCEL;
        }

        return MB_OK;
    }

    NmbButtonId MapMessageBoxResult(int result)
    {
        switch (result)
        {
        case IDOK:
            return NMB_BUTTON_ID_OK;
        case IDCANCEL:
            return NMB_BUTTON_ID_CANCEL;
        case IDYES:
            return NMB_BUTTON_ID_YES;
        case IDNO:
            return NMB_BUTTON_ID_NO;
        case IDABORT:
            return NMB_BUTTON_ID_ABORT;
        case IDRETRY:
            return NMB_BUTTON_ID_RETRY;
        case IDIGNORE:
            return NMB_BUTTON_ID_IGNORE;
#ifdef IDTRYAGAIN
        case IDTRYAGAIN:
            return NMB_BUTTON_ID_TRY_AGAIN;
#endif
        case IDCONTINUE:
            return NMB_BUTTON_ID_CONTINUE;
#ifdef IDCLOSE
        case IDCLOSE:
            return NMB_BUTTON_ID_CLOSE;
#endif
#ifdef IDHELP
        case IDHELP:
            return NMB_BUTTON_ID_HELP;
#endif
        default:
            return NMB_BUTTON_ID_NONE;
        }
    }

    HRESULT CALLBACK TaskDialogCallbackProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM /*lParam*/, LONG_PTR refData)
    {
        auto* state = reinterpret_cast<TaskDialogState*>(refData);
        if (!state)
        {
            return S_OK;
        }

        switch (msg)
        {
        case TDN_HYPERLINK_CLICKED:
            if (!state->help_link.empty())
            {
                ShellExecuteW(hwnd, L"open", state->help_link.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
            }
            return S_OK;
        case TDN_TIMER:
            if (state->timeout_ms > 0 && state->timeout_button != NMB_BUTTON_ID_NONE)
            {
                DWORD elapsed = static_cast<DWORD>(wParam);
                if (elapsed >= state->timeout_ms && !state->timed_out)
                {
                    state->timed_out = true;
                    SendMessageW(hwnd, TDM_CLICK_BUTTON, static_cast<WPARAM>(state->timeout_button), 0);
                }
            }
            return S_OK;
        default:
            return S_OK;
        }
    }

    bool RequiresTaskDialog(const NmbMessageBoxOptions* options)
    {
        if (!options)
        {
            return false;
        }

        if (!ButtonsSupportedByMessageBox(options))
        {
            return true;
        }

        if (options->button_count > 3)
        {
            return true;
        }

        if (options->verification_text_utf8 || options->secondary || options->allow_cancel_via_escape == NMB_FALSE ||
            options->show_suppress_checkbox == NMB_TRUE || options->timeout_milliseconds > 0 || options->icon == NMB_ICON_SHIELD)
        {
            return true;
        }

        if (options->input && options->input->mode == NMB_INPUT_CHECKBOX)
        {
            return true;
        }

        return false;
    }

    NmbResultCode ShowTaskDialog(const NmbMessageBoxOptions* options, NmbMessageBoxResult* out_result)
    {
        TaskDialogIndirectFn taskDialog = LoadTaskDialog();
        if (!taskDialog)
        {
            return NMB_E_NOT_SUPPORTED;
        }

        INITCOMMONCONTROLSEX icc = {};
        icc.dwSize = sizeof(icc);
        icc.dwICC = ICC_STANDARD_CLASSES;
        InitCommonControlsEx(&icc);

        std::wstring title = Utf8ToWide(options->title_utf8);
        std::wstring message = Utf8ToWide(options->message_utf8);
        std::wstring informative;
        std::wstring footer;
        std::wstring verification;

        if (options->secondary)
        {
            if (options->secondary->informative_text_utf8)
            {
                informative = Utf8ToWide(options->secondary->informative_text_utf8);
            }

            if (options->secondary->footer_text_utf8)
            {
                footer = Utf8ToWide(options->secondary->footer_text_utf8);
            }
        }

        if (options->verification_text_utf8)
        {
            if (options->show_suppress_checkbox == NMB_TRUE)
            {
                verification = Utf8ToWide(options->verification_text_utf8);
            }
            else
            {
                nmb_runtime_log("Windows: Verification text provided but show_suppress_checkbox is false; suppressing checkbox.");
            }
        }
        else if (options->input && options->input->mode == NMB_INPUT_CHECKBOX && options->input->prompt_utf8)
        {
            verification = Utf8ToWide(options->input->prompt_utf8);
        }

        TaskDialogState state = {};
        state.options = options;
        state.secondary = options->secondary;
        state.timeout_ms = options->timeout_milliseconds;
        state.timeout_button = options->timeout_button_id;
        state.timed_out = false;

        std::wstring expanded;
        if (options->secondary && options->secondary->expanded_text_utf8)
        {
            expanded = Utf8ToWide(options->secondary->expanded_text_utf8);
        }

        std::wstring expanded_control_text = L"More details";
        if (options->secondary && options->secondary->informative_text_utf8 && options->secondary->expanded_text_utf8)
        {
            expanded_control_text = L"Details";
        }

        if (options->secondary && options->secondary->help_link_utf8)
        {
            state.help_link = Utf8ToWide(options->secondary->help_link_utf8);
            if (!footer.empty())
            {
                footer.append(L"\n");
            }
            footer.append(L"<a href=\"");
            footer.append(state.help_link);
            footer.append(L"\">Open help</a>");
        }

        std::vector<std::wstring> buttonTexts;
        std::vector<TASKDIALOG_BUTTON> buttons;
        buttonTexts.reserve(options->button_count);
        buttons.reserve(options->button_count);

        int defaultButton = 0;
        for (size_t i = 0; i < options->button_count; ++i)
        {
            const NmbButtonOption& opt = options->buttons[i];
            std::wstring label = Utf8ToWide(opt.label_utf8);
            buttonTexts.push_back(label);

            TASKDIALOG_BUTTON btn = {};
            btn.nButtonID = static_cast<int>(opt.id);
            btn.pszButtonText = buttonTexts.back().c_str();
            buttons.push_back(btn);

            if (opt.is_default)
            {
                defaultButton = btn.nButtonID;
            }
        }

        TASKDIALOGCONFIG config = {};
        config.cbSize = sizeof(config);
        config.hwndParent = reinterpret_cast<HWND>(const_cast<void*>(options->parent_window));
        config.hInstance = GetModuleHandleW(nullptr);
        config.pszWindowTitle = title.empty() ? nullptr : title.c_str();
        config.pszMainInstruction = message.empty() ? L"" : message.c_str();
        config.pszContent = informative.empty() ? nullptr : informative.c_str();
        config.dwCommonButtons = 0;
        config.pButtons = buttons.empty() ? nullptr : buttons.data();
        config.cButtons = static_cast<UINT>(buttons.size());
        config.pfCallback = TaskDialogCallbackProc;
        config.lpCallbackData = reinterpret_cast<LONG_PTR>(&state);
        config.nDefaultButton = defaultButton;
        config.pszMainIcon = MapIconResource(options->icon);

        config.dwFlags |= TDF_ALLOW_DIALOG_CANCELLATION;
        if (options->requires_explicit_ack == NMB_TRUE)
        {
            config.dwFlags &= ~TDF_ALLOW_DIALOG_CANCELLATION;
        }

        if (options->allow_cancel_via_escape == NMB_FALSE)
        {
            config.dwFlags &= ~TDF_ALLOW_DIALOG_CANCELLATION;
        }

        if (!verification.empty())
        {
            config.pszVerificationText = verification.c_str();
        }

        if (!expanded.empty())
        {
            config.pszExpandedInformation = expanded.c_str();
            config.pszExpandedControlText = expanded_control_text.c_str();
        }

        if (!footer.empty())
        {
            config.pszFooter = footer.c_str();
            config.dwFlags |= TDF_ENABLE_HYPERLINKS;
        }

        BOOL verificationChecked = FALSE;
        int buttonPressed = 0;
        HRESULT hr = taskDialog(&config, &buttonPressed, nullptr, &verificationChecked);
        if (FAILED(hr))
        {
            return NMB_E_PLATFORM_FAILURE;
        }

        out_result->button = static_cast<NmbButtonId>(buttonPressed);
        out_result->checkbox_checked = verificationChecked ? NMB_TRUE : NMB_FALSE;
        out_result->input_value_utf8 = nullptr;
        out_result->was_timeout = state.timed_out ? NMB_TRUE : NMB_FALSE;
        out_result->result_code = NMB_OK;
        return NMB_OK;
    }

    NmbResultCode ShowMessageBoxSimple(const NmbMessageBoxOptions* options, NmbMessageBoxResult* out_result)
    {
        std::wstring title = Utf8ToWide(options->title_utf8);
        std::wstring message = Utf8ToWide(options->message_utf8);

        NmbButtonId defaultButton = NMB_BUTTON_ID_NONE;
        UINT flags = ComposeButtonFlags(options, &defaultButton) | MapMessageBoxIcon(options->icon);

        switch (options->modality)
        {
        case NMB_MODALITY_SYSTEM:
            flags |= MB_SYSTEMMODAL;
            break;
        case NMB_MODALITY_WINDOW:
            flags |= MB_TASKMODAL;
            break;
        default:
            flags |= MB_APPLMODAL;
            break;
        }

        if (defaultButton != NMB_BUTTON_ID_NONE)
        {
            UINT defFlag = 0;
            switch (defaultButton)
            {
            case NMB_BUTTON_ID_CANCEL:
                defFlag = MB_DEFBUTTON2;
                break;
            case NMB_BUTTON_ID_YES:
            case NMB_BUTTON_ID_NO:
            case NMB_BUTTON_ID_RETRY:
            case NMB_BUTTON_ID_IGNORE:
                defFlag = MB_DEFBUTTON3;
                break;
            default:
                defFlag = MB_DEFBUTTON1;
                break;
            }
            flags |= defFlag;
        }

        HWND parent = reinterpret_cast<HWND>(const_cast<void*>(options->parent_window));
        int response = MessageBoxW(parent, message.c_str(), title.empty() ? nullptr : title.c_str(), flags);
        if (response == 0)
        {
            DWORD error = GetLastError();
            out_result->result_code = (error == ERROR_CANCELLED) ? NMB_E_CANCELLED : NMB_E_PLATFORM_FAILURE;
            out_result->button = NMB_BUTTON_ID_NONE;
            out_result->checkbox_checked = NMB_FALSE;
            out_result->input_value_utf8 = nullptr;
            out_result->was_timeout = NMB_FALSE;
            return out_result->result_code;
        }

        out_result->button = MapMessageBoxResult(response);
        out_result->checkbox_checked = NMB_FALSE;
        out_result->input_value_utf8 = nullptr;
        out_result->was_timeout = NMB_FALSE;
        out_result->result_code = NMB_OK;
        return NMB_OK;
    }
}

extern "C"
{

NMB_API NmbResultCode NMB_CALL nmb_initialize(const NmbInitializeOptions* options)
{
    NmbResultCode validation = ValidateInitializeOptions(options);
    if (validation != NMB_OK)
    {
        return validation;
    }

    if (options)
    {
        nmb_runtime_set_log_callback(options->log_callback, options->log_user_data);
    }
    else
    {
        nmb_runtime_set_log_callback(NULL, NULL);
    }

    return NMB_OK;
}

NMB_API NmbResultCode NMB_CALL nmb_show_message_box(const NmbMessageBoxOptions* options, NmbMessageBoxResult* out_result)
{
    if (!options || !options->message_utf8 || !out_result)
    {
        return NMB_E_INVALID_ARGUMENT;
    }

    NmbResultCode validation = ValidateMessageBoxOptions(options);
    if (validation != NMB_OK)
    {
        return validation;
    }

    validation = ValidateMessageBoxResult(out_result);
    if (validation != NMB_OK)
    {
        return validation;
    }

    const bool buttonsSupportedByFallback = ButtonsSupportedByMessageBox(options);

    out_result->struct_size = sizeof(*out_result);
    out_result->button = NMB_BUTTON_ID_NONE;
    out_result->checkbox_checked = NMB_FALSE;
    out_result->input_value_utf8 = nullptr;
    out_result->was_timeout = NMB_FALSE;
    out_result->result_code = NMB_OK;

#if defined(NMB_TESTING)
    if (ApplyTestHarness(options, out_result))
    {
        return out_result->result_code;
    }
#endif

    if (options->input && options->input->mode != NMB_INPUT_CHECKBOX)
    {
        nmb_runtime_log("Windows: Input mode not supported in simple MessageBox fallback.");
        out_result->result_code = NMB_E_NOT_SUPPORTED;
        return NMB_E_NOT_SUPPORTED;
    }

    if (RequiresTaskDialog(options))
    {
        NmbResultCode rc = ShowTaskDialog(options, out_result);
        if (rc == NMB_OK)
        {
            return rc;
        }

        if (rc != NMB_E_NOT_SUPPORTED)
        {
            return rc;
        }

        if (!buttonsSupportedByFallback)
        {
            nmb_runtime_log("Windows: TaskDialogIndirect unavailable and button configuration requires Task Dialog.");
            out_result->result_code = NMB_E_NOT_SUPPORTED;
            return NMB_E_NOT_SUPPORTED;
        }

        nmb_runtime_log("Windows: TaskDialogIndirect unavailable, falling back to MessageBox.");
    }

    return ShowMessageBoxSimple(options, out_result);
}

NMB_API void NMB_CALL nmb_shutdown(void)
{
    nmb_runtime_reset_log();
}

NMB_API uint32_t NMB_CALL nmb_get_abi_version(void)
{
    return NMB_ABI_VERSION;
}

NMB_API void NMB_CALL nmb_set_log_callback(void (*log_callback)(void*, const char*), void* user_data)
{
    nmb_runtime_set_log_callback(log_callback, user_data);
}

} // extern "C"

#endif // _WIN32
