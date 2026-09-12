#ifndef PXQ_BINARY_PATCH_MEMORY_PATCH_H
#define PXQ_BINARY_PATCH_MEMORY_PATCH_H

#include <stddef.h>

struct LHMemoryPatch {
    void *destination;
    const void *data;
    size_t size;
    void *options;
};

typedef int (*LHPatchMemoryFunc)(
    const struct LHMemoryPatch *patches,
    int count
);

LHPatchMemoryFunc pxqMemoryPatchResolveBackend(void);

#endif
