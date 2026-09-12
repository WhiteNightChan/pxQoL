#import "PatchApplication.h"

#import "../../Core/MemoryAccess.h"
#import "../../../LogHelper.h"

#include <stddef.h>
#include <stdint.h>


bool pxqApplyPixivOAuthUserPatchPlan(
    const PXQPatchPlan *plan,
    LHPatchMemoryFunc patchMemory
)
{
    if (!plan ||
        !patchMemory ||
        plan->operationCount == 0 ||
        plan->operationCount >
            PXQ_PIXIV_OAUTH_USER_MAX_PATCH_OPERATIONS) {

        return false;
    }


    struct LHMemoryPatch patches[
        PXQ_PIXIV_OAUTH_USER_MAX_PATCH_OPERATIONS
    ];


    for (size_t i = 0;
         i < plan->operationCount;
         i++) {

        const PXQPatchOperation *operation =
            &plan->operations[i];

        patches[i] =
            (struct LHMemoryPatch) {
                .destination =
                    (void *)operation->targetAddress,
                .data =
                    &operation->replacementInstruction,
                .size =
                    sizeof(operation->replacementInstruction),
                .options =
                    NULL
            };
    }


    const int patchCount =
        (int)plan->operationCount;


    pxQoLLog(
        @"[PixivOAuthUser/PatchApplication] applying %d patches in one batch",
        patchCount
    );


    const int patchResult =
        patchMemory(
            patches,
            patchCount
        );


    /*
     * Preserve the raw LHPatchMemory result only as diagnostic data.
     * Authoritative success remains direct read-back equality for
     * every planned replacement instruction.
     */
    pxQoLLog(
        @"[PixivOAuthUser/PatchApplication] LHPatchMemory result=%d count=%d",
        patchResult,
        patchCount
    );


    for (int i = 0;
         i < patchCount;
         i++) {

        if (patches[i].size !=
            sizeof(uint32_t)) {

            pxQoLLog(
                @"[PixivOAuthUser/PatchApplication] FAIL [8] unexpected patch size at index=%d size=%zu",
                i,
                patches[i].size
            );

            return false;
        }


        uint32_t actualInstruction =
            0;

        if (!pxqMemoryReadU32(
                (uintptr_t)patches[i].destination,
                &actualInstruction)) {

            pxQoLLog(
                @"[PixivOAuthUser/PatchApplication] FAIL [8] read-back failed at index=%d address=%p",
                i,
                patches[i].destination
            );

            return false;
        }


        const uint32_t expectedInstruction =
            plan->operations[i].replacementInstruction;

        if (actualInstruction !=
            expectedInstruction) {

            pxQoLLog(
                @"[PixivOAuthUser/PatchApplication] FAIL [8] read-back mismatch at index=%d address=%p expected=0x%08x actual=0x%08x",
                i,
                patches[i].destination,
                (unsigned int)expectedInstruction,
                (unsigned int)actualInstruction
            );

            return false;
        }


        pxQoLLog(
            @"[PixivOAuthUser/PatchApplication] verified patch[%d] address=%p instruction=0x%08x",
            i,
            patches[i].destination,
            (unsigned int)actualInstruction
        );
    }


    return true;
}
