#ifndef NATIVE_MESSAGE_BOX_H
#define NATIVE_MESSAGE_BOX_H

/**
 * @file native_message_box.h
 * @brief Cross-platform C ABI for native message boxes on Windows, macOS, and Linux.
 *
 * Strings are UTF-8 encoded. Callers are expected to pin the memory for the duration
 * of the API call. Any output strings returned by the runtime must be released with
 * the provided deallocation callback (see NmbAllocator).
 */

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
  #if defined(NMB_SHARED)
    #if defined(NMB_IMPLEMENTATION)
      #define NMB_API __declspec(dllexport)
    #else
      #define NMB_API __declspec(dllimport)
    #endif
  #else
    #define NMB_API
  #endif
  #define NMB_CALL __stdcall
#else
  #if defined(NMB_SHARED) && defined(NMB_IMPLEMENTATION)
    #define NMB_API __attribute__((visibility("default")))
  #else
    #define NMB_API
  #endif
  #define NMB_CALL
#endif

typedef uint8_t nmb_bool;
#define NMB_FALSE ((nmb_bool)0)
#define NMB_TRUE ((nmb_bool)1)

typedef uint32_t nmb_result;

/** API version encoded as MAJOR << 16 | MINOR << 8 | PATCH. */
#define NMB_MAKE_VERSION(major, minor, patch) ((((major) & 0xFFu) << 16) | (((minor) & 0xFFu) << 8) | ((patch) & 0xFFu))

/* Current ABI version. Increment MAJOR for breaking changes, MINOR for additive, PATCH for fixes. */
#define NMB_ABI_VERSION NMB_MAKE_VERSION(0, 1, 0)

typedef struct NmbAllocator_t
{
    void* (*allocate)(void* user_data, size_t size, size_t alignment);
    void (*deallocate)(void* user_data, void* ptr);
    void* user_data;
} NmbAllocator;

typedef enum NmbResultCode_t
{
    NMB_OK = 0,
    NMB_E_INVALID_ARGUMENT = 1,
    NMB_E_UNINITIALIZED = 2,
    NMB_E_NOT_SUPPORTED = 3,
    NMB_E_PLATFORM_FAILURE = 4,
    NMB_E_CANCELLED = 5,
    NMB_E_OUT_OF_MEMORY = 6,
    NMB_E_UNKNOWN = 0xFFFFFFFFu
} NmbResultCode;

typedef enum NmbButtonKind_t
{
    NMB_BUTTON_KIND_DEFAULT = 0,
    NMB_BUTTON_KIND_PRIMARY = 1,
    NMB_BUTTON_KIND_SECONDARY = 2,
    NMB_BUTTON_KIND_DESTRUCTIVE = 3,
    NMB_BUTTON_KIND_HELP = 4
} NmbButtonKind;

typedef enum NmbIcon_t
{
    NMB_ICON_NONE = 0,
    NMB_ICON_INFORMATION = 1,
    NMB_ICON_WARNING = 2,
    NMB_ICON_ERROR = 3,
    NMB_ICON_QUESTION = 4,
    NMB_ICON_SHIELD = 5
} NmbIcon;

typedef enum NmbSeverity_t
{
    NMB_SEVERITY_INFO = 0,
    NMB_SEVERITY_WARNING = 1,
    NMB_SEVERITY_ERROR = 2,
    NMB_SEVERITY_CRITICAL = 3
} NmbSeverity;

typedef enum NmbDialogModality_t
{
    NMB_MODALITY_APP = 0,
    NMB_MODALITY_WINDOW = 1,
    NMB_MODALITY_SYSTEM = 2
} NmbDialogModality;

typedef enum NmbInputMode_t
{
    NMB_INPUT_NONE = 0,
    NMB_INPUT_CHECKBOX = 1,
    NMB_INPUT_TEXT = 2,
    NMB_INPUT_PASSWORD = 3,
    NMB_INPUT_COMBO = 4
} NmbInputMode;

typedef enum NmbButtonId_t
{
    NMB_BUTTON_ID_NONE = 0,
    NMB_BUTTON_ID_OK = 1,
    NMB_BUTTON_ID_CANCEL = 2,
    NMB_BUTTON_ID_YES = 3,
    NMB_BUTTON_ID_NO = 4,
    NMB_BUTTON_ID_RETRY = 5,
    NMB_BUTTON_ID_CONTINUE = 6,
    NMB_BUTTON_ID_IGNORE = 7,
    NMB_BUTTON_ID_ABORT = 8,
    NMB_BUTTON_ID_CLOSE = 9,
    NMB_BUTTON_ID_HELP = 10,
    NMB_BUTTON_ID_TRY_AGAIN = 11,
    NMB_BUTTON_ID_CUSTOM_BASE = 1000
} NmbButtonId;

typedef struct NmbButtonOption_t
{
    uint32_t struct_size;       /**< Must be set to sizeof(NmbButtonOption). */
    NmbButtonId id;             /**< Identifier returned in result. */
    const char* label_utf8;     /**< Display text; required. */
    const char* description_utf8; /**< Optional accessible description. */
    NmbButtonKind kind;         /**< Visual style hint. */
    nmb_bool is_default;        /**< Marks default button. */
    nmb_bool is_cancel;         /**< Marks cancel button. */
} NmbButtonOption;

typedef struct NmbInputOption_t
{
    uint32_t struct_size;         /**< Must be set to sizeof(NmbInputOption). */
    NmbInputMode mode;            /**< Input control type. */
    const char* prompt_utf8;      /**< Label for the input. */
    const char* placeholder_utf8; /**< Placeholder text for text input. */
    const char* default_value_utf8; /**< Initial value (for text/combo). */
    const char* const* combo_items_utf8; /**< Array of strings (NULL-terminated) when mode == NMB_INPUT_COMBO. */
} NmbInputOption;

typedef struct NmbSecondaryContentOption_t
{
    uint32_t struct_size;
    const char* informative_text_utf8; /**< Secondary text (smaller font). */
    const char* expanded_text_utf8;    /**< Text shown when expanded section opened. */
    const char* footer_text_utf8;      /**< Footer message / help link. */
    const char* help_link_utf8;        /**< Optional URL to open when user requests help. */
} NmbSecondaryContentOption;

typedef struct NmbMessageBoxOptions_t
{
    uint32_t struct_size;               /**< Must be set to sizeof(NmbMessageBoxOptions). */
    uint32_t abi_version;               /**< Must be set to NMB_ABI_VERSION. */
    const char* title_utf8;             /**< Dialog title; optional (platform default if NULL). */
    const char* message_utf8;           /**< Main message body; required. */
    const NmbButtonOption* buttons;     /**< Pointer to array of button definitions. */
    size_t button_count;                /**< Number of entries in buttons array. */
    NmbIcon icon;                       /**< Icon hint. */
    NmbSeverity severity;               /**< Severity mapping for accessibility. */
    NmbDialogModality modality;         /**< Modal behavior. */
    const void* parent_window;          /**< Opaque platform window handle (e.g., HWND*, NSWindow*, GtkWindow*). */
    const NmbInputOption* input;        /**< Optional pointer to input configuration. */
    const NmbSecondaryContentOption* secondary; /**< Optional pointer for additional content. */
    const char* verification_text_utf8; /**< Text for "Do not show again" checkbox; NULL to skip. */
    nmb_bool allow_cancel_via_escape;   /**< Allow ESC key cancellation. */
    nmb_bool show_suppress_checkbox;    /**< Show the verification checkbox. */
    nmb_bool requires_explicit_ack;     /**< Force explicit button click (no close). */
    uint32_t timeout_milliseconds;      /**< Auto-close timeout (0 = disabled). */
    NmbButtonId timeout_button_id;      /**< Button id to return if timeout occurs. */
    const char* locale_utf8;            /**< Preferred locale (e.g., "en-US"); optional. */
    const NmbAllocator* allocator;      /**< Custom allocator for any runtime allocations; optional. */
    void* user_context;                 /**< User data forwarded to callbacks (future use). */
} NmbMessageBoxOptions;

typedef struct NmbMessageBoxResult_t
{
    uint32_t struct_size;           /**< Must be set to sizeof(NmbMessageBoxResult) by caller. */
    NmbButtonId button;             /**< Selected button. */
    nmb_bool checkbox_checked;      /**< State of verification checkbox. */
    const char* input_value_utf8;   /**< Allocated string capturing user input (caller must free via allocator). */
    nmb_bool was_timeout;           /**< Indicates timeout path taken. */
    NmbResultCode result_code;      /**< Overall operation status. */
} NmbMessageBoxResult;

typedef struct NmbInitializeOptions_t
{
    uint32_t struct_size;             /**< Must be set to sizeof(NmbInitializeOptions). */
    uint32_t abi_version;             /**< Must be set to NMB_ABI_VERSION. */
    const char* runtime_name_utf8;    /**< Optional string for telemetry/logging. */
    const NmbAllocator* allocator;    /**< Global allocator override; optional. */
    nmb_bool enable_async_dispatch;   /**< Request runtime-managed dispatch queue (platform dependent). */
    void (*log_callback)(void* user_data, const char* message_utf8);
    void* log_user_data;
} NmbInitializeOptions;

/**
 * Initializes the native runtime. Optional; some platforms lazily initialize on first call.
 */
NMB_API NmbResultCode NMB_CALL nmb_initialize(const NmbInitializeOptions* options);

/**
 * Displays a message box using the provided options and writes the result to out_result.
 * When options->allocator is null, the runtime uses default allocation semantics.
 */
NMB_API NmbResultCode NMB_CALL nmb_show_message_box(const NmbMessageBoxOptions* options, NmbMessageBoxResult* out_result);

/**
 * Releases any resources held by the runtime.
 */
NMB_API void NMB_CALL nmb_shutdown(void);

/**
 * Returns the ABI version implemented by the native library.
 */
NMB_API uint32_t NMB_CALL nmb_get_abi_version(void);

/**
 * Updates the logging callback without reinitializing the runtime.
 */
NMB_API void NMB_CALL nmb_set_log_callback(void (*log_callback)(void*, const char*), void* user_data);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* NATIVE_MESSAGE_BOX_H */
