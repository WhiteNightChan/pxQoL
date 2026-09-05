#import "Patch.h"

#import "../../Core/pxQoLARM64.h"
#import "../../Core/pxQoLMachO.h"
#import "../../Core/pxQoLMemoryPatch.h"
#import "Finder.h"

#import "../../../LogHelper.h"

#include <stdint.h>

#define pxQoLLog(fmt, ...) \
    [LogHelper appendLine:[NSString stringWithFormat:(fmt), ##__VA_ARGS__]]

#pragma mark - Patch

BOOL pxQoLPatchVideoAdContainingViewController(void)
{
    pxQoLLog(
        @"[VideoAdContainingVC] === pxQoL patch start ==="
    );

    /*
     * Legacy.VideoAdContainingViewController
     *
     * ivar:
     *   +0x28 containedViewController
     */
    const uint64_t TARGET_IVAR_OFFSET = 0x28;


    /*
     * Find pixiv Mach-O image.
     */
    const struct mach_header_64 *header =
        pxQoLFindPixivImage();

    if (!header) {

        pxQoLLog(
            @"[VideoAdContainingVC] FAIL [1] pixiv image not found"
        );

        return NO;
    }


    /*
     * Get __TEXT,__text.
     */
    unsigned long textSize = 0;

    uint8_t *text =
        pxQoLGetTextSection(
            header,
            &textSize
        );

    if (!text ||
        textSize < 16 * sizeof(uint32_t)) {

        pxQoLLog(
            @"[VideoAdContainingVC] FAIL [2] __TEXT,__text not found"
        );

        return NO;
    }

    pxQoLLog(
        @"[VideoAdContainingVC] __text=%p size=%lu",
        text,
        textSize
    );


    /*
     * Find the semantic wrapper-generation pattern.
     *
     * The Finder returns:
     *
     *   patch1
     *       original:
     *           ADRP x8, ...
     *
     *   patch2
     *       original:
     *           MOV x0, x20
     *
     * The instruction at patch1 + 4 is the branch slot.
     */
    pxQoLVideoAdContainingViewControllerMatch scanResult;

    if (!pxQoLFindVideoAdContainingViewControllerMatch(
            text,
            textSize,
            TARGET_IVAR_OFFSET,
            &scanResult)) {

        pxQoLLog(
            @"[VideoAdContainingVC] FAIL [3] target pattern not found"
        );

        return NO;
    }


    uint8_t *patch1 =
        scanResult.patch1;

    uint8_t *patch2 =
        scanResult.patch2;


    /*
     * Sanity checks before generating the patch.
     */
    if (!patch1 ||
        !patch2) {

        pxQoLLog(
            @"[VideoAdContainingVC] FAIL [4] invalid patch address"
        );

        return NO;
    }


    uintptr_t patch1Address =
        (uintptr_t)patch1;

    uintptr_t patch2Address =
        (uintptr_t)patch2;


    /*
     * patch1 + 4 is the branch instruction slot.
     *
     *   patch1:
     *       MOV X0, X19
     *
     *   patch1 + 4:
     *       B patch2
     *
     *   patch2:
     *       MOV X0, X19
     *
     *   patch2 + 4:
     *       original epilogue
     */
    uintptr_t branchAddress =
        patch1Address + sizeof(uint32_t);

    uint32_t branchInstruction = 0;

    if (!pxQoLMakeB(
            branchAddress,
            patch2Address,
            &branchInstruction)) {

        pxQoLLog(
            @"[VideoAdContainingVC] FAIL [5] cannot encode branch"
        );

        return NO;
    }


    pxQoLLog(
        @"[VideoAdContainingVC] patch1=%p",
        (void *)patch1Address
    );

    pxQoLLog(
        @"[VideoAdContainingVC] branchAddress=%p",
        (void *)branchAddress
    );

    pxQoLLog(
        @"[VideoAdContainingVC] patch2=%p",
        (void *)patch2Address
    );

    pxQoLLog(
        @"[VideoAdContainingVC] branchInstruction=0x%08x",
        branchInstruction
    );


    /*
     * Verify the instructions that are about to be replaced.
     *
     * patch1:
     *   ADRP x8, ...
     *
     * patch1 + 4:
     *   ADD x8, x8, #...
     *
     * patch2:
     *   MOV x0, x20
     */
    uint32_t originalPatch1 =
        *(uint32_t *)patch1;

    uint32_t originalBranchSlot =
        *(uint32_t *)(patch1 + sizeof(uint32_t));

    uint32_t originalPatch2 =
        *(uint32_t *)patch2;


    uint32_t patch1Reg = 0;
    uintptr_t patch1Target = 0;

    if (!pxQoLDecodeADRP(
            originalPatch1,
            patch1Address,
            &patch1Reg,
            &patch1Target)) {
        pxQoLLog(@"[VideoAdContainingVC] FAIL [6] patch1 is not ADRP");
        return NO;
    }


    if ((originalBranchSlot & 0xFF000000u) != 0x91000000u) {

        pxQoLLog(
            @"[VideoAdContainingVC] FAIL [7] branch slot is not ADD immediate"
        );

        return NO;
    }


    if (!pxQoLIsMovReg(
            originalPatch2,
            0,
            20)) {

        pxQoLLog(
            @"[VideoAdContainingVC] FAIL [8] patch2 is not MOV X0,X20"
        );

        return NO;
    }


    /*
     * Do not patch an already-patched function.
     */
    if (pxQoLIsMovReg(
            originalPatch1,
            0,
            19)) {

        pxQoLLog(
            @"[VideoAdContainingVC] FAIL [9] patch1 already patched"
        );

        return NO;
    }


    if (pxQoLIsMovReg(
            originalBranchSlot,
            0,
            19)) {

        pxQoLLog(
            @"[VideoAdContainingVC] FAIL [10] branch slot already patched"
        );

        return NO;
    }


    /*
     * Patch #1:
     *
     *   ADRP x8, ...
     *       ->
     *   MOV X0, X19
     *
     *   ADD X8, X8, #...
     *       ->
     *   B patch2
     */
    uint32_t patch1Data[] = {
        0xAA1303E0,       // mov x0, x19
        branchInstruction
    };


    /*
     * Patch #2:
     *
     *   MOV X0, X20
     *       ->
     *   MOV X0, X19
     *
     * The existing epilogue at patch2 + 4 remains untouched.
     */
    uint32_t patch2Data[] = {
        0xAA1303E0        // mov x0, x19
    };


    pxQoLLog(
        @"[VideoAdContainingVC] original patch1 = 0x%08x",
        originalPatch1
    );

    pxQoLLog(
        @"[VideoAdContainingVC] original branch slot = 0x%08x",
        originalBranchSlot
    );

    pxQoLLog(
        @"[VideoAdContainingVC] original patch2 = 0x%08x",
        originalPatch2
    );


    /*
     * Get LHPatchMemory.
     */
    LHPatchMemoryFunc patchMemory =
        pxQoLGetPatchMemory();

    if (!patchMemory) {

        pxQoLLog(
            @"[VideoAdContainingVC] FAIL [11] LHPatchMemory not found"
        );

        return NO;
    }

    pxQoLLog(
        @"[VideoAdContainingVC] LHPatchMemory=%p",
        (void *)patchMemory
    );


    /*
     * Apply both patches independently.
     *
     * Patch #1 changes 8 bytes.
     * Patch #2 changes 4 bytes.
     *
     * Total = 12 bytes.
     */
    struct LHMemoryPatch memoryPatches[] = {

        {
            .destination = patch1,
            .data = patch1Data,
            .size = sizeof(patch1Data),
            .options = NULL
        },

        {
            .destination = patch2,
            .data = patch2Data,
            .size = sizeof(patch2Data),
            .options = NULL
        }
    };


    int patched =
        patchMemory(
            memoryPatches,
            2
        );

    pxQoLLog(
        @"[VideoAdContainingVC] LHPatchMemory result = %d",
        patched
    );

    if (patched != 0) {

        pxQoLLog(
            @"[VideoAdContainingVC] FAIL [12] LHPatchMemory"
        );

        return NO;
    }


    pxQoLLog(
        @"[VideoAdContainingVC] patch #1 success"
    );

    pxQoLLog(
        @"[VideoAdContainingVC] patch #2 success"
    );

    pxQoLLog(
        @"[VideoAdContainingVC] === PATCH SUCCESS ==="
    );

    return YES;
}