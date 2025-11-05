#ifndef NATIVE_MESSAGE_BOX_TEST_H
#define NATIVE_MESSAGE_BOX_TEST_H

#include "native_message_box.h"

#define NMB_TEST_HARNESS_MAGIC 0x4E4D4254u /* 'NMBT' */

typedef struct NmbTestHarness_t
{
    uint32_t struct_size;
    uint32_t magic;
    NmbButtonId scripted_button;
    nmb_bool checkbox_checked;
    nmb_bool simulate_timeout;
    NmbResultCode result_code;
    const char* input_value_utf8;
} NmbTestHarness;

#endif /* NATIVE_MESSAGE_BOX_TEST_H */
