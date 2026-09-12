#import "MemoryPatch.h"

#import <dlfcn.h>

LHPatchMemoryFunc pxqMemoryPatchResolveBackend(void)
{
    void *symbol =
        dlsym(
            RTLD_DEFAULT,
            "LHPatchMemory"
        );

    if (!symbol)
        return NULL;

    return (LHPatchMemoryFunc)symbol;
}
