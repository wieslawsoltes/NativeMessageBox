#include "native_message_box.h"

#if defined(__linux__)

#include <gtk/gtk.h>
#include <glib.h>
#include <gdk/gdkkeysyms.h>

#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <utility>
#include <sys/wait.h>
#include <cstddef>

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

    NmbResultCode ValidateInitializeOptions(const NmbInitializeOptions* options)
    {
        if (!options)
        {
            return NMB_OK;
        }

        if (options->struct_size < kInitializeOptionsMinSize)
        {
            return LogInvalid("Linux: NmbInitializeOptions.struct_size is smaller than expected.");
        }

        if (options->abi_version != NMB_ABI_VERSION)
        {
            return LogInvalid("Linux: NmbInitializeOptions.abi_version mismatch.");
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
            return LogInvalid("Linux: NmbMessageBoxOptions.struct_size is smaller than expected.");
        }

        if (options->abi_version != NMB_ABI_VERSION)
        {
            return LogInvalid("Linux: NmbMessageBoxOptions.abi_version mismatch.");
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
            return LogInvalid("Linux: NmbMessageBoxResult.struct_size is smaller than expected.");
        }

        return NMB_OK;
    }

    struct GtkDialogInfo
    {
        GtkWidget* dialog = nullptr;
        GtkWidget* verification = nullptr;
        GtkWidget* inputWidget = nullptr;
        GtkWidget* inputCheckbox = nullptr;
        NmbInputMode inputMode = NMB_INPUT_NONE;
        std::vector<std::pair<int, NmbButtonId>> buttonMap;
        int timeoutResponse = 0;
        bool timedOut = false;
        bool allowClose = true;
        bool requiresExplicitAck = false;
    };

    gboolean TimeoutCallback(gpointer data)
    {
        auto* info = static_cast<GtkDialogInfo*>(data);
        if (!info || !info->dialog)
        {
            return G_SOURCE_REMOVE;
        }

        info->timedOut = true;
        gtk_dialog_response(GTK_DIALOG(info->dialog), info->timeoutResponse);
        return G_SOURCE_REMOVE;
    }

    gboolean OnDeleteEvent(GtkWidget*, GdkEvent*, gpointer data)
    {
        auto* info = static_cast<GtkDialogInfo*>(data);
        if (!info)
        {
            return FALSE;
        }

        return info->allowClose ? FALSE : TRUE;
    }

    gboolean OnKeyPress(GtkWidget*, GdkEventKey* event, gpointer data)
    {
        auto* info = static_cast<GtkDialogInfo*>(data);
        if (!info || !event)
        {
            return FALSE;
        }

        if (event->keyval == GDK_KEY_Escape)
        {
            if (!info->allowClose || info->requiresExplicitAck)
            {
                return TRUE;
            }
        }

        return FALSE;
    }

    GtkMessageType MapMessageType(NmbIcon icon, NmbSeverity severity)
    {
        switch (icon)
        {
        case NMB_ICON_WARNING:
            return GTK_MESSAGE_WARNING;
        case NMB_ICON_ERROR:
            return GTK_MESSAGE_ERROR;
        case NMB_ICON_QUESTION:
            return GTK_MESSAGE_QUESTION;
        case NMB_ICON_SHIELD:
            return GTK_MESSAGE_OTHER;
        default:
            break;
        }

        if (severity == NMB_SEVERITY_CRITICAL)
        {
            return GTK_MESSAGE_ERROR;
        }

        return GTK_MESSAGE_INFO;
    }

    bool EnsureGtkInitialized()
    {
        static bool initialized = false;
        static bool available = false;
        if (!initialized)
        {
            initialized = true;
            available = gtk_init_check(nullptr, nullptr);
        }

        return available;
    }

    NmbResultCode CopyInputValue(const NmbMessageBoxOptions* options, GtkDialogInfo* info, NmbMessageBoxResult* out_result)
    {
        if (!info || !info->inputWidget)
        {
            out_result->input_value_utf8 = nullptr;
            return NMB_OK;
        }

        switch (info->inputMode)
        {
        case NMB_INPUT_TEXT:
        case NMB_INPUT_PASSWORD:
        {
            const char* text = gtk_entry_get_text(GTK_ENTRY(info->inputWidget));
            return nmb_copy_string_to_allocator(options->allocator, text, &out_result->input_value_utf8);
        }
        case NMB_INPUT_COMBO:
        {
            gchar* active = gtk_combo_box_text_get_active_text(GTK_COMBO_BOX_TEXT(info->inputWidget));
            if (!active)
            {
                out_result->input_value_utf8 = nullptr;
                return NMB_OK;
            }

            NmbResultCode rc = nmb_copy_string_to_allocator(options->allocator, active, &out_result->input_value_utf8);
            g_free(active);
            return rc;
        }
        case NMB_INPUT_CHECKBOX:
        {
            if (info->inputCheckbox)
            {
                gboolean active = gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(info->inputCheckbox));
                out_result->checkbox_checked = active ? NMB_TRUE : NMB_FALSE;
            }
            out_result->input_value_utf8 = nullptr;
            return NMB_OK;
        }
        default:
            out_result->input_value_utf8 = nullptr;
            return NMB_OK;
        }
    }

    bool MapButtonId(const GtkDialogInfo& info, int response, NmbButtonId* outId)
    {
        for (const auto& pair : info.buttonMap)
        {
            if (pair.first == response)
            {
                if (outId)
                {
                    *outId = pair.second;
                }
                return true;
            }
        }

        return false;
    }

    bool RunZenityFallback(const NmbMessageBoxOptions* options, NmbMessageBoxResult* out_result)
    {
        if (!options || options->input != nullptr || (options->buttons && options->button_count > 1))
        {
            return false;
        }

        gchar* zenity = g_find_program_in_path("zenity");
        if (!zenity)
        {
            return false;
        }

        std::vector<char*> args;
        args.push_back(zenity);

        switch (options->icon)
        {
        case NMB_ICON_WARNING:
            args.push_back(g_strdup("--warning"));
            break;
        case NMB_ICON_ERROR:
            args.push_back(g_strdup("--error"));
            break;
        case NMB_ICON_QUESTION:
            args.push_back(g_strdup("--question"));
            break;
        default:
            args.push_back(g_strdup("--info"));
            break;
        }

        args.push_back(g_strdup("--no-wrap"));

        if (options->title_utf8)
        {
            args.push_back(g_strdup_printf("--title=%s", options->title_utf8));
        }

        if (options->message_utf8)
        {
            args.push_back(g_strdup_printf("--text=%s", options->message_utf8));
        }

        args.push_back(nullptr);

        GError* error = nullptr;
        gint exitStatus = 0;
        gboolean spawnOk = g_spawn_sync(
            nullptr,
            args.data(),
            nullptr,
            G_SPAWN_DEFAULT,
            nullptr,
            nullptr,
            nullptr,
            nullptr,
            &exitStatus,
            &error);

        for (size_t i = 0; i + 1 < args.size(); ++i)
        {
            g_free(args[i]);
        }

        if (!spawnOk)
        {
            if (error)
            {
                nmb_runtime_log(error->message);
                g_error_free(error);
            }
            return false;
        }

        if (!WIFEXITED(exitStatus))
        {
            nmb_runtime_log("Linux: zenity terminated without exit status.");
            return false;
        }

        int exitCode = WEXITSTATUS(exitStatus);
        out_result->button = (exitCode == 0) ? NMB_BUTTON_ID_OK : NMB_BUTTON_ID_CANCEL;
        out_result->checkbox_checked = NMB_FALSE;
        out_result->input_value_utf8 = nullptr;
        out_result->was_timeout = NMB_FALSE;
        out_result->result_code = NMB_OK;
        return true;
    }

    NmbResultCode ShowGtkDialog(const NmbMessageBoxOptions* options, NmbMessageBoxResult* out_result)
    {
        GtkDialogInfo info = {};
        GtkMessageType messageType = MapMessageType(options->icon, options->severity);

        GtkWidget* dialog = gtk_message_dialog_new(
            options->parent_window ? GTK_WINDOW(const_cast<void*>(options->parent_window)) : nullptr,
            GTK_DIALOG_MODAL,
            messageType,
            GTK_BUTTONS_NONE,
            "%s",
            options->message_utf8 ? options->message_utf8 : "");

        info.dialog = dialog;

        if (options->title_utf8)
        {
            gtk_window_set_title(GTK_WINDOW(dialog), options->title_utf8);
        }

        if (options->secondary && options->secondary->informative_text_utf8)
        {
            gtk_message_dialog_format_secondary_text(GTK_MESSAGE_DIALOG(dialog), "%s", options->secondary->informative_text_utf8);
        }

        GtkBox* content = GTK_BOX(gtk_dialog_get_content_area(GTK_DIALOG(dialog)));

        if (options->secondary && options->secondary->expanded_text_utf8)
        {
            GtkWidget* expander = gtk_expander_new("More details");
            GtkWidget* expanded_label = gtk_label_new(options->secondary->expanded_text_utf8);
            gtk_label_set_xalign(GTK_LABEL(expanded_label), 0.0f);
            gtk_label_set_line_wrap(GTK_LABEL(expanded_label), TRUE);
            gtk_label_set_selectable(GTK_LABEL(expanded_label), FALSE);
            gtk_container_add(GTK_CONTAINER(expander), expanded_label);
            gtk_box_pack_start(content, expander, FALSE, FALSE, 0);
        }

        if (options->secondary && options->secondary->help_link_utf8)
        {
            GtkWidget* link = gtk_link_button_new_with_label(options->secondary->help_link_utf8, "Open Help");
            gtk_box_pack_start(content, link, FALSE, FALSE, 0);
        }

        if (options->show_suppress_checkbox == NMB_TRUE && options->verification_text_utf8)
        {
            info.verification = gtk_check_button_new_with_label(options->verification_text_utf8);
            gtk_box_pack_start(content, info.verification, FALSE, FALSE, 0);
        }

        if (options->input)
        {
            info.inputMode = options->input->mode;
            switch (options->input->mode)
            {
            case NMB_INPUT_TEXT:
            case NMB_INPUT_PASSWORD:
            {
                GtkWidget* label = nullptr;
                if (options->input->prompt_utf8)
                {
                    label = gtk_label_new(options->input->prompt_utf8);
                    gtk_label_set_xalign(GTK_LABEL(label), 0.0f);
                    gtk_box_pack_start(content, label, FALSE, FALSE, 0);
                }

                GtkWidget* entry = gtk_entry_new();
                if (options->input->mode == NMB_INPUT_PASSWORD)
                {
                    gtk_entry_set_visibility(GTK_ENTRY(entry), FALSE);
                }

                if (options->input->default_value_utf8)
                {
                    gtk_entry_set_text(GTK_ENTRY(entry), options->input->default_value_utf8);
                }

                info.inputWidget = entry;
                gtk_box_pack_start(content, entry, FALSE, FALSE, 0);
                break;
            }
            case NMB_INPUT_COMBO:
            {
                GtkWidget* label = nullptr;
                if (options->input->prompt_utf8)
                {
                    label = gtk_label_new(options->input->prompt_utf8);
                    gtk_label_set_xalign(GTK_LABEL(label), 0.0f);
                    gtk_box_pack_start(content, label, FALSE, FALSE, 0);
                }

                GtkWidget* combo = gtk_combo_box_text_new();
                if (options->input->combo_items_utf8)
                {
                    const char* const* items = options->input->combo_items_utf8;
                    int index = 0;
                    int defaultIndex = -1;
                    while (items && *items)
                    {
                        gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(combo), *items);
                        if (options->input->default_value_utf8 && strcmp(options->input->default_value_utf8, *items) == 0)
                        {
                            defaultIndex = index;
                        }
                        ++index;
                        ++items;
                    }

                    if (defaultIndex >= 0)
                    {
                        gtk_combo_box_set_active(GTK_COMBO_BOX(combo), defaultIndex);
                    }
                    else if (index > 0)
                    {
                        gtk_combo_box_set_active(GTK_COMBO_BOX(combo), 0);
                    }

                    if (options->input->default_value_utf8 && defaultIndex == -1)
                    {
                        gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(combo), options->input->default_value_utf8);
                        gtk_combo_box_set_active(GTK_COMBO_BOX(combo), index);
                    }
                }

                info.inputWidget = combo;
                gtk_box_pack_start(content, combo, FALSE, FALSE, 0);
                break;
            }
            case NMB_INPUT_CHECKBOX:
            {
                GtkWidget* checkbox = gtk_check_button_new_with_label(options->input->prompt_utf8 ? options->input->prompt_utf8 : "");
                if (options->input->default_value_utf8 && strcmp(options->input->default_value_utf8, "true") == 0)
                {
                    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(checkbox), TRUE);
                }

                info.inputCheckbox = checkbox;
                gtk_box_pack_start(content, checkbox, FALSE, FALSE, 0);
                break;
            }
            default:
                break;
            }
        }

        if (options->buttons && options->button_count > 0)
        {
            for (size_t i = 0; i < options->button_count; ++i)
            {
                const NmbButtonOption& button = options->buttons[i];
                int responseId = GTK_RESPONSE_NONE - static_cast<int>(i) - 1;
                gtk_dialog_add_button(GTK_DIALOG(dialog), button.label_utf8 ? button.label_utf8 : "", responseId);
                info.buttonMap.emplace_back(responseId, button.id);
                if (button.is_default)
                {
                    gtk_dialog_set_default_response(GTK_DIALOG(dialog), responseId);
                }
            }
        }
        else
        {
            gtk_dialog_add_button(GTK_DIALOG(dialog), "OK", GTK_RESPONSE_OK);
            info.buttonMap.emplace_back(GTK_RESPONSE_OK, NMB_BUTTON_ID_OK);
        }

        info.requiresExplicitAck = options->requires_explicit_ack == NMB_TRUE;
        info.allowClose = (options->allow_cancel_via_escape == NMB_TRUE) && !info.requiresExplicitAck;
        g_signal_connect(dialog, "delete-event", G_CALLBACK(OnDeleteEvent), &info);
        g_signal_connect(dialog, "key-press-event", G_CALLBACK(OnKeyPress), &info);

        if (options->timeout_milliseconds > 0 && options->timeout_button_id != NMB_BUTTON_ID_NONE)
        {
            int mappedResponse = 0;
            for (const auto& pair : info.buttonMap)
            {
                if (pair.second == options->timeout_button_id)
                {
                    mappedResponse = pair.first;
                    break;
                }
            }

            if (mappedResponse != 0)
            {
                info.timeoutResponse = mappedResponse;
                g_timeout_add(options->timeout_milliseconds, TimeoutCallback, &info);
            }
        }

        gtk_widget_show_all(dialog);

        int response = gtk_dialog_run(GTK_DIALOG(dialog));

        NmbButtonId button = NMB_BUTTON_ID_NONE;
        bool mapped = MapButtonId(info, response, &button);

        if (info.verification)
        {
            gboolean value = gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(info.verification));
            out_result->checkbox_checked = value ? NMB_TRUE : NMB_FALSE;
        }

        out_result->was_timeout = info.timedOut ? NMB_TRUE : NMB_FALSE;

        if (!mapped)
        {
            switch (response)
            {
            case GTK_RESPONSE_DELETE_EVENT:
            case GTK_RESPONSE_CANCEL:
            case GTK_RESPONSE_CLOSE:
            case GTK_RESPONSE_REJECT:
            case GTK_RESPONSE_NONE:
                out_result->button = NMB_BUTTON_ID_CANCEL;
                out_result->input_value_utf8 = nullptr;
                gtk_widget_destroy(dialog);
                out_result->result_code = NMB_E_CANCELLED;
                return NMB_E_CANCELLED;
            default:
                break;
            }
        }

        out_result->button = button;

        NmbResultCode rc = CopyInputValue(options, &info, out_result);
        gtk_widget_destroy(dialog);

        if (rc != NMB_OK)
        {
            out_result->result_code = rc;
            return rc;
        }

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

    if (!EnsureGtkInitialized())
    {
        nmb_runtime_log("Linux: GTK initialization failed; will rely on fallback strategies.");
        return NMB_E_PLATFORM_FAILURE;
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

    if (!EnsureGtkInitialized())
    {
        nmb_runtime_log("Linux: GTK unavailable, attempting zenity fallback.");
        if (RunZenityFallback(options, out_result))
        {
            return NMB_OK;
        }

        nmb_runtime_log("Linux: No GUI backend available for message box.");
        return NMB_E_PLATFORM_FAILURE;
    }

    return ShowGtkDialog(options, out_result);
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

#endif // __linux__
