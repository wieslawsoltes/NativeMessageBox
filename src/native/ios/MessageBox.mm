#include "native_message_box.h"

#if defined(__APPLE__)

#import <TargetConditionals.h>

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_MACCATALYST

#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>
#import <CoreFoundation/CoreFoundation.h>

#include <cstddef>
#include <cstdint>

#include "../../shared/nmb_alloc.h"
#include "../../shared/nmb_runtime.h"
#if defined(NMB_TESTING)
#include "native_message_box_test.h"
#endif

static const size_t kInitializeOptionsMinSize =
    offsetof(NmbInitializeOptions, log_user_data) + sizeof(void*);
static const size_t kMessageBoxOptionsMinSize =
    offsetof(NmbMessageBoxOptions, user_context) + sizeof(void*);
static const size_t kMessageBoxResultMinSize =
    offsetof(NmbMessageBoxResult, result_code) + sizeof(NmbResultCode);

static const uint64_t kNanosecondsPerMillisecond = 1000000ull;

static NmbResultCode NmbLogInvalid(const char* message)
{
    nmb_runtime_log(message);
    return NMB_E_INVALID_ARGUMENT;
}

static NmbResultCode NmbValidateInitializeOptions(const NmbInitializeOptions* options)
{
    if (!options)
    {
        return NMB_OK;
    }

    if (options->struct_size < kInitializeOptionsMinSize)
    {
        return NmbLogInvalid("iOS: NmbInitializeOptions.struct_size is smaller than expected.");
    }

    if (options->abi_version != NMB_ABI_VERSION)
    {
        return NmbLogInvalid("iOS: NmbInitializeOptions.abi_version mismatch.");
    }

    return NMB_OK;
}

static NmbResultCode NmbValidateMessageBoxOptions(const NmbMessageBoxOptions* options)
{
    if (!options)
    {
        return NMB_E_INVALID_ARGUMENT;
    }

    if (options->struct_size < kMessageBoxOptionsMinSize)
    {
        return NmbLogInvalid("iOS: NmbMessageBoxOptions.struct_size is smaller than expected.");
    }

    if (options->abi_version != NMB_ABI_VERSION)
    {
        return NmbLogInvalid("iOS: NmbMessageBoxOptions.abi_version mismatch.");
    }

    if (!options->message_utf8)
    {
        return NmbLogInvalid("iOS: message_utf8 is required.");
    }

    return NMB_OK;
}

static NmbResultCode NmbValidateMessageBoxResult(const NmbMessageBoxResult* result)
{
    if (!result)
    {
        return NMB_E_INVALID_ARGUMENT;
    }

    if (result->struct_size < kMessageBoxResultMinSize)
    {
        return NmbLogInvalid("iOS: NmbMessageBoxResult.struct_size is smaller than expected.");
    }

    return NMB_OK;
}

static NSString* NmbStringFromUtf8(const char* value)
{
    if (!value)
    {
        return nil;
    }

    return [NSString stringWithUTF8String:value];
}

static UIViewController* ResolvePresenter(const NmbMessageBoxOptions* options)
{
    if (options && options->parent_window)
    {
        return (__bridge UIViewController*)options->parent_window;
    }

    if (![NSThread isMainThread])
    {
        return nil;
    }

    UIApplication* application = [UIApplication sharedApplication];
    if (!application)
    {
        return nil;
    }

    UIViewController* candidate = nil;

    if (@available(iOS 13.0, *))
    {
        for (UIScene* scene in application.connectedScenes)
        {
            if (scene.activationState != UISceneActivationStateForegroundActive)
            {
                continue;
            }

            if (![scene isKindOfClass:[UIWindowScene class]])
            {
                continue;
            }

            UIWindowScene* windowScene = (UIWindowScene*)scene;
            for (UIWindow* window in windowScene.windows)
            {
                if (window.hidden || window.alpha <= 0.0 || !window.rootViewController)
                {
                    continue;
                }

                candidate = window.rootViewController;
                if (window.isKeyWindow)
                {
                    break;
                }
            }

            if (candidate)
            {
                break;
            }
        }
    }
    else
    {
        UIWindow* window = application.keyWindow;
        candidate = window.rootViewController;
    }

    while (candidate && candidate.presentedViewController)
    {
        candidate = candidate.presentedViewController;
    }

    return candidate;
}

#if defined(NMB_TESTING)
static bool ApplyTestHarness(const NmbMessageBoxOptions* options, NmbMessageBoxResult* out_result)
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

typedef struct NmbIOSWaitContext_t
{
    dispatch_semaphore_t semaphore;
    CFRunLoopRef run_loop;
    bool uses_semaphore;
    bool completed;
} NmbIOSWaitContext;

static void FinishWait(NmbIOSWaitContext* context)
{
    if (!context)
    {
        return;
    }

    context->completed = true;
    if (context->uses_semaphore && context->semaphore)
    {
        dispatch_semaphore_signal(context->semaphore);
    }
    else if (context->run_loop)
    {
        CFRunLoopStop(context->run_loop);
    }
}

static UIAlertActionStyle ActionStyleForButton(const NmbButtonOption* button, bool* out_is_cancel, bool* out_is_default)
{
    if (out_is_cancel)
    {
        *out_is_cancel = (button && button->is_cancel == NMB_TRUE);
    }

    if (out_is_default)
    {
        *out_is_default = (button && button->is_default == NMB_TRUE);
    }

    if (!button)
    {
        return UIAlertActionStyleDefault;
    }

    if (button->is_cancel == NMB_TRUE)
    {
        return UIAlertActionStyleCancel;
    }

    if (button->kind == NMB_BUTTON_KIND_DESTRUCTIVE)
    {
        return UIAlertActionStyleDestructive;
    }

    return UIAlertActionStyleDefault;
}

static void LogUnsupportedFeatures(const NmbMessageBoxOptions* options)
{
    if (!options)
    {
        return;
    }

    if (options->secondary && (options->secondary->informative_text_utf8 || options->secondary->expanded_text_utf8 ||
                               options->secondary->footer_text_utf8 || options->secondary->help_link_utf8))
    {
        nmb_runtime_log("iOS: Secondary content is not supported and will be ignored.");
    }

    if (options->verification_text_utf8 || options->show_suppress_checkbox == NMB_TRUE)
    {
        nmb_runtime_log("iOS: Verification checkboxes are not supported and will be ignored.");
    }

    if (options->input)
    {
        switch (options->input->mode)
        {
        case NMB_INPUT_TEXT:
        case NMB_INPUT_PASSWORD:
            break;
        default:
            nmb_runtime_log("iOS: Only text and password input modes are supported.");
            break;
        }
    }

    if (options->icon != NMB_ICON_NONE)
    {
        nmb_runtime_log("iOS: Icon hints are not currently supported.");
    }
}

static void PopulateInputResult(const NmbMessageBoxOptions* options,
                                UIAlertController* alert,
                                NmbMessageBoxResult* out_result,
                                NmbResultCode* out_code)
{
    if (!options || !alert || !out_result || !out_code)
    {
        return;
    }

    out_result->checkbox_checked = NMB_FALSE;

    if (!options->input || alert.textFields.count == 0)
    {
        out_result->input_value_utf8 = nullptr;
        return;
    }

    UITextField* textField = alert.textFields.firstObject;
    NSString* value = textField.text ?: @"";
    const char* utf8 = [value UTF8String];

    if (!utf8)
    {
        out_result->input_value_utf8 = nullptr;
        return;
    }

    NmbResultCode rc = nmb_copy_string_to_allocator(options->allocator, utf8, &out_result->input_value_utf8);
    if (rc != NMB_OK)
    {
        out_result->result_code = rc;
        *out_code = rc;
    }
}

static void ConfigureInput(const NmbMessageBoxOptions* options, UIAlertController* alert)
{
    if (!options || !options->input || !alert)
    {
        return;
    }

    const NmbInputOption* input = options->input;
    if (input->mode != NMB_INPUT_TEXT && input->mode != NMB_INPUT_PASSWORD)
    {
        return;
    }

    [alert addTextField:^(UITextField* textField) {
      textField.placeholder = NmbStringFromUtf8(input->placeholder_utf8);
      textField.secureTextEntry = (input->mode == NMB_INPUT_PASSWORD);
      NSString* defaultValue = NmbStringFromUtf8(input->default_value_utf8);
      if (defaultValue)
      {
          textField.text = defaultValue;
      }
      if (input->prompt_utf8)
      {
          textField.accessibilityLabel = NmbStringFromUtf8(input->prompt_utf8);
      }
    }];
}

static NmbResultCode PresentAlert(const NmbMessageBoxOptions* options,
                                  NmbMessageBoxResult* out_result,
                                  NmbIOSWaitContext* wait_context)
{
    if (!options || !out_result || !wait_context)
    {
        return NMB_E_INVALID_ARGUMENT;
    }

#if defined(NMB_TESTING)
    if (ApplyTestHarness(options, out_result))
    {
        FinishWait(wait_context);
        return out_result->result_code;
    }
#endif

    UIViewController* presenter = ResolvePresenter(options);
    if (!presenter)
    {
        nmb_runtime_log("iOS: Unable to resolve a presenter UIViewController.");
        out_result->button = NMB_BUTTON_ID_NONE;
        out_result->input_value_utf8 = nullptr;
        out_result->checkbox_checked = NMB_FALSE;
        out_result->was_timeout = NMB_FALSE;
        out_result->result_code = NMB_E_PLATFORM_FAILURE;
        FinishWait(wait_context);
        return NMB_E_PLATFORM_FAILURE;
    }

    NSString* title = NmbStringFromUtf8(options->title_utf8);
    NSString* message = NmbStringFromUtf8(options->message_utf8);
    UIAlertController* alert =
        [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];

    ConfigureInput(options, alert);
    LogUnsupportedFeatures(options);

    const bool hasButtons = options->buttons && options->button_count > 0;
    const size_t buttonCount = hasButtons ? options->button_count : 1;
    const bool hasTimeoutButton = (options->timeout_button_id != NMB_BUTTON_ID_NONE);
    bool timeoutButtonMatched = false;

    __block BOOL completed = NO;
    __block NmbResultCode completionCode = NMB_OK;

    void (^complete)(NmbButtonId, BOOL) = ^(NmbButtonId buttonId, BOOL timedOut) {
      if (completed)
      {
          return;
      }
      completed = YES;

      out_result->button = buttonId;
      out_result->was_timeout = timedOut ? NMB_TRUE : NMB_FALSE;
      out_result->result_code = NMB_OK;
      completionCode = NMB_OK;

      PopulateInputResult(options, alert, out_result, &completionCode);

      if (completionCode != NMB_OK)
      {
          FinishWait(wait_context);
          return;
      }

      if (buttonId == NMB_BUTTON_ID_NONE && !timedOut)
      {
          out_result->result_code = NMB_E_CANCELLED;
          completionCode = NMB_E_CANCELLED;
      }

      FinishWait(wait_context);
    };

    bool seenCancelAction = false;
    bool assignedPreferredAction = false;

    for (size_t i = 0; i < buttonCount; ++i)
    {
        NmbButtonOption fallbackButton{};
        fallbackButton.struct_size = sizeof(fallbackButton);
        fallbackButton.id = NMB_BUTTON_ID_OK;
        fallbackButton.label_utf8 = "OK";
        fallbackButton.is_default = NMB_TRUE;

        const NmbButtonOption* sourceButton = hasButtons ? (options->buttons + i) : &fallbackButton;
        NSString* label = NmbStringFromUtf8(sourceButton->label_utf8);
        if (!label || label.length == 0)
        {
            label = @"";
        }

        if (hasTimeoutButton && sourceButton->id == options->timeout_button_id)
        {
            timeoutButtonMatched = true;
        }

        bool isCancel = false;
        bool isDefault = false;
        UIAlertActionStyle style = ActionStyleForButton(sourceButton, &isCancel, &isDefault);
        if (isCancel)
        {
            if (seenCancelAction)
            {
                nmb_runtime_log("iOS: Multiple cancel buttons requested; subsequent cancel buttons will be treated as default style.");
                style = UIAlertActionStyleDefault;
                isCancel = false;
            }
            else
            {
                seenCancelAction = true;
            }
        }

        NmbButtonId buttonId = sourceButton->id;
        UIAlertAction* action = [UIAlertAction actionWithTitle:label
                                                         style:style
                                                       handler:^(UIAlertAction*) {
                                                         complete(buttonId, NO);
                                                       }];

        [alert addAction:action];

        if (isDefault && !assignedPreferredAction && style != UIAlertActionStyleCancel)
        {
            alert.preferredAction = action;
            assignedPreferredAction = true;
        }
    }

    [presenter presentViewController:alert animated:YES completion:nil];

    if (options->timeout_milliseconds > 0 && hasTimeoutButton)
    {
        if (timeoutButtonMatched)
        {
            uint64_t delay = options->timeout_milliseconds * kNanosecondsPerMillisecond;
            NmbButtonId timeoutId = options->timeout_button_id;

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)delay), dispatch_get_main_queue(), ^{
              if (completed)
              {
                  return;
              }

              [alert dismissViewControllerAnimated:YES
                                         completion:^{
                                           complete(timeoutId, YES);
                                         }];
            });
        }
        else
        {
            nmb_runtime_log("iOS: Timeout button id did not match any configured button; timeout disabled.");
        }
    }

    return completionCode;
}

extern "C"
{

NMB_API NmbResultCode NMB_CALL nmb_initialize(const NmbInitializeOptions* options)
{
    NmbResultCode validation = NmbValidateInitializeOptions(options);
    if (validation != NMB_OK)
    {
        return validation;
    }

    @autoreleasepool
    {
        if (options)
        {
            nmb_runtime_set_log_callback(options->log_callback, options->log_user_data);
        }
        else
        {
            nmb_runtime_set_log_callback(NULL, NULL);
        }
    }

    return NMB_OK;
}

NMB_API NmbResultCode NMB_CALL nmb_show_message_box(const NmbMessageBoxOptions* options, NmbMessageBoxResult* out_result)
{
    if (!options || !out_result)
    {
        return NMB_E_INVALID_ARGUMENT;
    }

    NmbResultCode validation = NmbValidateMessageBoxOptions(options);
    if (validation != NMB_OK)
    {
        return validation;
    }

    validation = NmbValidateMessageBoxResult(out_result);
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

    NmbIOSWaitContext wait_context{};
    wait_context.completed = false;

    if ([NSThread isMainThread])
    {
        wait_context.run_loop = CFRunLoopGetCurrent();
        wait_context.uses_semaphore = false;

        PresentAlert(options, out_result, &wait_context);

        while (!wait_context.completed)
        {
            @autoreleasepool
            {
                CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, true);
            }
        }
    }
    else
    {
        wait_context.semaphore = dispatch_semaphore_create(0);
        wait_context.uses_semaphore = true;

        dispatch_async(dispatch_get_main_queue(), ^{
          @autoreleasepool
          {
              PresentAlert(options, out_result, const_cast<NmbIOSWaitContext*>(&wait_context));
          }
        });

        dispatch_semaphore_wait(wait_context.semaphore, DISPATCH_TIME_FOREVER);
    }

    return out_result->result_code;
}

NMB_API void NMB_CALL nmb_shutdown(void)
{
    @autoreleasepool
    {
        nmb_runtime_reset_log();
    }
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

#endif // TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_MACCATALYST

#endif // defined(__APPLE__)
