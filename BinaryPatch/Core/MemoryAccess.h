#ifndef PXQ_BINARY_PATCH_MEMORY_ACCESS_H
#define PXQ_BINARY_PATCH_MEMORY_ACCESS_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

bool pxqMemoryRead(
    uintptr_t address,
    void *buffer,
    size_t size
);

bool pxqMemoryReadU32(
    uintptr_t address,
    uint32_t *value
);

bool pxqMemoryReadU64(
    uintptr_t address,
    uint64_t *value
);

bool pxqMemoryReadCString(
    uintptr_t address,
    char *buffer,
    size_t capacity
);

bool pxqAddressAddSignedOffset(
    uintptr_t base,
    int64_t offset,
    uintptr_t *result
);

bool pxqAddressResolveRelative32(
    uintptr_t base,
    int32_t relativeOffset,
    uintptr_t *result
);

bool pxqAddressRangeContains(
    uintptr_t rangeStart,
    size_t rangeSize,
    uintptr_t address,
    size_t size
);

#endif
