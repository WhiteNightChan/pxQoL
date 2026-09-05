#import "Finder.h"

#import "../../Core/pxQoLARM64.h"

#import "../../../LogHelper.h"

#include <string.h>

#define pxQoLLog(fmt, ...) \
    [LogHelper appendLine:[NSString stringWithFormat:(fmt), ##__VA_ARGS__]]

BOOL pxQoLFindVideoAdContainingViewControllerMatch(
    uint8_t *text,
    unsigned long textSize,
    uint64_t targetIvarOffset,
    pxQoLVideoAdContainingViewControllerMatch *result
)
{
    if (!text ||
        textSize == 0 ||
        !result) {

        return NO;
    }

    memset(
        result,
        0,
        sizeof(pxQoLVideoAdContainingViewControllerMatch)
    );

    uint32_t *insns =
        (uint32_t *)text;

    const size_t instructionCount =
        textSize / sizeof(uint32_t);

    NSUInteger matchCount = 0;

    uint8_t *matchPatch1 = NULL;
    uint8_t *matchPatch2 = NULL;

    uintptr_t matchBranchTarget = 0;
    uintptr_t matchGlobalAddress = 0;
    uint64_t matchGlobalValue = 0;

    uint32_t matchObjectReg = 0;
    uint32_t matchIndexReg = 0;
    uint32_t matchLoadedReg = 0;
    uint32_t matchStoredReg = 0;


    for (size_t i = 0;
         i + 9 < instructionCount;
         i++) {

        /*
         * Global ivar offset:
         *
         *   ADRP xN, ...
         *   LDR  xN, [xN, #imm]
         */
        uintptr_t adrpAddress =
            (uintptr_t)text +
            i * sizeof(uint32_t);

        uint32_t adrpReg = 0;
        uintptr_t globalPage = 0;

        if (!pxQoLDecodeADRP(
                insns[i],
                adrpAddress,
                &adrpReg,
                &globalPage)) {

            continue;
        }

        uint32_t globalLdrRt = 0;
        uint32_t globalLdrRn = 0;
        uint32_t globalLdrImm12 = 0;

        if (!pxQoLIsLDR64UnsignedImm(
                insns[i + 1],
                &globalLdrRt,
                &globalLdrRn,
                &globalLdrImm12)) {

            continue;
        }

        if (globalLdrRn != adrpReg ||
            globalLdrRt != adrpReg) {

            continue;
        }

        uintptr_t globalAddress =
            globalPage +
            ((uintptr_t)globalLdrImm12 * 8);

        uint64_t globalValue = 0;

        if (!pxQoLReadU64(
                globalAddress,
                &globalValue)) {

            continue;
        }

        if (globalValue != targetIvarOffset) {
            continue;
        }


        /*
         * containedViewController access:
         *
         *   LDR xLoaded, [xObject, xIndex]
         *   STR x19,     [xObject, xIndex]
         */
        uint32_t loadedReg = 0;
        uint32_t objectReg = 0;
        uint32_t indexReg = 0;

        if (!pxQoLIsLDR64Register(
                insns[i + 2],
                &loadedReg,
                &objectReg,
                &indexReg)) {

            continue;
        }

        if (indexReg != globalLdrRt) {
            continue;
        }

        /*
         * The target wrapper-generation function uses:
         *
         *   x20 = generated VideoAdContainingViewController
         *
         * for the containedViewController ivar access.
         *
         * Reject unrelated xN-based ivar accesses even if
         * they happen to reference a global ivar offset of 0x28.
         */
        if (objectReg != 20) {
            continue;
        }

        uint32_t storedReg = 0;
        uint32_t strObjectReg = 0;
        uint32_t strIndexReg = 0;

        if (!pxQoLIsSTR64Register(
                insns[i + 3],
                &storedReg,
                &strObjectReg,
                &strIndexReg)) {

            continue;
        }

        if (strObjectReg != objectReg ||
            strIndexReg != indexReg ||
            storedReg != 19) {

            continue;
        }


        /*
         *   BL objc_release
         *   BL objc_retain
         */
        if (!pxQoLIsBL(insns[i + 4]) ||
            !pxQoLIsBL(insns[i + 5])) {

            continue;
        }


        /*
         * The wrapper-generation function keeps:
         *
         *   x19 = original view controller
         *   x20 = generated VideoAdContainingViewController
         *
         * and returns x20 normally:
         *
         *   MOV x0, x20
         */
        if (!pxQoLIsMovReg(
                insns[i + 6],
                0,
                20)) {

            continue;
        }


        /*
         * Locate patch1 from the function-local prologue pattern:
         *
         *   MOV  x19, x0
         *   ADRP xN, ...
         *   ADD  xN, xN, #...
         *
         * The MOV establishes x19 as the original view controller.
         * The following ADRP/ADD pair is the code that will be
         * replaced by:
         *
         *   MOV x0, x19
         *   B   patch2
         *
         * Do not assume a fixed instruction distance from the
         * containedViewController access.
         */
        size_t patch2Index =
            i + 6;

        size_t patch1Index = 0;

        BOOL foundPatch1 = NO;

        /*
         * Search backward within the same local function region.
         *
         * We only need to find:
         *
         *   MOV x19, x0
         *   ADRP xN, ...
         *   ADD  xN, xN, #...
         *
         * immediately followed by the ADRP.
         */
        size_t searchStart =
            (i > 128) ? (i - 128) : 0;

        for (size_t j = i;
             j > searchStart;
             j--) {

            size_t movIndex =
                j - 1;

            if (!pxQoLIsMovReg(
                    insns[movIndex],
                    19,
                    0)) {

                continue;
            }

            size_t candidatePatch1 =
                j;

            if (candidatePatch1 + 1 >= instructionCount) {
                continue;
            }

            uint32_t patchAdrpReg = 0;
            uintptr_t patchAdrpTarget = 0;

            if (!pxQoLDecodeADRP(
                    insns[candidatePatch1],
                    (uintptr_t)text +
                        candidatePatch1 * sizeof(uint32_t),
                    &patchAdrpReg,
                    &patchAdrpTarget)) {

                continue;
            }

            /*
             * ADD Xd, Xn, #imm
             *
             * Require the ADD to use the ADRP destination
             * as both destination and source.
             */
            uint32_t addInsn =
                insns[candidatePatch1 + 1];

            uint32_t addRd =
                addInsn & 0x1Fu;

            uint32_t addRn =
                (addInsn >> 5) & 0x1Fu;

            if ((addInsn & 0xFF000000u) != 0x91000000u ||
                addRd != patchAdrpReg ||
                addRn != patchAdrpReg) {

                continue;
            }

            patch1Index =
                candidatePatch1;

            foundPatch1 = YES;

            break;
        }

        if (!foundPatch1) {
            continue;
        }


        /*
         * The branch source is the ADD slot.
         *
         *   patch1:
         *       MOV x0, x19
         *
         *   patch1 + 4:
         *       B patch2
         *
         *   patch2:
         *       MOV x0, x19
         *
         * patch2 + 4 must be the existing function epilogue.
         */

        uintptr_t patch2Address =
            (uintptr_t)text +
            patch2Index * sizeof(uint32_t);

        /*
         * The original instruction at patch2 is
         * MOV x0, x20, so patch2 itself is the branch target.
         */
        uintptr_t branchTarget =
            patch2Address;

        /*
         * Existing epilogue:
         *
         *   LDP x29, x30, [sp, #...]
         *
         * Detect the exact pair used by the target.
         */
        uint32_t epilogue =
            insns[patch2Index + 1];

        if ((epilogue & 0xFFC003FFu) != 0xA94003FDu) {

            continue;
        }


        matchCount++;

        matchPatch1 =
            (uint8_t *)text +
            patch1Index * sizeof(uint32_t);

        matchPatch2 =
            (uint8_t *)text +
            patch2Index * sizeof(uint32_t);

        matchBranchTarget =
            branchTarget;

        matchGlobalAddress =
            globalAddress;

        matchGlobalValue =
            globalValue;

        matchObjectReg =
            objectReg;

        matchIndexReg =
            indexReg;

        matchLoadedReg =
            loadedReg;

        matchStoredReg =
            storedReg;


        pxQoLLog(
            @"[VideoAdContainingVC] candidate #%lu",
            (unsigned long)matchCount
        );

        pxQoLLog(
            @"[VideoAdContainingVC]   patch1=%p",
            matchPatch1
        );

        pxQoLLog(
            @"[VideoAdContainingVC]   patch2=%p",
            matchPatch2
        );

        pxQoLLog(
            @"[VideoAdContainingVC]   branchTarget=%p",
            (void *)matchBranchTarget
        );

        pxQoLLog(
            @"[VideoAdContainingVC]   globalAddress=%p",
            (void *)matchGlobalAddress
        );

        pxQoLLog(
            @"[VideoAdContainingVC]   globalValue=0x%llx",
            matchGlobalValue
        );

        pxQoLLog(
            @"[VideoAdContainingVC]   object=X%u index=X%u loaded=X%u stored=X%u",
            matchObjectReg,
            matchIndexReg,
            matchLoadedReg,
            matchStoredReg
        );
    }


    pxQoLLog(
        @"[VideoAdContainingVC] semantic candidate count = %lu",
        (unsigned long)matchCount
    );


    if (matchCount != 1 ||
        !matchPatch1 ||
        !matchPatch2) {

        if (matchCount == 0) {

            pxQoLLog(
                @"[VideoAdContainingVC] FAIL [3] no candidate with ivar offset 0x%llx",
                targetIvarOffset
            );

        } else {

            pxQoLLog(
                @"[VideoAdContainingVC] FAIL [3] ambiguous candidate count"
            );
        }

        return NO;
    }


    result->patch1 =
        matchPatch1;

    result->patch2 =
        matchPatch2;

    result->branchTarget =
        matchBranchTarget;

    result->globalAddress =
        matchGlobalAddress;

    result->globalValue =
        matchGlobalValue;

    result->objectReg =
        matchObjectReg;

    result->indexReg =
        matchIndexReg;

    result->loadedReg =
        matchLoadedReg;

    result->storedReg =
        matchStoredReg;


    pxQoLLog(
        @"[VideoAdContainingVC] target match = %p",
        matchPatch1
    );

    pxQoLLog(
        @"[VideoAdContainingVC] patch2 = %p",
        matchPatch2
    );

    pxQoLLog(
        @"[VideoAdContainingVC] global ivar address = %p",
        (void *)matchGlobalAddress
    );

    pxQoLLog(
        @"[VideoAdContainingVC] global ivar value = 0x%llx",
        matchGlobalValue
    );


    return YES;
}