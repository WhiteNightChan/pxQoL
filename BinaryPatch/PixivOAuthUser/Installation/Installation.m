#import "Installation.h"

#import "PatchApplication.h"
#import "PatchPlan.h"
#import "../Discovery/Discovery.h"
#import "../../Core/MachO.h"
#import "../../Core/MemoryPatch.h"
#import "../../../LogHelper.h"

#include <stdbool.h>
#include <stdint.h>


/* Runtime-owned context publication API. */
bool pxqPublishAssignmentCallRuntimeContext(
    const PXQPixivOAuthUserAssignmentCallContract *contract
);


static void pxqLogPixivOAuthUserInterceptionContract(
    const PXQPixivOAuthUserInterceptionContract *contract,
    uintptr_t imageBase
)
{
    pxQoLLog(
        @"[PixivOAuthUser/Installation] assignmentCallSiteCount=%zu",
        contract->assignmentCall.callSiteCount
    );


    for (size_t i = 0;
         i < contract->assignmentCall.callSiteCount;
         i++) {

        pxQoLLog(
            @"[PixivOAuthUser/Installation] assignmentCall[%zu]=pixiv+0x%llx",
            i,
            (unsigned long long)(
                contract->assignmentCall.callSites[i] -
                imageBase
            )
        );
    }


    pxQoLLog(
        @"[PixivOAuthUser/Installation] assignmentCallOriginalWrapper=pixiv+0x%llx",
        (unsigned long long)(
            contract->assignmentCall.originalAssignmentWrapper -
            imageBase
        )
    );


    pxQoLLog(
        @"[PixivOAuthUser/Installation] pixivOAuthUserMetadataAccessor=pixiv+0x%llx",
        (unsigned long long)(
            contract->assignmentCall.pixivOAuthUserMetadataAccessor -
            imageBase
        )
    );


    pxQoLLog(
        @"[PixivOAuthUser/Installation] assignmentReturnSiteCount=%zu",
        contract->assignmentReturn.siteCount
    );


    for (size_t i = 0;
         i < contract->assignmentReturn.siteCount;
         i++) {

        pxQoLLog(
            @"[PixivOAuthUser/Installation] assignmentReturn[%zu]=pixiv+0x%llx destination=x%u metadata=x%u",
            i,
            (unsigned long long)(
                contract->assignmentReturn.sites[i].patchSite -
                imageBase
            ),
            (unsigned int)
                contract->assignmentReturn.sites[i].capture.destinationRegister,
            (unsigned int)
                contract->assignmentReturn.sites[i].capture.metadataRegister
        );
    }
}


BOOL pxQoLInstallPixivOAuthUserPremiumOverride(void)
{
    pxQoLLog(
        @"[PixivOAuthUser/Installation] === installation start ==="
    );


    const struct mach_header_64 *header =
        pxqMachOFindLoadedImage(
            "/pixiv.app/pixiv"
        );

    if (!header) {
        pxQoLLog(
            @"[PixivOAuthUser/Installation] FAIL [1] pixiv image not found"
        );
        return NO;
    }


    unsigned long textSize =
        0;

    uint8_t *text =
        pxqMachOGetTextSection(
            header,
            &textSize
        );

    if (!text ||
        textSize < sizeof(uint32_t)) {

        pxQoLLog(
            @"[PixivOAuthUser/Installation] FAIL [2] __TEXT,__text not found"
        );
        return NO;
    }


    PXQPixivOAuthUserInterceptionContract contract;

    if (!pxqDiscoverPixivOAuthUserInterceptionContract(
            text,
            textSize,
            &contract)) {

        pxQoLLog(
            @"[PixivOAuthUser/Installation] FAIL [3] discovery failed"
        );
        return NO;
    }


    PXQPatchPlan plan = {0};

    if (!pxqBuildPixivOAuthUserPatchPlan(
            &contract,
            &plan)) {

        return NO;
    }


    pxqLogPixivOAuthUserInterceptionContract(
        &contract,
        (uintptr_t)header
    );


    /*
     * Preserve the established ordering: all branch generation and
     * plan validation must finish before resolving the patch backend.
     */
    LHPatchMemoryFunc patchMemory =
        pxqMemoryPatchResolveBackend();

    if (!patchMemory) {
        pxQoLLog(
            @"[PixivOAuthUser/Installation] FAIL [7] LHPatchMemory not found"
        );
        return NO;
    }


    /*
     * Publish the complete runtime context only after the plan and
     * backend are ready, but before any memory patch can become active.
     * After PatchApplication starts, the context is intentionally never
     * cleared because partial application cannot be ruled out.
     */
    if (!pxqPublishAssignmentCallRuntimeContext(
            &contract.assignmentCall)) {

        pxQoLLog(
            @"[PixivOAuthUser/Installation] FAIL [7] AssignmentCall runtime context publication failed"
        );
        return NO;
    }


    if (!pxqApplyPixivOAuthUserPatchPlan(
            &plan,
            patchMemory)) {

        return NO;
    }


    pxQoLLog(
        @"[PixivOAuthUser/Installation] === INSTALLATION SUCCESS ==="
    );

    return YES;
}
