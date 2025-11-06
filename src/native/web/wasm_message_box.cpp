#include "../../../include/native_message_box.h"
#include "../../shared/nmb_alloc.h"
#include "../../shared/nmb_runtime.h"

#include <emscripten/emscripten.h>

#include <cstdint>
#include <cstdlib>
#include <vector>

namespace
{
    struct NmbWasmButton
    {
        uint32_t id;
        uint32_t kind;
        uint32_t is_default;
        uint32_t is_cancel;
        uint32_t label_ptr;
        uint32_t description_ptr;
    };

    struct NmbWasmInput
    {
        uint32_t mode;
        uint32_t prompt_ptr;
        uint32_t placeholder_ptr;
        uint32_t default_value_ptr;
        uint32_t combo_items_ptr;
        uint32_t combo_count;
    };

    struct NmbWasmSecondary
    {
        uint32_t informative_ptr;
        uint32_t expanded_ptr;
        uint32_t footer_ptr;
        uint32_t help_link_ptr;
    };

    struct NmbWasmRequest
    {
        uint32_t title_ptr;
        uint32_t message_ptr;
        uint32_t buttons_ptr;
        uint32_t button_count;
        uint32_t icon;
        uint32_t severity;
        uint32_t modality;
        uint32_t verification_text_ptr;
        uint32_t allow_escape;
        uint32_t show_suppress_checkbox;
        uint32_t requires_explicit_ack;
        uint32_t timeout_milliseconds;
        uint32_t timeout_button_id;
        uint32_t locale_ptr;
        uint32_t input_ptr;
        uint32_t secondary_ptr;
    };

    struct NmbWasmResponse
    {
        uint32_t result_code;
        uint32_t button_id;
        uint32_t checkbox_checked;
        uint32_t was_timeout;
        uint32_t input_ptr;
        uint32_t input_length;
    };

    static_assert(sizeof(NmbWasmButton) == 24, "Unexpected NmbWasmButton size.");
    static_assert(sizeof(NmbWasmInput) == 24, "Unexpected NmbWasmInput size.");
    static_assert(sizeof(NmbWasmSecondary) == 16, "Unexpected NmbWasmSecondary size.");
    static_assert(sizeof(NmbWasmRequest) == 64, "Unexpected NmbWasmRequest size.");
    static_assert(sizeof(NmbWasmResponse) == 24, "Unexpected NmbWasmResponse size.");

    inline uint32_t ToPtr(const void* value)
    {
        return static_cast<uint32_t>(reinterpret_cast<uintptr_t>(value));
    }

    NmbResultCode ValidateMessageBoxOptions(const NmbMessageBoxOptions* options)
    {
        if (!options)
        {
            return NMB_E_INVALID_ARGUMENT;
        }

        if (options->struct_size < sizeof(NmbMessageBoxOptions))
        {
            return NMB_E_INVALID_ARGUMENT;
        }

        if (options->abi_version != NMB_ABI_VERSION)
        {
            return NMB_E_INVALID_ARGUMENT;
        }

        if (!options->message_utf8)
        {
            return NMB_E_INVALID_ARGUMENT;
        }

        if (options->button_count > 0 && !options->buttons)
        {
            return NMB_E_INVALID_ARGUMENT;
        }

        return NMB_OK;
    }

    NmbResultCode ValidateMessageBoxResult(const NmbMessageBoxResult* result)
    {
        if (!result)
        {
            return NMB_E_INVALID_ARGUMENT;
        }

        if (result->struct_size < sizeof(NmbMessageBoxResult))
        {
            return NMB_E_INVALID_ARGUMENT;
        }

        return NMB_OK;
    }

    void ApplyLogCallback(const NmbInitializeOptions* options)
    {
        if (options && options->log_callback)
        {
            nmb_runtime_set_log_callback(options->log_callback, options->log_user_data);
        }
        else
        {
            nmb_runtime_reset_log();
        }
    }

    EM_JS(void, nmb_wasm_set_runtime_name, (const char* name_ptr), {
        if (!Module.nativeMessageBox) {
            Module.nativeMessageBox = null;
        }
        Module.nativeMessageBoxRuntimeName = name_ptr ? UTF8ToString(name_ptr) : "";
    });

    EM_JS(void, nmb_wasm_shutdown, (), {
        if (Module.nativeMessageBoxInterop && Module.nativeMessageBoxInterop.shutdown) {
            Module.nativeMessageBoxInterop.shutdown();
        }
    });

    EM_ASYNC_JS(int, nmb_wasm_dispatch_message_box, (uint32_t request_ptr, uint32_t response_ptr), {
        try {
            if (!Module.nativeMessageBoxInterop || !Module.nativeMessageBoxInterop.dispatch) {
                if (Module.nmbCreateMessageBoxInterop) {
                    Module.nativeMessageBoxInterop = Module.nmbCreateMessageBoxInterop(Module);
                } else {
                    throw new Error("Module.nmbCreateMessageBoxInterop is missing.");
                }
            }

            await Module.nativeMessageBoxInterop.dispatch(request_ptr, response_ptr);
            return 0;
        } catch (err) {
            console.error("NativeMessageBox wasm dispatch failed", err);
            return 1;
        }
    });
} // namespace

extern "C"
{

NMB_API NmbResultCode NMB_CALL nmb_initialize(const NmbInitializeOptions* options)
{
    if (options)
    {
        if (options->struct_size < sizeof(NmbInitializeOptions))
        {
            return NMB_E_INVALID_ARGUMENT;
        }

        if (options->abi_version != NMB_ABI_VERSION)
        {
            return NMB_E_INVALID_ARGUMENT;
        }
    }

    ApplyLogCallback(options);

    if (options && options->runtime_name_utf8)
    {
        nmb_wasm_set_runtime_name(options->runtime_name_utf8);
    }

    return NMB_OK;
}

NMB_API NmbResultCode NMB_CALL nmb_show_message_box(const NmbMessageBoxOptions* options, NmbMessageBoxResult* out_result)
{
    if (!options || !out_result)
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

    std::vector<NmbWasmButton> buttons;
    buttons.reserve(options->button_count);
    if (options->buttons && options->button_count > 0)
    {
        for (size_t i = 0; i < options->button_count; ++i)
        {
            const NmbButtonOption& button = options->buttons[i];
            NmbWasmButton wasmButton{};
            wasmButton.id = static_cast<uint32_t>(button.id);
            wasmButton.kind = static_cast<uint32_t>(button.kind);
            wasmButton.is_default = button.is_default ? 1u : 0u;
            wasmButton.is_cancel = button.is_cancel ? 1u : 0u;
            wasmButton.label_ptr = ToPtr(button.label_utf8);
            wasmButton.description_ptr = ToPtr(button.description_utf8);
            buttons.push_back(wasmButton);
        }
    }

    std::vector<uint32_t> comboItems;
    NmbWasmInput wasmInput{};
    uint32_t inputPtr = 0;
    if (options->input)
    {
        const NmbInputOption& input = *options->input;
        wasmInput.mode = static_cast<uint32_t>(input.mode);
        wasmInput.prompt_ptr = ToPtr(input.prompt_utf8);
        wasmInput.placeholder_ptr = ToPtr(input.placeholder_utf8);
        wasmInput.default_value_ptr = ToPtr(input.default_value_utf8);
        wasmInput.combo_items_ptr = 0;
        wasmInput.combo_count = 0;

        if (input.mode == NMB_INPUT_COMBO && input.combo_items_utf8)
        {
            const char* const* items = input.combo_items_utf8;
            while (*items)
            {
                comboItems.push_back(ToPtr(*items));
                ++items;
            }
            wasmInput.combo_count = static_cast<uint32_t>(comboItems.size());
            if (!comboItems.empty())
            {
                wasmInput.combo_items_ptr = ToPtr(comboItems.data());
            }
        }

        inputPtr = ToPtr(&wasmInput);
    }

    NmbWasmSecondary wasmSecondary{};
    uint32_t secondaryPtr = 0;
    if (options->secondary)
    {
        wasmSecondary.informative_ptr = ToPtr(options->secondary->informative_text_utf8);
        wasmSecondary.expanded_ptr = ToPtr(options->secondary->expanded_text_utf8);
        wasmSecondary.footer_ptr = ToPtr(options->secondary->footer_text_utf8);
        wasmSecondary.help_link_ptr = ToPtr(options->secondary->help_link_utf8);
        secondaryPtr = ToPtr(&wasmSecondary);
    }

    NmbWasmRequest request{};
    request.title_ptr = ToPtr(options->title_utf8);
    request.message_ptr = ToPtr(options->message_utf8);
    request.buttons_ptr = buttons.empty() ? 0u : ToPtr(buttons.data());
    request.button_count = static_cast<uint32_t>(buttons.size());
    request.icon = static_cast<uint32_t>(options->icon);
    request.severity = static_cast<uint32_t>(options->severity);
    request.modality = static_cast<uint32_t>(options->modality);
    request.verification_text_ptr = ToPtr(options->verification_text_utf8);
    request.allow_escape = options->allow_cancel_via_escape ? 1u : 0u;
    request.show_suppress_checkbox = options->show_suppress_checkbox ? 1u : 0u;
    request.requires_explicit_ack = options->requires_explicit_ack ? 1u : 0u;
    request.timeout_milliseconds = options->timeout_milliseconds;
    request.timeout_button_id = static_cast<uint32_t>(options->timeout_button_id);
    request.locale_ptr = ToPtr(options->locale_utf8);
    request.input_ptr = inputPtr;
    request.secondary_ptr = secondaryPtr;

    NmbWasmResponse response{};
    int dispatch_rc = nmb_wasm_dispatch_message_box(ToPtr(&request), ToPtr(&response));
    if (dispatch_rc != 0)
    {
        out_result->result_code = NMB_E_PLATFORM_FAILURE;
        return NMB_E_PLATFORM_FAILURE;
    }

    out_result->result_code = static_cast<NmbResultCode>(response.result_code);
    out_result->button = static_cast<NmbButtonId>(response.button_id);
    out_result->checkbox_checked = response.checkbox_checked ? NMB_TRUE : NMB_FALSE;
    out_result->was_timeout = response.was_timeout ? NMB_TRUE : NMB_FALSE;

    if (response.input_ptr != 0)
    {
        const char* input_utf8 = reinterpret_cast<const char*>(static_cast<uintptr_t>(response.input_ptr));
        NmbResultCode copy_rc = nmb_copy_string_to_allocator(options->allocator, input_utf8, &out_result->input_value_utf8);
        std::free(reinterpret_cast<void*>(static_cast<uintptr_t>(response.input_ptr)));
        if (copy_rc != NMB_OK)
        {
            out_result->result_code = copy_rc;
            return copy_rc;
        }
    }

    return out_result->result_code;
}

NMB_API void NMB_CALL nmb_shutdown(void)
{
    nmb_runtime_reset_log();
    nmb_wasm_shutdown();
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
