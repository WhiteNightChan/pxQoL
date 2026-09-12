#import "PatchPlan.h"

#import "../../Core/ARM64.h"
#import "../../../LogHelper.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>


/* Runtime-owned adapter selection APIs. */
bool pxqResolveAssignmentCallRuntimeEntry(
    PXQPixivOAuthUserAssignmentCallKind kind,
    uintptr_t *runtimeEntryAddress
);

bool pxqResolveAssignmentReturnRuntimeEntry(
    const PXQAssignmentReturnCapture *capture,
    uintptr_t *runtimeEntryAddress
);


static bool pxqValidatePixivOAuthUserInterceptionContract(
    const PXQPixivOAuthUserInterceptionContract *contract
)
{
    if (!contract)
        return false;


    const bool assignmentCallKindSupported =
        (contract->assignmentCall.kind ==
            PXQ_PIXIV_OAUTH_USER_ASSIGNMENT_CALL_TWO_ARGUMENT ||
         contract->assignmentCall.kind ==
            PXQ_PIXIV_OAUTH_USER_ASSIGNMENT_CALL_WITH_TYPE_REFERENCE);


    const bool assignmentCallUsesTypeReference =
        (contract->assignmentCall.kind ==
            PXQ_PIXIV_OAUTH_USER_ASSIGNMENT_CALL_WITH_TYPE_REFERENCE);


    const bool assignmentReturnCountValid =
        (contract->assignmentReturn.siteCount > 0 &&
         contract->assignmentReturn.siteCount <=
            PXQ_PIXIV_OAUTH_USER_MAX_ASSIGNMENT_RETURN_SITES);


    if (!assignmentCallKindSupported ||
        contract->assignmentCall.callSiteCount == 0 ||
        contract->assignmentCall.callSiteCount >
            PXQ_PIXIV_OAUTH_USER_MAX_ASSIGNMENT_CALL_SITES ||
        (assignmentCallUsesTypeReference &&
         contract->assignmentCall.callSiteCount != 1) ||
        contract->assignmentCall.originalAssignmentWrapper == 0 ||
        contract->assignmentCall.pixivOAuthUserMetadataAccessor == 0 ||
        !assignmentReturnCountValid) {

        pxQoLLog(
            @"[PixivOAuthUser/PatchPlan] FAIL [4] invalid interception contract"
        );
        return false;
    }


    for (size_t i = 0;
         i < contract->assignmentReturn.siteCount;
         i++) {

        const PXQPixivOAuthUserAssignmentReturnSite *site =
            &contract->assignmentReturn.sites[i];

        const bool captureX19X21 =
            (site->capture.destinationRegister == 19 &&
             site->capture.metadataRegister == 21);

        const bool captureX21X19 =
            (site->capture.destinationRegister == 21 &&
             site->capture.metadataRegister == 19);

        /*
         * Production support policy is intentionally separate from
         * Runtime adapter availability. A new adapter alone must not
         * silently expand the supported capture contract.
         */
        if (site->patchSite == 0 ||
            (!captureX19X21 &&
             !captureX21X19)) {

            pxQoLLog(
                @"[PixivOAuthUser/PatchPlan] FAIL [4] invalid AssignmentReturn site[%zu] patchSite=%p destination=x%u metadata=x%u",
                i,
                (void *)site->patchSite,
                (unsigned int)site->capture.destinationRegister,
                (unsigned int)site->capture.metadataRegister
            );

            return false;
        }
    }


    return true;
}


bool pxqBuildPixivOAuthUserPatchPlan(
    const PXQPixivOAuthUserInterceptionContract *contract,
    PXQPatchPlan *plan
)
{
    if (!plan ||
        !pxqValidatePixivOAuthUserInterceptionContract(contract)) {

        return false;
    }


    PXQPatchPlan builtPlan = {0};


    uintptr_t assignmentCallRuntimeEntry =
        0;

    if (!pxqResolveAssignmentCallRuntimeEntry(
            contract->assignmentCall.kind,
            &assignmentCallRuntimeEntry)) {

        pxQoLLog(
            @"[PixivOAuthUser/PatchPlan] FAIL [5] unsupported AssignmentCall kind=%u",
            (unsigned int)contract->assignmentCall.kind
        );
        return false;
    }


    for (size_t i = 0;
         i < contract->assignmentCall.callSiteCount;
         i++) {

        uint32_t instruction =
            0;

        if (!pxqARM64EncodeBL(
                contract->assignmentCall.callSites[i],
                assignmentCallRuntimeEntry,
                &instruction)) {

            pxQoLLog(
                @"[PixivOAuthUser/PatchPlan] FAIL [5] AssignmentCall trampoline BL out of range at index=%zu",
                i
            );

            pxQoLLog(
                @"[PixivOAuthUser/PatchPlan]   source=%p target=%p",
                (void *)contract->assignmentCall.callSites[i],
                (void *)assignmentCallRuntimeEntry
            );

            return false;
        }


        PXQPatchOperation *operation =
            &builtPlan.operations[builtPlan.operationCount++];

        operation->targetAddress =
            contract->assignmentCall.callSites[i];

        operation->replacementInstruction =
            instruction;
    }


#if !defined(__aarch64__)

    pxQoLLog(
        @"[PixivOAuthUser/PatchPlan] FAIL [6] AssignmentReturn trampolines require arm64"
    );
    return false;

#else

    for (size_t i = 0;
         i < contract->assignmentReturn.siteCount;
         i++) {

        const PXQPixivOAuthUserAssignmentReturnSite *site =
            &contract->assignmentReturn.sites[i];

        uintptr_t assignmentReturnRuntimeEntry =
            0;

        if (!pxqResolveAssignmentReturnRuntimeEntry(
                &site->capture,
                &assignmentReturnRuntimeEntry)) {

            pxQoLLog(
                @"[PixivOAuthUser/PatchPlan] FAIL [6] AssignmentReturn runtime adapter unavailable at index=%zu destination=x%u metadata=x%u",
                i,
                (unsigned int)site->capture.destinationRegister,
                (unsigned int)site->capture.metadataRegister
            );
            return false;
        }


        uint32_t instruction =
            0;

        if (!pxqARM64EncodeBL(
                site->patchSite,
                assignmentReturnRuntimeEntry,
                &instruction)) {

            pxQoLLog(
                @"[PixivOAuthUser/PatchPlan] FAIL [6] AssignmentReturn trampoline BL out of range at index=%zu destination=x%u metadata=x%u",
                i,
                (unsigned int)site->capture.destinationRegister,
                (unsigned int)site->capture.metadataRegister
            );

            pxQoLLog(
                @"[PixivOAuthUser/PatchPlan]   source=%p target=%p",
                (void *)site->patchSite,
                (void *)assignmentReturnRuntimeEntry
            );

            return false;
        }


        PXQPatchOperation *operation =
            &builtPlan.operations[builtPlan.operationCount++];

        operation->targetAddress =
            site->patchSite;

        operation->replacementInstruction =
            instruction;
    }

#endif


    if (builtPlan.operationCount == 0 ||
        builtPlan.operationCount >
            PXQ_PIXIV_OAUTH_USER_MAX_PATCH_OPERATIONS) {

        return false;
    }


    /* Publish only a complete plan. */
    *plan =
        builtPlan;

    return true;
}
