#pragma once

#include "native_message_box.h"

#include <stddef.h>
#include <string.h>

#if defined(_WIN32)
#  include <windows.h>
#else
#  include <stdlib.h>
#endif

static inline void* nmb_default_alloc(size_t size)
{
    if (size == 0)
    {
        return NULL;
    }

#if defined(_WIN32)
    return CoTaskMemAlloc(size);
#else
    return malloc(size);
#endif
}

static inline void nmb_default_free(void* ptr)
{
    if (!ptr)
    {
        return;
    }

#if defined(_WIN32)
    CoTaskMemFree(ptr);
#else
    free(ptr);
#endif
}

static inline void* nmb_allocate(const NmbAllocator* allocator, size_t size, size_t alignment)
{
    if (allocator && allocator->allocate)
    {
        return allocator->allocate(allocator->user_data, size, alignment);
    }

    (void)alignment;
    return nmb_default_alloc(size);
}

static inline void nmb_deallocate(const NmbAllocator* allocator, void* ptr)
{
    if (!ptr)
    {
        return;
    }

    if (allocator && allocator->deallocate)
    {
        allocator->deallocate(allocator->user_data, ptr);
        return;
    }

    nmb_default_free(ptr);
}

static inline NmbResultCode nmb_copy_string_to_allocator(const NmbAllocator* allocator, const char* source, const char** target)
{
    if (!target)
    {
        return NMB_E_INVALID_ARGUMENT;
    }

    if (!source)
    {
        *target = NULL;
        return NMB_OK;
    }

    size_t len = strlen(source) + 1;
    char* buffer = (char*)nmb_allocate(allocator, len, sizeof(char));
    if (!buffer)
    {
        return NMB_E_OUT_OF_MEMORY;
    }

    memcpy(buffer, source, len);
    *target = buffer;
    return NMB_OK;
}
