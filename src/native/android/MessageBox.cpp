#include "native_message_box.h"

#if defined(__ANDROID__)

#include <android/log.h>
#include <jni.h>

#include <cstddef>
#include <condition_variable>
#include <mutex>
#include <vector>

#include "../../shared/nmb_alloc.h"
#include "../../shared/nmb_runtime.h"
#if defined(NMB_TESTING)
#include "native_message_box_test.h"
#endif

#define NMB_ANDROID_LOG_TAG "NativeMessageBox"

namespace
{

JavaVM* g_javaVm = nullptr;
jclass g_bridgeClass = nullptr;
jmethodID g_showDialogMethod = nullptr;

constexpr const char* kBridgeClassName = "com/nativeinterop/NativeMessageBoxBridge";

struct DialogState
{
    std::mutex mutex;
    std::condition_variable cv;
    bool completed = false;
    bool cancelled = false;
    bool error = false;
    NmbResultCode error_code = NMB_OK;
    NmbButtonId button = NMB_BUTTON_ID_NONE;
};

static void AndroidLog(const char* message)
{
    if (message)
    {
        __android_log_print(ANDROID_LOG_INFO, NMB_ANDROID_LOG_TAG, "%s", message);
    }
    nmb_runtime_log(message);
}

static JNIEnv* AcquireEnv(bool& didAttach)
{
    didAttach = false;
    if (!g_javaVm)
    {
        AndroidLog("Android: JavaVM not initialized.");
        return nullptr;
    }

    JNIEnv* env = nullptr;
    jint getEnvResult = g_javaVm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
    if (getEnvResult == JNI_OK)
    {
        return env;
    }

    if (getEnvResult == JNI_EDETACHED)
    {
        if (g_javaVm->AttachCurrentThread(&env, nullptr) != JNI_OK)
        {
            AndroidLog("Android: Failed to attach current thread to JVM.");
            return nullptr;
        }

        didAttach = true;
        return env;
    }

    AndroidLog("Android: GetEnv returned unexpected result.");
    return nullptr;
}

static void ReleaseEnv(bool didAttach)
{
    if (didAttach && g_javaVm)
    {
        g_javaVm->DetachCurrentThread();
    }
}

static bool EnsureBridge(JNIEnv* env)
{
    if (!env)
    {
        return false;
    }

    if (g_bridgeClass && g_showDialogMethod)
    {
        return true;
    }

    jclass local = env->FindClass(kBridgeClassName);
    if (!local)
    {
        AndroidLog("Android: Unable to find NativeMessageBoxBridge class. Ensure the helper Java source is bundled.");
        return false;
    }

    g_bridgeClass = static_cast<jclass>(env->NewGlobalRef(local));
    env->DeleteLocalRef(local);

    if (!g_bridgeClass)
    {
        AndroidLog("Android: Failed to create global reference for NativeMessageBoxBridge.");
        return false;
    }

    g_showDialogMethod = env->GetStaticMethodID(
        g_bridgeClass,
        "showMessageDialog",
        "(Landroid/app/Activity;JLjava/lang/String;Ljava/lang/String;[Ljava/lang/String;[JIZ)V");

    if (!g_showDialogMethod)
    {
        AndroidLog("Android: Unable to locate showMessageDialog method on NativeMessageBoxBridge.");
        return false;
    }

    return true;
}

static const size_t kMessageBoxOptionsMinSize =
    offsetof(NmbMessageBoxOptions, user_context) + sizeof(void*);
static const size_t kMessageBoxResultMinSize =
    offsetof(NmbMessageBoxResult, result_code) + sizeof(NmbResultCode);

static NmbResultCode ValidateMessageBoxOptions(const NmbMessageBoxOptions* options)
{
    if (!options)
    {
        return NMB_E_INVALID_ARGUMENT;
    }

    if (options->struct_size < kMessageBoxOptionsMinSize)
    {
        AndroidLog("Android: NmbMessageBoxOptions.struct_size is smaller than expected.");
        return NMB_E_INVALID_ARGUMENT;
    }

    if (options->abi_version != NMB_ABI_VERSION)
    {
        AndroidLog("Android: NmbMessageBoxOptions.abi_version mismatch.");
        return NMB_E_INVALID_ARGUMENT;
    }

    if (!options->message_utf8)
    {
        AndroidLog("Android: message_utf8 is required.");
        return NMB_E_INVALID_ARGUMENT;
    }

    return NMB_OK;
}

static NmbResultCode ValidateMessageBoxResult(const NmbMessageBoxResult* result)
{
    if (!result)
    {
        return NMB_E_INVALID_ARGUMENT;
    }

    if (result->struct_size < kMessageBoxResultMinSize)
    {
        AndroidLog("Android: NmbMessageBoxResult.struct_size is smaller than expected.");
        return NMB_E_INVALID_ARGUMENT;
    }

    return NMB_OK;
}

static void LogUnsupportedFeatures(const NmbMessageBoxOptions* options)
{
    if (!options)
    {
        return;
    }

    if (options->secondary && (options->secondary->informative_text_utf8 ||
                               options->secondary->expanded_text_utf8 ||
                               options->secondary->footer_text_utf8 ||
                               options->secondary->help_link_utf8))
    {
        AndroidLog("Android: Secondary content is not supported and will be ignored.");
    }

    if (options->verification_text_utf8 || options->show_suppress_checkbox == NMB_TRUE)
    {
        AndroidLog("Android: Verification checkboxes are not supported.");
    }

    if (options->input && options->input->mode != NMB_INPUT_NONE)
    {
        AndroidLog("Android: Input controls are not supported.");
    }

    if (options->icon != NMB_ICON_NONE)
    {
        AndroidLog("Android: Icon hints are not currently supported.");
    }

    if (options->button_count > 3)
    {
        AndroidLog("Android: Only the first three buttons are supported (positive, negative, neutral).");
    }
}

static std::vector<const NmbButtonOption*> CollectButtons(const NmbMessageBoxOptions* options)
{
    std::vector<const NmbButtonOption*> buttons;

    if (!options || !options->buttons || options->button_count == 0)
    {
        static NmbButtonOption defaultButton =
        {
            static_cast<uint32_t>(sizeof(NmbButtonOption)),
            NMB_BUTTON_ID_OK,
            "OK",
            nullptr,
            NMB_BUTTON_KIND_PRIMARY,
            NMB_TRUE,
            NMB_FALSE
        };
        buttons.push_back(&defaultButton);
        return buttons;
    }

    size_t limit = options->button_count;
    if (limit > 3)
    {
        limit = 3;
    }

    for (size_t i = 0; i < limit; ++i)
    {
        buttons.push_back(&options->buttons[i]);
    }

    return buttons;
}

static int FindCancelIndex(const std::vector<const NmbButtonOption*>& buttons)
{
    for (size_t i = 0; i < buttons.size(); ++i)
    {
        if (buttons[i]->is_cancel == NMB_TRUE)
        {
            return static_cast<int>(i);
        }
    }

    return -1;
}

#if defined(NMB_TESTING)
static bool ApplyTestHarness(const NmbMessageBoxOptions* options, NmbMessageBoxResult* out_result)
{
    if (!options || !out_result || !options->user_context)
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
        if (harness->result_code == NMB_OK)
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
    }

    return true;
}
#endif

static NmbResultCode ShowDialogInternal(const NmbMessageBoxOptions* options, NmbMessageBoxResult* out_result)
{
    if (!options || !out_result)
    {
        return NMB_E_INVALID_ARGUMENT;
    }

#if defined(NMB_TESTING)
    if (ApplyTestHarness(options, out_result))
    {
        return out_result->result_code;
    }
#endif

    if (!options->parent_window)
    {
        AndroidLog("Android: parent_window must provide an Activity jobject handle.");
        return NMB_E_INVALID_ARGUMENT;
    }

    bool didAttach = false;
    JNIEnv* env = AcquireEnv(didAttach);
    if (!env)
    {
        return NMB_E_PLATFORM_FAILURE;
    }

    if (!EnsureBridge(env))
    {
        ReleaseEnv(didAttach);
        return NMB_E_PLATFORM_FAILURE;
    }

    jobject activity = reinterpret_cast<jobject>(const_cast<void*>(options->parent_window));
    jobject activityLocal = env->NewLocalRef(activity);
    if (!activityLocal)
    {
        AndroidLog("Android: Invalid Activity reference provided via parent_window.");
        ReleaseEnv(didAttach);
        return NMB_E_INVALID_ARGUMENT;
    }

    std::vector<const NmbButtonOption*> buttons = CollectButtons(options);
    const size_t buttonCount = buttons.size();

    jclass stringClass = env->FindClass("java/lang/String");
    if (!stringClass)
    {
        env->DeleteLocalRef(activityLocal);
        ReleaseEnv(didAttach);
        AndroidLog("Android: Unable to find java/lang/String class.");
        return NMB_E_PLATFORM_FAILURE;
    }

    jobjectArray labelArray = env->NewObjectArray(static_cast<jsize>(buttonCount), stringClass, nullptr);
    env->DeleteLocalRef(stringClass);
    if (!labelArray)
    {
        env->DeleteLocalRef(activityLocal);
        ReleaseEnv(didAttach);
        AndroidLog("Android: Unable to allocate button label array.");
        return NMB_E_PLATFORM_FAILURE;
    }

    jlongArray idArray = env->NewLongArray(static_cast<jsize>(buttonCount));
    if (!idArray)
    {
        env->DeleteLocalRef(labelArray);
        env->DeleteLocalRef(activityLocal);
        ReleaseEnv(didAttach);
        AndroidLog("Android: Unable to allocate button id array.");
        return NMB_E_PLATFORM_FAILURE;
    }

    std::vector<jlong> buttonIds(buttonCount, 0);
    for (size_t i = 0; i < buttonCount; ++i)
    {
        const NmbButtonOption* button = buttons[i];
        jstring label = env->NewStringUTF(button && button->label_utf8 ? button->label_utf8 : "");
        if (!label)
        {
            env->DeleteLocalRef(idArray);
            env->DeleteLocalRef(labelArray);
            env->DeleteLocalRef(activityLocal);
            ReleaseEnv(didAttach);
            AndroidLog("Android: Failed to allocate button label string.");
            return NMB_E_OUT_OF_MEMORY;
        }

        env->SetObjectArrayElement(labelArray, static_cast<jsize>(i), label);
        env->DeleteLocalRef(label);

        buttonIds[i] = button ? static_cast<jlong>(button->id) : static_cast<jlong>(NMB_BUTTON_ID_OK);
    }

    env->SetLongArrayRegion(idArray, 0, static_cast<jsize>(buttonCount), buttonIds.data());

    jstring title = env->NewStringUTF(options->title_utf8 ? options->title_utf8 : "");
    jstring message = env->NewStringUTF(options->message_utf8 ? options->message_utf8 : "");

    DialogState state;
    jint cancelIndex = FindCancelIndex(buttons);
    jboolean cancellable = (options->allow_cancel_via_escape == NMB_TRUE) ? JNI_TRUE : JNI_FALSE;

    env->CallStaticVoidMethod(
        g_bridgeClass,
        g_showDialogMethod,
        activityLocal,
        reinterpret_cast<jlong>(&state),
        title,
        message,
        labelArray,
        idArray,
        cancelIndex,
        cancellable);

    env->DeleteLocalRef(title);
    env->DeleteLocalRef(message);
    env->DeleteLocalRef(idArray);
    env->DeleteLocalRef(labelArray);
    env->DeleteLocalRef(activityLocal);

    if (env->ExceptionCheck())
    {
        env->ExceptionClear();
        ReleaseEnv(didAttach);
        AndroidLog("Android: Exception thrown while displaying dialog.");
        return NMB_E_PLATFORM_FAILURE;
    }

    {
        std::unique_lock<std::mutex> lock(state.mutex);
        state.cv.wait(lock, [&state] { return state.completed; });
    }

    ReleaseEnv(didAttach);

    if (state.error)
    {
        return state.error_code;
    }

    out_result->checkbox_checked = NMB_FALSE;
    out_result->input_value_utf8 = nullptr;
    out_result->was_timeout = NMB_FALSE;

    if (state.cancelled)
    {
        if (state.button != NMB_BUTTON_ID_NONE)
        {
            out_result->button = state.button;
        }
        else if (cancelIndex >= 0 && static_cast<size_t>(cancelIndex) < buttonIds.size())
        {
            out_result->button = static_cast<NmbButtonId>(buttonIds[static_cast<size_t>(cancelIndex)]);
        }
        else
        {
            out_result->button = NMB_BUTTON_ID_CANCEL;
        }

        out_result->result_code = NMB_E_CANCELLED;
        return NMB_E_CANCELLED;
    }

    out_result->button = state.button;
    out_result->result_code = NMB_OK;
    return NMB_OK;
}

} // namespace

extern "C"
{

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*)
{
    g_javaVm = vm;

    JNIEnv* env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK)
    {
        return JNI_ERR;
    }

    EnsureBridge(env);
    return JNI_VERSION_1_6;
}

JNIEXPORT void JNICALL Java_com_nativeinterop_NativeMessageBoxBridge_nativeOnDialogCompleted(
    JNIEnv*, jclass, jlong handle, jlong buttonId, jboolean cancelled)
{
    auto* state = reinterpret_cast<DialogState*>(handle);
    if (!state)
    {
        return;
    }

    std::lock_guard<std::mutex> lock(state->mutex);
    state->completed = true;
    state->button = static_cast<NmbButtonId>(buttonId);
    state->cancelled = (cancelled == JNI_TRUE);
    state->cv.notify_all();
}

JNIEXPORT void JNICALL Java_com_nativeinterop_NativeMessageBoxBridge_nativeOnDialogError(
    JNIEnv*, jclass, jlong handle, jint errorCode)
{
    auto* state = reinterpret_cast<DialogState*>(handle);
    if (!state)
    {
        return;
    }

    std::lock_guard<std::mutex> lock(state->mutex);
    state->completed = true;
    state->error = true;
    state->error_code = static_cast<NmbResultCode>(errorCode);
    state->cv.notify_all();
}

} // extern "C"

extern "C"
{

NMB_API NmbResultCode NMB_CALL nmb_initialize(const NmbInitializeOptions* options)
{
    (void)options;

    if (options)
    {
        nmb_runtime_set_log_callback(options->log_callback, options->log_user_data);
    }
    else
    {
        nmb_runtime_set_log_callback(nullptr, nullptr);
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

    LogUnsupportedFeatures(options);

    NmbResultCode result = ShowDialogInternal(options, out_result);
    return result;
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

#endif // defined(__ANDROID__)
