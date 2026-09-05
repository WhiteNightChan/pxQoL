#import "Patch.h"
#import "../../Core/pxQoLARM64.h"
#import "../../Core/pxQoLMachO.h"
#import "../../Core/pxQoLMemoryPatch.h"
#import "Finder.h"

#import <UIKit/UIKit.h>
#include <stdint.h>

#import "../../../LogHelper.h"

#define pxQoLLog(fmt, ...) \
    [LogHelper appendLine:[NSString stringWithFormat:(fmt), ##__VA_ARGS__]]

#pragma mark - Patch

BOOL pxQoLPatchAdContainingViewController(void)
{
    pxQoLLog(@"[AdContainingVC] === pxQoL patch start ===");

    const uint64_t TARGET_IVAR_OFFSET = 0x30;

    const struct mach_header_64 *header =
        pxQoLFindPixivImage();

    if (!header) {

        pxQoLLog(
            @"[AdContainingVC] FAIL [1] pixiv image not found"
        );

        return NO;
    }


    // Get __TEXT,__text
    unsigned long textSize = 0;

    uint8_t *text =
        pxQoLGetTextSection(
            header,
            &textSize
        );

    if (!text ||
        textSize < 8 * sizeof(uint32_t)) {

        pxQoLLog(
            @"[AdContainingVC] FAIL [2] __TEXT,__text not found"
        );

        return NO;
    }

    pxQoLLog(
        @"__text=%p size=%lu",
        text,
        textSize
    );


    pxQoLAdContainingViewControllerMatch scanResult;

    if (!pxQoLFindAdContainingViewControllerMatch(
            text,
            textSize,
            TARGET_IVAR_OFFSET,
            &scanResult)) {

        return NO;
    }

    uint8_t *match =
        scanResult.match;

    int matchVariant =
        scanResult.variant;

    uintptr_t matchBranchTarget =
        scanResult.branchTarget;

    // LHPatchMemory
    LHPatchMemoryFunc patchMemory =
        pxQoLGetPatchMemory();

    if (!patchMemory) {

        pxQoLLog(
            @"[AdContainingVC] FAIL [4] LHPatchMemory not found"
        );

        return NO;
    }

    pxQoLLog(
        @"LHPatchMemory = %p",
        (void *)patchMemory
    );


    // Variant A patch
    if (matchVariant == 1) {

        uintptr_t newBranchAddress =
            (uintptr_t)match + 0x18;

        uint32_t newBranch = 0;

        if (!pxQoLMakeB(
                newBranchAddress,
                matchBranchTarget,
                &newBranch)) {

            pxQoLLog(
                @"[AdContainingVC] FAIL [5] cannot encode Variant A continuation branch"
            );

            return NO;
        }

        uint32_t patch[] = {
            0xAA1303E0,   // mov x0, x19
            0xD503201F,   // nop
            0xD503201F,   // nop
            0xD503201F,   // nop
            0xD503201F,   // nop
            0xD503201F,   // nop
            newBranch     // b original continuation
        };

        pxQoLLog(
            @"[AdContainingVC] Variant A patch"
        );

        pxQoLLog(
            @"[AdContainingVC]   branch source=%p",
            (void *)newBranchAddress
        );

        pxQoLLog(
            @"[AdContainingVC]   branch target=%p",
            (void *)matchBranchTarget
        );

        pxQoLLog(
            @"[AdContainingVC]   branch instruction=%08x",
            newBranch
        );

        struct LHMemoryPatch memoryPatch = {
            .destination = match,
            .data = patch,
            .size = sizeof(patch),
            .options = NULL
        };

        int patched =
            patchMemory(
                &memoryPatch,
                1
            );

        pxQoLLog(
            @"[AdContainingVC] LHPatchMemory result = %d",
            patched
        );

        if (patched != 0) {

            pxQoLLog(
                @"[AdContainingVC] FAIL [6] Variant A LHPatchMemory"
            );

            return NO;
        }

        pxQoLLog(
            @"[AdContainingVC] Variant A patch success"
        );
    }


    // Variant B patch
    else if (matchVariant == 2) {

        /*
         * The original epilogue starts at match + 0x14.
         * Only the five instructions at +00 .. +10 are replaced.
         */
        uint32_t patch[] = {
            0xAA1303E0,   // +00 mov x0, x19
            0xD503201F,   // +04 nop
            0xD503201F,   // +08 nop
            0xD503201F,   // +0c nop
            0xD503201F    // +10 nop
        };

        pxQoLLog(
            @"[AdContainingVC] Variant B patch"
        );

        pxQoLLog(
            @"[AdContainingVC]   original epilogue preserved at match+0x14"
        );

        struct LHMemoryPatch memoryPatch = {
            .destination = match,
            .data = patch,
            .size = sizeof(patch),
            .options = NULL
        };

        int patched =
            patchMemory(
                &memoryPatch,
                1
            );

        pxQoLLog(
            @"[AdContainingVC] LHPatchMemory result = %d",
            patched
        );

        if (patched != 0) {

            pxQoLLog(
                @"[AdContainingVC] FAIL [7] Variant B LHPatchMemory"
            );

            return NO;
        }

        pxQoLLog(
            @"[AdContainingVC] Variant B patch success"
        );
    }


    else {

        pxQoLLog(
            @"[AdContainingVC] FAIL [8] unknown patch variant"
        );

        return NO;
    }


    pxQoLLog(
        @"[AdContainingVC] === PATCH SUCCESS ==="
    );

    return YES;
}