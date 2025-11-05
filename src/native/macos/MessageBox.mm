#include "native_message_box.h"

#if defined(__APPLE__)

#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>

#include <string.h>
#include <cstddef>
#include <cstdint>

#include "../../shared/nmb_alloc.h"
#include "../../shared/nmb_runtime.h"
#if defined(NMB_TESTING)
#include "native_message_box_test.h"
#endif

#ifndef __has_feature
#define __has_feature(x) 0
#endif

#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 101200
#define NMB_EVENT_MASK_KEY_DOWN NSEventMaskKeyDown
#define NMB_EVENT_MODIFIER_FLAG_COMMAND NSEventModifierFlagCommand
#else
#define NMB_EVENT_MASK_KEY_DOWN NSKeyDownMask
#define NMB_EVENT_MODIFIER_FLAG_COMMAND NSCommandKeyMask
#endif

#if __has_feature(objc_arc)
#define NMB_WEAK_REF(type, name, value) __weak type name = value
#else
#define NMB_WEAK_REF(type, name, value) __unsafe_unretained type name = value
#endif

static const size_t kInitializeOptionsMinSize =
    offsetof(NmbInitializeOptions, log_user_data) + sizeof(void*);
static const size_t kMessageBoxOptionsMinSize =
    offsetof(NmbMessageBoxOptions, user_context) + sizeof(void*);
static const size_t kMessageBoxResultMinSize =
    offsetof(NmbMessageBoxResult, result_code) + sizeof(NmbResultCode);

static const NSUInteger kEscapeKeyCode = 53;
static const int64_t kNanosecondsPerMillisecond = 1000000;

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
        return NmbLogInvalid("macOS: NmbInitializeOptions.struct_size is smaller than expected.");
    }

    if (options->abi_version != NMB_ABI_VERSION)
    {
        return NmbLogInvalid("macOS: NmbInitializeOptions.abi_version mismatch.");
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
        return NmbLogInvalid("macOS: NmbMessageBoxOptions.struct_size is smaller than expected.");
    }

    if (options->abi_version != NMB_ABI_VERSION)
    {
        return NmbLogInvalid("macOS: NmbMessageBoxOptions.abi_version mismatch.");
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
        return NmbLogInvalid("macOS: NmbMessageBoxResult.struct_size is smaller than expected.");
    }

    return NMB_OK;
}

@interface NmbAlertHelper : NSObject <NSWindowDelegate>
@property (nonatomic, strong) NSView* accessoryView;
@property (nonatomic, strong) NSControl* inputControl;
@property (nonatomic, assign) NmbInputMode inputMode;
@property (nonatomic, strong) NSString* helpLink;
@property (nonatomic, assign) BOOL inputCheckboxState;
@property (nonatomic, assign) BOOL allowEscape;
@property (nonatomic, assign) BOOL requiresExplicitAck;
@property (nonatomic, strong) id escapeMonitor;
@property (nonatomic, assign) NSInteger timeoutButtonIndex;
@property (nonatomic, strong) dispatch_source_t timeoutSource;
@property (nonatomic, assign) BOOL timedOut;
@property (nonatomic, strong) NSString* secondaryInformative;
@property (nonatomic, strong) NSString* secondaryFooter;
- (void)openHelp:(id)sender;
- (NSString*)inputStringValue;
@end

@implementation NmbAlertHelper
- (void)openHelp:(id)sender
{
    if (self.helpLink.length == 0)
    {
        return;
    }

    NSURL* url = [NSURL URLWithString:self.helpLink];
    if (!url)
    {
        return;
    }

    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (NSString*)inputStringValue
{
    if (!self.inputControl)
    {
        return nil;
    }

    if (self.inputMode == NMB_INPUT_COMBO || self.inputMode == NMB_INPUT_TEXT || self.inputMode == NMB_INPUT_PASSWORD)
    {
        return [(id)self.inputControl stringValue];
    }

    return nil;
}

- (BOOL)windowShouldClose:(NSWindow*)sender
{
    return self.requiresExplicitAck ? NO : YES;
}

- (void)dealloc
{
    if (self.escapeMonitor)
    {
        [NSEvent removeMonitor:self.escapeMonitor];
        self.escapeMonitor = nil;
    }

    if (self.timeoutSource)
    {
        dispatch_source_cancel(self.timeoutSource);
        self.timeoutSource = nil;
    }
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}
@end

static NSString* Utf8String(const char* value)
{
    if (!value)
    {
        return nil;
    }

    return [NSString stringWithUTF8String:value];
}

static NmbButtonId ButtonIdAtIndex(const NmbMessageBoxOptions* options, NSInteger index)
{
    if (!options || !options->buttons || index < 0)
    {
        return NMB_BUTTON_ID_NONE;
    }

    size_t idx = static_cast<size_t>(index);
    if (idx >= options->button_count)
    {
        return NMB_BUTTON_ID_NONE;
    }

    return options->buttons[idx].id;
}

static NSInteger ButtonIndexForId(const NmbMessageBoxOptions* options, NmbButtonId buttonId)
{
    if (!options)
    {
        return -1;
    }

    if (!options->buttons || options->button_count == 0)
    {
        return (buttonId == NMB_BUTTON_ID_OK) ? 0 : -1;
    }

    for (size_t i = 0; i < options->button_count; ++i)
    {
        if (options->buttons[i].id == buttonId)
        {
            return static_cast<NSInteger>(i);
        }
    }

    return -1;
}

static NSView* BuildAccessoryView(const NmbMessageBoxOptions* options, NmbAlertHelper* helper)
{
        const bool hasSecondary = options->secondary != nullptr;
        const bool hasInput = options->input != nullptr;
        const bool hasHelperContent = (helper.secondaryInformative.length > 0) || (helper.secondaryFooter.length > 0);
        if (!hasSecondary && !hasInput && !hasHelperContent)
        {
            return nil;
        }

        NSStackView* stack = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 320, 10)];
        stack.orientation = NSUserInterfaceLayoutOrientationVertical;
        stack.alignment = NSLayoutAttributeLeading;
        stack.spacing = 8.0;

        if (helper.secondaryInformative.length > 0)
        {
            NSTextField* secondaryInfo = [NSTextField wrappingLabelWithString:helper.secondaryInformative];
            secondaryInfo.translatesAutoresizingMaskIntoConstraints = NO;
            [stack addArrangedSubview:secondaryInfo];
        }

        if (options->secondary && options->secondary->expanded_text_utf8)
        {
            NSTextField* info = [NSTextField wrappingLabelWithString:Utf8String(options->secondary->expanded_text_utf8)];
            info.translatesAutoresizingMaskIntoConstraints = NO;
            [stack addArrangedSubview:info];
        }

        if (options->input)
        {
            helper.inputMode = options->input->mode;
            switch (options->input->mode)
            {
            case NMB_INPUT_TEXT:
            case NMB_INPUT_PASSWORD:
            {
                NSTextField* field = options->input->mode == NMB_INPUT_PASSWORD
                                         ? [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 280, 24)]
                                         : [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 280, 24)];

                if (options->input->prompt_utf8)
                {
                    NSTextField* label = [NSTextField wrappingLabelWithString:Utf8String(options->input->prompt_utf8)];
                    label.translatesAutoresizingMaskIntoConstraints = NO;
                    [stack addArrangedSubview:label];
                }

                if (options->input->placeholder_utf8)
                {
                    field.placeholderString = Utf8String(options->input->placeholder_utf8);
                }

                if (options->input->default_value_utf8)
                {
                    field.stringValue = Utf8String(options->input->default_value_utf8);
                }

                field.translatesAutoresizingMaskIntoConstraints = NO;
                if (@available(macOS 10.11, *))
                {
                    [[field.heightAnchor constraintGreaterThanOrEqualToConstant:28.0] setActive:YES];
                }
                else
                {
                    NSRect frame = field.frame;
                    frame.size.height = 28.0;
                    field.frame = frame;
                }
                helper.inputControl = field;
                [stack addArrangedSubview:field];
                break;
            }
            case NMB_INPUT_COMBO:
            {
                if (options->input->prompt_utf8)
                {
                    NSTextField* label = [NSTextField wrappingLabelWithString:Utf8String(options->input->prompt_utf8)];
                    label.translatesAutoresizingMaskIntoConstraints = NO;
                    [stack addArrangedSubview:label];
                }

                NSComboBox* combo = [[NSComboBox alloc] initWithFrame:NSMakeRect(0, 0, 280, 26)];
                if (options->input->combo_items_utf8)
                {
                    const char* const* items = options->input->combo_items_utf8;
                    while (items && *items)
                    {
                        [combo addItemWithObjectValue:Utf8String(*items)];
                        ++items;
                    }
                }

                if (options->input->default_value_utf8)
                {
                    combo.stringValue = Utf8String(options->input->default_value_utf8);
                }

                helper.inputControl = combo;
                helper.inputMode = NMB_INPUT_COMBO;
                combo.translatesAutoresizingMaskIntoConstraints = NO;
                if (@available(macOS 10.11, *))
                {
                    [[combo.heightAnchor constraintGreaterThanOrEqualToConstant:28.0] setActive:YES];
                }
                else
                {
                    NSRect frame = combo.frame;
                    frame.size.height = 28.0;
                    combo.frame = frame;
                }
                [stack addArrangedSubview:combo];
                break;
            }
            case NMB_INPUT_CHECKBOX:
            {
                NSButton* checkbox = [NSButton checkboxWithTitle:(options->input->prompt_utf8 ? Utf8String(options->input->prompt_utf8) : @"")
                                                          target:nil
                                                        action:nil];
                helper.inputControl = checkbox;
                helper.inputCheckboxState = options->input->default_value_utf8 && strcmp(options->input->default_value_utf8, "true") == 0;
                checkbox.state = helper.inputCheckboxState ? NSControlStateValueOn : NSControlStateValueOff;
                checkbox.translatesAutoresizingMaskIntoConstraints = NO;
                [stack addArrangedSubview:checkbox];
                break;
            }
            default:
                break;
            }
        }

        if (helper.secondaryFooter.length > 0)
        {
            NSTextField* footerLabel = [NSTextField wrappingLabelWithString:helper.secondaryFooter];
            footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
            if ([NSColor respondsToSelector:@selector(secondaryLabelColor)])
            {
                footerLabel.textColor = [NSColor secondaryLabelColor];
            }
            footerLabel.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
            [stack addArrangedSubview:footerLabel];
        }

        if (options->secondary && options->secondary->help_link_utf8)
        {
            helper.helpLink = Utf8String(options->secondary->help_link_utf8);
            NSButton* helpButton = [NSButton buttonWithTitle:@"Open Help" target:helper action:@selector(openHelp:)];
            helpButton.translatesAutoresizingMaskIntoConstraints = NO;
            [stack addArrangedSubview:helpButton];
        }

    helper.accessoryView = stack;
    return stack;
}

static NmbResultCode CopyInputValue(const NmbMessageBoxOptions* options, NmbAlertHelper* helper, NmbMessageBoxResult* out_result)
{
        if (!helper || !helper.inputControl)
        {
            out_result->input_value_utf8 = nullptr;
            return NMB_OK;
        }

        if (helper.inputMode == NMB_INPUT_CHECKBOX)
        {
            NSButton* checkbox = (NSButton*)helper.inputControl;
            out_result->checkbox_checked = (checkbox.state == NSControlStateValueOn) ? NMB_TRUE : NMB_FALSE;
            out_result->input_value_utf8 = nullptr;
            return NMB_OK;
        }

        NSString* value = [helper inputStringValue];
        if (!value)
        {
            out_result->input_value_utf8 = nullptr;
            return NMB_OK;
        }

        const char* utf8 = [value UTF8String];
        if (!utf8)
        {
            out_result->input_value_utf8 = nullptr;
            return NMB_OK;
        }

        return nmb_copy_string_to_allocator(options->allocator, utf8, &out_result->input_value_utf8);
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

static NmbResultCode ShowAlertInternal(const NmbMessageBoxOptions* options, NmbMessageBoxResult* out_result)
{
        if (!options || !options->message_utf8 || !out_result)
        {
            nmb_runtime_log("macOS: Invalid arguments provided to nmb_show_message_box.");
            return NMB_E_INVALID_ARGUMENT;
        }

#if defined(NMB_TESTING)
        if (ApplyTestHarness(options, out_result))
        {
            return out_result->result_code;
        }
#endif

        @autoreleasepool
        {
            NSAlert* alert = [[NSAlert alloc] init];
            NmbAlertHelper* helper = [[NmbAlertHelper alloc] init];

            NSString* message = Utf8String(options->message_utf8);
            NSString* title = Utf8String(options->title_utf8);

            NSString* mainText = title ?: @"";
            NSString* detailText = message ?: @"";
            if (mainText.length == 0)
            {
                if (detailText.length > 0)
                {
                    mainText = detailText;
                    detailText = @"";
                }
                else
                {
                    mainText = @"Message";
                }
            }

            alert.messageText = mainText;
            alert.informativeText = detailText ?: @"";

            NSString* secondaryInformative = nil;
            NSString* secondaryFooter = nil;
            if (options->secondary)
            {
                if (options->secondary->informative_text_utf8)
                {
                    secondaryInformative = Utf8String(options->secondary->informative_text_utf8);
                    if (secondaryInformative.length == 0)
                    {
                        secondaryInformative = nil;
                    }
                    else if (alert.informativeText.length == 0)
                    {
                        alert.informativeText = secondaryInformative;
                        secondaryInformative = nil;
                    }
                }

                if (options->secondary->footer_text_utf8)
                {
                    secondaryFooter = Utf8String(options->secondary->footer_text_utf8);
                    if (secondaryFooter.length == 0)
                    {
                        secondaryFooter = nil;
                    }
                }
            }

            helper.secondaryInformative = secondaryInformative;
            helper.secondaryFooter = secondaryFooter;

            switch (options->icon)
            {
            case NMB_ICON_WARNING:
            case NMB_ICON_SHIELD:
                alert.alertStyle = NSAlertStyleWarning;
                break;
            case NMB_ICON_ERROR:
                alert.alertStyle = NSAlertStyleCritical;
                break;
            default:
                alert.alertStyle = NSAlertStyleInformational;
                break;
            }

            if (options->buttons && options->button_count > 0)
            {
                for (size_t i = 0; i < options->button_count; ++i)
                {
                    const char* label = options->buttons[i].label_utf8 ? options->buttons[i].label_utf8 : "OK";
                    [alert addButtonWithTitle:Utf8String(label)];
                }
            }
            else
            {
                [alert addButtonWithTitle:@"OK"];
            }

            if (options->show_suppress_checkbox == NMB_TRUE && options->verification_text_utf8)
            {
                alert.showsSuppressionButton = YES;
                alert.suppressionButton.title = Utf8String(options->verification_text_utf8);
            }

            NSView* accessory = BuildAccessoryView(options, helper);
            if (accessory)
            {
                alert.accessoryView = accessory;
            }

            helper.allowEscape = (options->allow_cancel_via_escape != NMB_FALSE);
            helper.requiresExplicitAck = (options->requires_explicit_ack == NMB_TRUE);
            if (helper.requiresExplicitAck)
            {
                helper.allowEscape = NO;
            }
            helper.timedOut = NO;
            helper.timeoutButtonIndex = -1;
            helper.timeoutSource = nil;
            helper.escapeMonitor = nil;

            NSWindow* alertWindow = alert.window;
            BOOL assignedDelegate = NO;

            if (helper.requiresExplicitAck)
            {
                alertWindow.delegate = helper;
                assignedDelegate = YES;
                NSButton* closeButton = [alertWindow standardWindowButton:NSWindowCloseButton];
                if (closeButton)
                {
                    closeButton.enabled = NO;
                }
            }

            if (!helper.allowEscape)
            {
                if (!assignedDelegate)
                {
                    alertWindow.delegate = helper;
                    assignedDelegate = YES;
                }

                NMB_WEAK_REF(NmbAlertHelper*, weakHelper, helper);
                helper.escapeMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NMB_EVENT_MASK_KEY_DOWN
                                                                              handler:^NSEvent* (NSEvent* event) {
                    NmbAlertHelper* strongHelper = weakHelper;
                    if (!strongHelper)
                    {
                        return event;
                    }

                    BOOL isEscape = (event.keyCode == kEscapeKeyCode);
                    BOOL isCommandPeriod = ((event.modifierFlags & NMB_EVENT_MODIFIER_FLAG_COMMAND) != 0) &&
                                            [[event charactersIgnoringModifiers] isEqualToString:@"."];

                    if (isEscape && !strongHelper.allowEscape)
                    {
                        return nil;
                    }

                    if (isCommandPeriod && (!strongHelper.allowEscape || strongHelper.requiresExplicitAck))
                    {
                        return nil;
                    }

                    return event;
                }];
            }

            NSWindow* parent = options->parent_window ? (__bridge NSWindow*)options->parent_window : nil;
            NSInteger response = 0;
            helper.timeoutButtonIndex = -1;

            if (options->timeout_milliseconds > 0 && options->timeout_button_id != NMB_BUTTON_ID_NONE)
            {
                NSInteger timeoutIndex = ButtonIndexForId(options, options->timeout_button_id);
                if (timeoutIndex >= 0)
                {
                    helper.timeoutButtonIndex = timeoutIndex;
                    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
                    if (timer)
                    {
                        helper.timeoutSource = timer;
                        dispatch_time_t deadline = dispatch_time(DISPATCH_TIME_NOW, static_cast<int64_t>(options->timeout_milliseconds) * kNanosecondsPerMillisecond);
                        NMB_WEAK_REF(NmbAlertHelper*, weakHelper, helper);
                        NMB_WEAK_REF(NSAlert*, weakAlert, alert);
                        dispatch_source_set_timer(timer, deadline, DISPATCH_TIME_FOREVER, 0);
                        dispatch_source_set_event_handler(timer, ^{
                            NmbAlertHelper* strongHelper = weakHelper;
                            NSAlert* strongAlert = weakAlert;
                            if (!strongHelper || !strongAlert)
                            {
                                return;
                            }

                            if (strongHelper.timeoutButtonIndex < 0)
                            {
                                return;
                            }

                            NSArray<NSButton*>* buttons = strongAlert.buttons;
                            if (strongHelper.timeoutButtonIndex >= static_cast<NSInteger>(buttons.count))
                            {
                                return;
                            }

                            strongHelper.timedOut = YES;
                            NSButton* target = buttons[strongHelper.timeoutButtonIndex];
                            if (target)
                            {
                                [target performClick:nil];
                            }

                            if (strongHelper.timeoutSource)
                            {
                                dispatch_source_cancel(strongHelper.timeoutSource);
                                strongHelper.timeoutSource = nil;
                            }
                        });
                        dispatch_resume(timer);
                    }
                }
                else
                {
                    nmb_runtime_log("macOS: Timeout button identifier not present in options; ignoring timeout.");
                }
            }

            if (parent)
            {
                __block NSInteger sheetResponse = NSModalResponseCancel;
                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                [alert beginSheetModalForWindow:parent
                                  completionHandler:^(NSModalResponse returnCode) {
                                      sheetResponse = returnCode;
                                      dispatch_semaphore_signal(semaphore);
                                  }];
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                response = sheetResponse;
            }
            else
            {
                response = [alert runModal];
            }

            if (helper.timeoutSource)
            {
                dispatch_source_cancel(helper.timeoutSource);
                helper.timeoutSource = nil;
            }

            if (helper.escapeMonitor)
            {
                [NSEvent removeMonitor:helper.escapeMonitor];
                helper.escapeMonitor = nil;
            }

            if (assignedDelegate && alertWindow)
            {
                alertWindow.delegate = nil;
            }

            NSInteger base = NSAlertFirstButtonReturn;
#ifdef NSModalResponseFirst
            if (response >= NSModalResponseFirst && response < NSModalResponseFirst + static_cast<NSInteger>(options->button_count))
            {
                base = NSModalResponseFirst;
            }
#endif

            NSInteger index = response - base;
            if (!options->buttons || options->button_count == 0)
            {
                out_result->button = NMB_BUTTON_ID_OK;
            }
            else
            {
                out_result->button = ButtonIdAtIndex(options, index);
            }

            if (options->show_suppress_checkbox == NMB_TRUE)
            {
                out_result->checkbox_checked = (alert.suppressionButton.state == NSControlStateValueOn) ? NMB_TRUE : NMB_FALSE;
            }

            NmbResultCode rc = CopyInputValue(options, helper, out_result);
            if (rc != NMB_OK)
            {
                out_result->result_code = rc;
                return rc;
            }

#if defined(NMB_TESTING)
            if (ApplyTestHarness(options, out_result))
            {
                return out_result->result_code;
            }
#endif

            out_result->was_timeout = helper.timedOut ? NMB_TRUE : NMB_FALSE;
            out_result->result_code = NMB_OK;
            return NMB_OK;
        }
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

        if (![NSThread isMainThread])
        {
            dispatch_sync(dispatch_get_main_queue(), ^{
              if (NSApp == nil)
              {
                  [NSApplication sharedApplication];
              }
            });
        }
        else if (NSApp == nil)
        {
            [NSApplication sharedApplication];
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

    if (![NSThread isMainThread])
    {
        __block NmbResultCode code = NMB_OK;
        dispatch_sync(dispatch_get_main_queue(), ^{
          code = ShowAlertInternal(options, out_result);
        });
        return code;
    }

    return ShowAlertInternal(options, out_result);
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

#endif // __APPLE__
