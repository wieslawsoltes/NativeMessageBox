#include "nmb_runtime.h"

#include <stddef.h>

static void (*s_log_callback)(void*, const char*) = NULL;
static void* s_log_user_data = NULL;

void nmb_runtime_set_log_callback(void (*log_callback)(void*, const char*), void* user_data)
{
    s_log_callback = log_callback;
    s_log_user_data = user_data;
}

void nmb_runtime_log(const char* message)
{
    if (s_log_callback && message)
    {
        s_log_callback(s_log_user_data, message);
    }
}

void nmb_runtime_reset_log(void)
{
    s_log_callback = NULL;
    s_log_user_data = NULL;
}

