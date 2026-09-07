#import "pxQoLMemoryPatch.h"

#import <dlfcn.h>


LHPatchMemoryFunc pxQoLGetPatchMemory(void)
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