#ifndef PXQ_BINARY_PATCH_PIXIV_OAUTH_USER_PATCH_PLAN_H
#define PXQ_BINARY_PATCH_PIXIV_OAUTH_USER_PATCH_PLAN_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#import "../Contract/InterceptionContract.h"


#define PXQ_PIXIV_OAUTH_USER_MAX_PATCH_OPERATIONS \
    (PXQ_PIXIV_OAUTH_USER_MAX_ASSIGNMENT_CALL_SITES + \
     PXQ_PIXIV_OAUTH_USER_MAX_ASSIGNMENT_RETURN_SITES)


typedef struct {
    uintptr_t targetAddress;
    uint32_t replacementInstruction;

} PXQPatchOperation;


typedef struct {
    PXQPatchOperation operations[
        PXQ_PIXIV_OAUTH_USER_MAX_PATCH_OPERATIONS
    ];

    size_t operationCount;

} PXQPatchPlan;


bool pxqBuildPixivOAuthUserPatchPlan(
    const PXQPixivOAuthUserInterceptionContract *contract,
    PXQPatchPlan *plan
);


#endif
