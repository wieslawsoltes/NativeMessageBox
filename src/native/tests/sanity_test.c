#include "native_message_box.h"
#include "native_message_box_test.h"

#include <stdio.h>
#include <string.h>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#include <dispatch/dispatch.h>
#endif

static void log_sink(void* user_data, const char* message)
{
    (void)user_data;
    if (message)
    {
        fprintf(stderr, "[nmb-test] %s\n", message);
    }
}

static void init_button_option(NmbButtonOption* option, NmbButtonId id, const char* label, nmb_bool is_default, nmb_bool is_cancel)
{
    memset(option, 0, sizeof(*option));
    option->struct_size = sizeof(*option);
    option->id = id;
    option->label_utf8 = label;
    option->kind = NMB_BUTTON_KIND_DEFAULT;
    option->is_default = is_default;
    option->is_cancel = is_cancel;
}

static void init_options(NmbMessageBoxOptions* options, const NmbButtonOption* buttons, size_t button_count)
{
    memset(options, 0, sizeof(*options));
    options->struct_size = sizeof(*options);
    options->abi_version = NMB_ABI_VERSION;
    options->title_utf8 = "Test";
    options->message_utf8 = "Test message";
    options->buttons = buttons;
    options->button_count = button_count;
    options->allow_cancel_via_escape = NMB_TRUE;
    options->show_suppress_checkbox = NMB_FALSE;
    options->requires_explicit_ack = NMB_FALSE;
    options->timeout_milliseconds = 0;
    options->timeout_button_id = NMB_BUTTON_ID_NONE;
}

static int run_null_options_test(void)
{
    NmbMessageBoxResult result;
    memset(&result, 0, sizeof(result));
    result.struct_size = sizeof(result);

    NmbResultCode rc = nmb_show_message_box(NULL, &result);
    if (rc != NMB_E_INVALID_ARGUMENT)
    {
        fprintf(stderr, "Expected invalid argument for NULL options, got: %u\n", rc);
        return 1;
    }

    return 0;
}

static int run_standard_button_tests(void)
{
    const struct
    {
        NmbButtonId id;
        const char* label;
        nmb_bool is_cancel;
    } cases[] = {
        { NMB_BUTTON_ID_OK, "OK", NMB_FALSE },
        { NMB_BUTTON_ID_CANCEL, "Cancel", NMB_TRUE },
        { NMB_BUTTON_ID_YES, "Yes", NMB_FALSE },
        { NMB_BUTTON_ID_NO, "No", NMB_FALSE },
        { NMB_BUTTON_ID_RETRY, "Retry", NMB_FALSE },
        { NMB_BUTTON_ID_CONTINUE, "Continue", NMB_FALSE },
        { NMB_BUTTON_ID_IGNORE, "Ignore", NMB_FALSE },
        { NMB_BUTTON_ID_ABORT, "Abort", NMB_FALSE },
        { NMB_BUTTON_ID_CLOSE, "Close", NMB_TRUE },
        { NMB_BUTTON_ID_TRY_AGAIN, "Try Again", NMB_FALSE },
        { NMB_BUTTON_ID_HELP, "Help", NMB_FALSE }
    };

    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i)
    {
        NmbButtonOption button;
        init_button_option(&button, cases[i].id, cases[i].label, NMB_TRUE, cases[i].is_cancel);

        NmbMessageBoxOptions options;
        init_options(&options, &button, 1);

        NmbTestHarness harness;
        memset(&harness, 0, sizeof(harness));
        harness.struct_size = sizeof(harness);
        harness.magic = NMB_TEST_HARNESS_MAGIC;
        harness.scripted_button = cases[i].id;
        harness.result_code = NMB_OK;
        options.user_context = &harness;

        NmbMessageBoxResult result;
        memset(&result, 0, sizeof(result));
        result.struct_size = sizeof(result);

        NmbResultCode rc = nmb_show_message_box(&options, &result);
        if (rc != NMB_OK || result.button != cases[i].id)
        {
            fprintf(stderr, "Round-trip failed for button %u (rc=%u, button=%u)\n",
                    (unsigned int)cases[i].id, rc, (unsigned int)result.button);
            return 1;
        }

        if (result.checkbox_checked != NMB_FALSE || result.was_timeout != NMB_FALSE)
        {
            fprintf(stderr, "Unexpected state for button %u\n", (unsigned int)cases[i].id);
            return 1;
        }
    }

    return 0;
}

static int run_timeout_test(void)
{
    NmbButtonOption buttons[2];
    init_button_option(&buttons[0], NMB_BUTTON_ID_OK, "OK", NMB_TRUE, NMB_FALSE);
    init_button_option(&buttons[1], NMB_BUTTON_ID_CANCEL, "Cancel", NMB_FALSE, NMB_TRUE);

    NmbMessageBoxOptions options;
    init_options(&options, buttons, 2);
    options.timeout_milliseconds = 250;
    options.timeout_button_id = NMB_BUTTON_ID_CANCEL;

    NmbTestHarness harness;
    memset(&harness, 0, sizeof(harness));
    harness.struct_size = sizeof(harness);
    harness.magic = NMB_TEST_HARNESS_MAGIC;
    harness.scripted_button = NMB_BUTTON_ID_CANCEL;
    harness.simulate_timeout = NMB_TRUE;
    harness.result_code = NMB_OK;
    options.user_context = &harness;

    NmbMessageBoxResult result;
    memset(&result, 0, sizeof(result));
    result.struct_size = sizeof(result);

    NmbResultCode rc = nmb_show_message_box(&options, &result);
    if (rc != NMB_OK)
    {
        fprintf(stderr, "Timeout test failed: rc=%u\n", rc);
        return 1;
    }

    if (result.button != NMB_BUTTON_ID_CANCEL || result.was_timeout != NMB_TRUE)
    {
        fprintf(stderr, "Timeout test produced unexpected result (button=%u, timeout=%u)\n",
                (unsigned int)result.button, (unsigned int)result.was_timeout);
        return 1;
    }

    return 0;
}

static int run_verification_checkbox_test(void)
{
    NmbButtonOption button;
    init_button_option(&button, NMB_BUTTON_ID_OK, "OK", NMB_TRUE, NMB_FALSE);

    NmbMessageBoxOptions options;
    init_options(&options, &button, 1);
    options.show_suppress_checkbox = NMB_TRUE;
    options.verification_text_utf8 = "Do not show again";

    NmbTestHarness harness;
    memset(&harness, 0, sizeof(harness));
    harness.struct_size = sizeof(harness);
    harness.magic = NMB_TEST_HARNESS_MAGIC;
    harness.scripted_button = NMB_BUTTON_ID_OK;
    harness.checkbox_checked = NMB_TRUE;
    harness.result_code = NMB_OK;
    options.user_context = &harness;

    NmbMessageBoxResult result;
    memset(&result, 0, sizeof(result));
    result.struct_size = sizeof(result);

    NmbResultCode rc = nmb_show_message_box(&options, &result);
    if (rc != NMB_OK)
    {
        fprintf(stderr, "Verification checkbox test failed: rc=%u\n", rc);
        return 1;
    }

    if (result.button != NMB_BUTTON_ID_OK || result.checkbox_checked != NMB_TRUE)
    {
        fprintf(stderr, "Verification checkbox state incorrect (button=%u, checkbox=%u)\n",
                (unsigned int)result.button, (unsigned int)result.checkbox_checked);
        return 1;
    }

    return 0;
}

#if defined(__ANDROID__)
static int run_android_requires_activity_test(void)
{
    NmbButtonOption button;
    init_button_option(&button, NMB_BUTTON_ID_OK, "OK", NMB_TRUE, NMB_FALSE);

    NmbMessageBoxOptions options;
    init_options(&options, &button, 1);
    options.parent_window = NULL;

    NmbMessageBoxResult result;
    memset(&result, 0, sizeof(result));
    result.struct_size = sizeof(result);

    NmbResultCode rc = nmb_show_message_box(&options, &result);
    if (rc != NMB_E_INVALID_ARGUMENT)
    {
        fprintf(stderr, "Expected invalid argument when no Activity is supplied on Android (rc=%u)\n", rc);
        return 1;
    }

    return 0;
}
#endif

#if defined(__APPLE__) && (TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_MACCATALYST)
typedef struct
{
    dispatch_semaphore_t semaphore;
    int status;
} NmbIOSDispatchContext;

static void nmb_ios_background_worker(void* user_data)
{
    NmbIOSDispatchContext* context = (NmbIOSDispatchContext*)user_data;

    NmbButtonOption button;
    init_button_option(&button, NMB_BUTTON_ID_OK, "OK", NMB_TRUE, NMB_FALSE);

    NmbMessageBoxOptions options;
    init_options(&options, &button, 1);

    NmbTestHarness harness;
    memset(&harness, 0, sizeof(harness));
    harness.struct_size = sizeof(harness);
    harness.magic = NMB_TEST_HARNESS_MAGIC;
    harness.scripted_button = NMB_BUTTON_ID_OK;
    harness.result_code = NMB_OK;
    options.user_context = &harness;

    NmbMessageBoxResult result;
    memset(&result, 0, sizeof(result));
    result.struct_size = sizeof(result);

    NmbResultCode rc = nmb_show_message_box(&options, &result);
    if (rc != NMB_OK || result.button != NMB_BUTTON_ID_OK || result.was_timeout != NMB_FALSE)
    {
        fprintf(stderr, "iOS background dispatch: rc=%u button=%u timeout=%u\n",
                (unsigned int)rc, (unsigned int)result.button, (unsigned int)result.was_timeout);
        context->status = 1;
    }
    else
    {
        context->status = 0;
    }

    dispatch_semaphore_signal(context->semaphore);
}

static int run_ios_background_dispatch_test(void)
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    if (!semaphore)
    {
        fprintf(stderr, "Failed to create dispatch semaphore for iOS test\n");
        return 1;
    }

    NmbIOSDispatchContext context;
    context.semaphore = semaphore;
    context.status = 1;

    dispatch_async_f(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                     &context,
                     nmb_ios_background_worker);

    long wait_result = dispatch_semaphore_wait(semaphore,
                                               dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
    if (wait_result != 0)
    {
        fprintf(stderr, "iOS background dispatch test timed out\n");
        context.status = 1;
    }

    return context.status;
}
#endif

int main(void)
{
    if (nmb_get_abi_version() != NMB_ABI_VERSION)
    {
        fprintf(stderr, "ABI version mismatch\n");
        return 1;
    }

    NmbInitializeOptions init_opts;
    memset(&init_opts, 0, sizeof(init_opts));
    init_opts.struct_size = sizeof(init_opts);
    init_opts.abi_version = NMB_ABI_VERSION;
    init_opts.log_callback = log_sink;

    NmbResultCode rc = nmb_initialize(&init_opts);
    if (rc != NMB_OK && rc != NMB_E_PLATFORM_FAILURE)
    {
        fprintf(stderr, "nmb_initialize failed: %u\n", rc);
        return 1;
    }

    if (run_null_options_test() != 0 ||
        run_standard_button_tests() != 0 ||
        run_timeout_test() != 0 ||
        run_verification_checkbox_test() != 0)
    {
        nmb_shutdown();
        return 1;
    }

#if defined(__ANDROID__)
    if (run_android_requires_activity_test() != 0)
    {
        nmb_shutdown();
        return 1;
    }
#endif

#if defined(__APPLE__) && (TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_MACCATALYST)
    if (run_ios_background_dispatch_test() != 0)
    {
        nmb_shutdown();
        return 1;
    }
#endif

    nmb_shutdown();
    return 0;
}
