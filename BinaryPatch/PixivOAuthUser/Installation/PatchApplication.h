#ifndef PXQ_BINARY_PATCH_PIXIV_OAUTH_USER_PATCH_APPLICATION_H
#define PXQ_BINARY_PATCH_PIXIV_OAUTH_USER_PATCH_APPLICATION_H

#include <stdbool.h>

#import "PatchPlan.h"
#import "../../Core/MemoryPatch.h"


bool pxqApplyPixivOAuthUserPatchPlan(
    const PXQPatchPlan *plan,
    LHPatchMemoryFunc patchMemory
);


#endif
