#import "Finder.h"

#import "../../Core/pxQoLARM64.h"

#import "../../../LogHelper.h"

#include <string.h>

#define pxQoLLog(fmt, ...) \
    [LogHelper appendLine:[NSString stringWithFormat:(fmt), ##__VA_ARGS__]]

BOOL pxQoLFindAdContainingViewControllerMatch(
    uint8_t *text,
    unsigned long textSize,
    uint64_t targetIvarOffset,
    pxQoLAdContainingViewControllerMatch *result
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
        sizeof(pxQoLAdContainingViewControllerMatch)
    );

    uint32_t *insns =
        (uint32_t *)text;

    const size_t instructionCount =
        textSize / sizeof(uint32_t);

    NSUInteger matchCount = 0;
    uint8_t *match = NULL;
    int matchVariant = 0;
    uintptr_t matchBranchTarget = 0;
    uintptr_t matchGlobalAddress = 0;
    uint64_t matchGlobalValue = 0;
    uint32_t matchObjectReg = 0;
    uint32_t matchIndexReg = 0;
    uint32_t matchLoadedReg = 0;
    uint32_t matchStoredReg = 0;

    for (size_t i = 0;
         i + 7 < instructionCount;
         i++) {

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

        if (globalLdrRn != adrpReg) {
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

        if (globalValue != targetIvarOffset)
            continue;

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
            strIndexReg != indexReg) {

            continue;
        }

        // Variant A
        if (pxQoLIsBL(insns[i + 4]) &&
            pxQoLIsMovReg(
                insns[i + 5],
                0,
                objectReg) &&
            pxQoLIsB(insns[i + 6])) {

            uintptr_t branchAddress =
                (uintptr_t)text +
                (i + 6) * sizeof(uint32_t);

            uintptr_t branchTarget = 0;

            if (pxQoLDecodeBranchTarget(
                    insns[i + 6],
                    branchAddress,
                    &branchTarget)) {

                matchCount++;

                match =
                    (uint8_t *)text +
                    (i + 2) * sizeof(uint32_t);

                matchVariant = 1;
                matchBranchTarget = branchTarget;
                matchGlobalAddress = globalAddress;
                matchGlobalValue = globalValue;
                matchObjectReg = objectReg;
                matchIndexReg = indexReg;
                matchLoadedReg = loadedReg;
                matchStoredReg = storedReg;

                pxQoLLog(
                    @"[AdContainingVC] candidate #%lu VARIANT A",
                    (unsigned long)matchCount
                );

                pxQoLLog(
                    @"[AdContainingVC]   match=%p",
                    match
                );

                pxQoLLog(
                    @"[AdContainingVC]   globalAddress=%p",
                    (void *)globalAddress
                );

                pxQoLLog(
                    @"[AdContainingVC]   globalValue=0x%llx",
                    globalValue
                );

                pxQoLLog(
                    @"[AdContainingVC]   object=X%u index=X%u loaded=X%u stored=X%u",
                    objectReg,
                    indexReg,
                    loadedReg,
                    storedReg
                );

                pxQoLLog(
                    @"[AdContainingVC]   continuation=%p",
                    (void *)branchTarget
                );

                continue;
            }
        }

        // Variant B
        size_t blIndex = i + 5;

        if (!pxQoLIsMovReg(
                insns[i + 4],
                19,
                objectReg)) {

            continue;
        }

        if (pxQoLIsBL(insns[i + 5]) &&
            pxQoLIsMovReg(
                insns[i + 6],
                0,
                19)) {

            blIndex = i + 5;
        }
        else if (pxQoLIsMovReg(
                     insns[i + 5],
                     0,
                     loadedReg) &&
                 pxQoLIsBL(insns[i + 6]) &&
                 pxQoLIsMovReg(
                     insns[i + 7],
                     0,
                     19)) {

            blIndex = i + 6;
        }
        else {
            continue;
        }

        matchCount++;

        match =
            (uint8_t *)text +
            (i + 2) * sizeof(uint32_t);

        matchVariant = 2;
        matchBranchTarget = 0;
        matchGlobalAddress = globalAddress;
        matchGlobalValue = globalValue;
        matchObjectReg = objectReg;
        matchIndexReg = indexReg;
        matchLoadedReg = loadedReg;
        matchStoredReg = storedReg;

        pxQoLLog(
            @"[AdContainingVC] candidate #%lu VARIANT B",
            (unsigned long)matchCount
        );

        pxQoLLog(
            @"[AdContainingVC]   match=%p",
            match
        );

        pxQoLLog(
            @"[AdContainingVC]   BL=%p",
            (void *)(
                (uintptr_t)text +
                blIndex * sizeof(uint32_t)
            )
        );

        pxQoLLog(
            @"[AdContainingVC]   match=%p",
            match
        );

        pxQoLLog(
            @"[AdContainingVC]   globalAddress=%p",
            (void *)globalAddress
        );

        pxQoLLog(
            @"[AdContainingVC]   globalValue=0x%llx",
            globalValue
        );

        pxQoLLog(
            @"[AdContainingVC]   object=X%u index=X%u loaded=X%u stored=X%u",
            objectReg,
            indexReg,
            loadedReg,
            storedReg
        );
    }

    // Candidate count
    pxQoLLog(
        @"[AdContainingVC] semantic candidate count = %lu",
        (unsigned long)matchCount
    );

    if (matchCount != 1 ||
        !match) {

        if (matchCount == 0) {

            pxQoLLog(
                @"[AdContainingVC] FAIL [3] no candidate with ivar offset 0x%llx",
                targetIvarOffset
            );

        } else {

            pxQoLLog(
                @"[AdContainingVC] FAIL [3] ambiguous candidate count"
            );
        }

        return NO;
    }

    pxQoLLog(
        @"[AdContainingVC] target match = %p",
        match
    );

    pxQoLLog(
        @"[AdContainingVC] variant = %d",
        matchVariant
    );

    pxQoLLog(
        @"[AdContainingVC] global ivar address = %p",
        (void *)matchGlobalAddress
    );

    pxQoLLog(
        @"[AdContainingVC] global ivar value = 0x%llx",
        matchGlobalValue
    );

    pxQoLLog(
        @"[AdContainingVC] object register = X%u",
        matchObjectReg
    );

    pxQoLLog(
        @"[AdContainingVC] index register = X%u",
        matchIndexReg
    );

    pxQoLLog(
        @"[AdContainingVC] loaded register = X%u",
        matchLoadedReg
    );

    pxQoLLog(
        @"[AdContainingVC] stored register = X%u",
        matchStoredReg
    );

    result->match =
        match;

    result->variant =
        matchVariant;

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

    return YES;
}