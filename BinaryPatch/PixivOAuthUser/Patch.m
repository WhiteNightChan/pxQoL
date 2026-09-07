#import "Patch.h"
#import "Finder.h"
#import "../Core/pxQoLARM64.h"
#import "../Core/pxQoLMachO.h"
#import "../Core/pxQoLMemoryPatch.h"

#include <stdint.h>

#import "../../LogHelper.h"

typedef void *(*PXQInitialAssignmentWrapperFunc)(
    void *source,
    void *destination
);

typedef void *(*PXQMetadataAccessorFunc)(
    uintptr_t request
);


static PXQInitialAssignmentWrapperFunc
    gOriginalWrapper = NULL;

static PXQMetadataAccessorFunc
    gMetadataAccessor = NULL;


__attribute__((noinline))
static void *pxQoLInitialPremiumTrampoline(
    void *source,
    void *destination
)
{
    /*
     * Preserve the original Swift assignment completely first.
     * gOriginalWrapper is installed before any callsite is patched.
     */
    void *result =
        gOriginalWrapper(
            source,
            destination
        );

    PXQMetadataAccessorFunc accessor =
        gMetadataAccessor;

    if (!accessor ||
        !destination) {

        return result;
    }

    /*
     * PixivOAuthUser metadata accessor.
     * Only x0 is needed from the metadata response.
     */
    void *metadata =
        accessor(0);

    if (!metadata)
        return result;

    int32_t isPremiumOffset =
        *(const int32_t *)(
            (const uint8_t *)metadata +
            0x28
        );

    /*
     * Initial implementation is intentionally fail-closed for
     * layouts other than the device-confirmed offset 65.
     */
    if (isPremiumOffset == 65) {
        *((uint8_t *)destination +
          (size_t)isPremiumOffset) = 1;
    }

    return result;
}


BOOL pxQoLPatchPixivOAuthUserPremium(void)
{
    pxQoLLog(
        @"[PixivOAuthUser] === patch start ==="
    );

    const struct mach_header_64 *header =
        pxQoLFindPixivImage();

    if (!header) {
        pxQoLLog(
            @"[PixivOAuthUser] FAIL [1] pixiv image not found"
        );
        return NO;
    }


    unsigned long textSize = 0;

    uint8_t *text =
        pxQoLGetTextSection(
            header,
            &textSize
        );

    if (!text ||
        textSize < sizeof(uint32_t)) {

        pxQoLLog(
            @"[PixivOAuthUser] FAIL [2] __TEXT,__text not found"
        );
        return NO;
    }


    pxQoLPixivOAuthUserMatch match;

    if (!pxQoLFindPixivOAuthUserMatch(
            text,
            textSize,
            &match)) {

        pxQoLLog(
            @"[PixivOAuthUser] FAIL [3] finder validation failed"
        );
        return NO;
    }


    if (match.initialCallsiteCount == 0 ||
        match.initialCallsiteCount >
            PXQ_PIXIV_OAUTH_USER_MAX_INITIAL_CALLSITES ||
        match.initialOriginalWrapper == 0 ||
        match.metadataAccessor == 0 ||
        match.laterPremiumLoad == 0) {

        pxQoLLog(
            @"[PixivOAuthUser] FAIL [4] invalid finder result"
        );
        return NO;
    }


    uintptr_t imageBase =
        (uintptr_t)header;

    pxQoLLog(
        @"[PixivOAuthUser] initialCallsiteCount=%zu",
        match.initialCallsiteCount
    );

    for (size_t i = 0;
         i < match.initialCallsiteCount;
         i++) {

        pxQoLLog(
            @"[PixivOAuthUser] initial[%zu]=pixiv+0x%llx",
            i,
            (unsigned long long)(
                match.initialCallsites[i] -
                imageBase
            )
        );
    }

    pxQoLLog(
        @"[PixivOAuthUser] originalWrapper=pixiv+0x%llx",
        (unsigned long long)(
            match.initialOriginalWrapper -
            imageBase
        )
    );

    pxQoLLog(
        @"[PixivOAuthUser] metadataAccessor=pixiv+0x%llx",
        (unsigned long long)(
            match.metadataAccessor -
            imageBase
        )
    );

    pxQoLLog(
        @"[PixivOAuthUser] laterPremiumLoad=pixiv+0x%llx",
        (unsigned long long)(
            match.laterPremiumLoad -
            imageBase
        )
    );


    /*
     * ---------------------------------------------------------
     * Build every patch instruction before changing memory.
     * ---------------------------------------------------------
     */

    uint32_t initialInstructions[
        PXQ_PIXIV_OAUTH_USER_MAX_INITIAL_CALLSITES
    ] = {0};

    uintptr_t trampolineAddress =
        (uintptr_t)&pxQoLInitialPremiumTrampoline;


    for (size_t i = 0;
         i < match.initialCallsiteCount;
         i++) {

        if (!pxQoLMakeBL(
                match.initialCallsites[i],
                trampolineAddress,
                &initialInstructions[i])) {

            pxQoLLog(
                @"[PixivOAuthUser] FAIL [5] trampoline BL out of range at initial[%zu]",
                i
            );

            pxQoLLog(
                @"[PixivOAuthUser]   source=%p target=%p",
                (void *)match.initialCallsites[i],
                (void *)trampolineAddress
            );

            return NO;
        }
    }


    uint32_t laterInstruction = 0;

    if (!pxQoLMakeMOVZ32(
            8,
            1,
            &laterInstruction)) {

        pxQoLLog(
            @"[PixivOAuthUser] FAIL [6] cannot encode mov w8,#1"
        );
        return NO;
    }


    /*
     * Do not resolve LHPatchMemory until all Finder and ARM64
     * instruction validation has succeeded.
     */
    LHPatchMemoryFunc patchMemory =
        pxQoLGetPatchMemory();

    if (!patchMemory) {
        pxQoLLog(
            @"[PixivOAuthUser] FAIL [7] LHPatchMemory not found"
        );
        return NO;
    }


    /*
     * Globals must be valid before any initial callsite can branch
     * to the trampoline.
     */
    gOriginalWrapper =
        (PXQInitialAssignmentWrapperFunc)
        match.initialOriginalWrapper;

    gMetadataAccessor =
        (PXQMetadataAccessorFunc)
        match.metadataAccessor;


    struct LHMemoryPatch patches[
        PXQ_PIXIV_OAUTH_USER_MAX_INITIAL_CALLSITES + 1
    ];

    int patchCount = 0;


    for (size_t i = 0;
         i < match.initialCallsiteCount;
         i++) {

        patches[patchCount++] =
            (struct LHMemoryPatch) {
                .destination =
                    (void *)match.initialCallsites[i],
                .data =
                    &initialInstructions[i],
                .size =
                    sizeof(initialInstructions[i]),
                .options =
                    NULL
            };
    }


    patches[patchCount++] =
        (struct LHMemoryPatch) {
            .destination =
                (void *)match.laterPremiumLoad,
            .data =
                &laterInstruction,
            .size =
                sizeof(laterInstruction),
            .options =
                NULL
        };


    pxQoLLog(
        @"[PixivOAuthUser] applying %d patches in one batch",
        patchCount
    );


    int patchResult =
        patchMemory(
            patches,
            patchCount
        );

    /*
     * LHPatchMemory return-value semantics are not used as the
     * authoritative success condition here.
     *
     * Keep the raw result for diagnostics, then verify every
     * patched 32-bit ARM64 instruction directly from memory.
     */
    pxQoLLog(
        @"[PixivOAuthUser] LHPatchMemory result=%d count=%d",
        patchResult,
        patchCount
    );


    for (int i = 0;
         i < patchCount;
         i++) {

        if (patches[i].size != sizeof(uint32_t)) {
            pxQoLLog(
                @"[PixivOAuthUser] FAIL [8] unexpected patch size at index=%d size=%zu",
                i,
                patches[i].size
            );

            /*
             * Do not clear gOriginalWrapper / gMetadataAccessor.
             * LHPatchMemory is not assumed to be transactional;
             * an initial BL may already point to the trampoline.
             */
            return NO;
        }


        uint32_t actualInstruction = 0;

        if (!pxQoLReadU32(
                (uintptr_t)patches[i].destination,
                &actualInstruction)) {

            pxQoLLog(
                @"[PixivOAuthUser] FAIL [8] read-back failed at index=%d address=%p",
                i,
                patches[i].destination
            );

            /*
             * Same reason: keep trampoline globals valid in case
             * this batch was only partially applied.
             */
            return NO;
        }


        uint32_t expectedInstruction =
            *(const uint32_t *)patches[i].data;


        if (actualInstruction !=
            expectedInstruction) {

            pxQoLLog(
                @"[PixivOAuthUser] FAIL [8] read-back mismatch at index=%d address=%p expected=0x%08x actual=0x%08x",
                i,
                patches[i].destination,
                (unsigned int)expectedInstruction,
                (unsigned int)actualInstruction
            );

            /*
             * Do not clear the globals here. A different patch in
             * the same batch may already have been applied.
             */
            return NO;
        }


        pxQoLLog(
            @"[PixivOAuthUser] verified patch[%d] address=%p instruction=0x%08x",
            i,
            patches[i].destination,
            (unsigned int)actualInstruction
        );
    }


    pxQoLLog(
        @"[PixivOAuthUser] === PATCH SUCCESS ==="
    );

    return YES;
}