#ifndef pxQoLMemoryPatch_h
#define pxQoLMemoryPatch_h

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

LHPatchMemoryFunc pxQoLGetPatchMemory(void);

#endif