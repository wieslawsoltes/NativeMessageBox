#pragma once

#include "native_message_box.h"

#ifdef __cplusplus
extern "C" {
#endif

void nmb_runtime_set_log_callback(void (*log_callback)(void*, const char*), void* user_data);
void nmb_runtime_log(const char* message);
void nmb_runtime_reset_log(void);

#ifdef __cplusplus
}
#endif

