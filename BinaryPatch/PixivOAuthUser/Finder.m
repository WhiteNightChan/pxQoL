#import "Finder.h"
#import "../Core/pxQoLARM64.h"
#import "../../LogHelper.h"

#include <string.h>


static bool pxqInText(
    uint8_t *text,
    unsigned long textSize,
    uintptr_t address,
    size_t size
)
{
    uintptr_t start =
        (uintptr_t)text;

    if (address < start)
        return false;

    uintptr_t offset =
        address - start;

    if (offset > (uintptr_t)textSize)
        return false;

    return size <=
        (size_t)textSize -
        (size_t)offset;
}


static bool pxqValidateInitialContext(
    const uint32_t *insns,
    size_t count,
    size_t i
)
{
    if (i < 7 ||
        i + 2 >= count) {

        return false;
    }

    /*
     * swift_beginAccess
     * -> add x1,x26,x20
     * -> mov x0,x24
     * -> bl wrapper
     * -> swift_endAccess
     */

    return
        insns[i - 7] ==
            0x8B140340u &&

        /*
         * add x0,x26,x20
         */

        insns[i - 6] ==
            0x910042C1u &&

        /*
         * add x1,x22,#0x10
         */

        insns[i - 5] ==
            0x52800422u &&

        /*
         * mov w2,#0x21
         */

        insns[i - 4] ==
            0xD2800003u &&

        /*
         * mov x3,#0
         */

        pxQoLIsBL(
            insns[i - 3]
        ) &&

        insns[i - 2] ==
            0x8B140341u &&

        /*
         * add x1,x26,x20
         */

        pxQoLIsMovReg(
            insns[i - 1],
            0,
            24
        ) &&

        /*
         * mov x0,x24
         */

        pxQoLIsBL(
            insns[i]
        ) &&

        insns[i + 1] ==
            0x910042C0u &&

        /*
         * add x0,x22,#0x10
         */

        pxQoLIsBL(
            insns[i + 2]
        );
}


static bool pxqValidateInitialWrapper(
    uint8_t *text,
    unsigned long textSize,
    uintptr_t wrapper
)
{
    const size_t scanSize =
        0x50;

    if (!pxqInText(
            text,
            textSize,
            wrapper,
            scanSize)) {

        return false;
    }

    const uint32_t *insns =
        (const uint32_t *)wrapper;

    const size_t count =
        scanSize /
        sizeof(uint32_t);

    bool savesArguments =
        false;


    /*
     * destination -> x19
     * source      -> x20
     */

    for (size_t i = 0;
         i + 1 < 8 &&
         i + 1 < count;
         i++) {

        if (pxQoLIsMovReg(
                insns[i],
                19,
                1) &&
            pxQoLIsMovReg(
                insns[i + 1],
                20,
                0)) {

            savesArguments =
                true;

            break;
        }
    }

    if (!savesArguments)
        return false;


    /*
     * VWT +0x28 assignment:
     *
     * mov  x2,x0
     * ldur x8,[x0,#-8]
     * ldr  x8,[x8,#0x28]
     * mov  x0,x19
     * mov  x1,x20
     * blr  x8
     * mov  x0,x19
     */

    for (size_t i = 0;
         i + 6 < count;
         i++) {

        uint32_t rt = 0;
        uint32_t rn = 0;
        uint32_t imm12 = 0;

        if (!pxQoLIsMovReg(
                insns[i],
                2,
                0) ||

            insns[i + 1] !=
                0xF85F8008u ||

            !pxQoLIsLDR64UnsignedImm(
                insns[i + 2],
                &rt,
                &rn,
                &imm12) ||

            rt != 8 ||
            rn != 8 ||
            imm12 != 5 ||

            /*
             * 0x28 / 8 = 5
             */

            !pxQoLIsMovReg(
                insns[i + 3],
                0,
                19) ||

            !pxQoLIsMovReg(
                insns[i + 4],
                1,
                20) ||

            insns[i + 5] !=
                0xD63F0100u ||

            /*
             * blr x8
             */

            !pxQoLIsMovReg(
                insns[i + 6],
                0,
                19)) {

            continue;
        }

        return true;
    }

    return false;
}


static size_t
pxqFindMetadataAccessorNearCallsite(
    uint8_t *text,
    unsigned long textSize,
    uintptr_t callsite,
    uintptr_t *accessor
)
{
    const uint32_t *insns =
        (const uint32_t *)text;

    const size_t count =
        textSize /
        sizeof(uint32_t);

    const size_t callIndex =
        (size_t)(
            callsite -
            (uintptr_t)text
        ) /
        sizeof(uint32_t);

    const size_t searchBack =
        0x200 /
        sizeof(uint32_t);

    const size_t start =
        callIndex > searchBack
            ? callIndex - searchBack
            : 0;

    size_t matchCount =
        0;

    uintptr_t found =
        0;


    for (size_t i = start;
         i + 9 < callIndex &&
         i + 9 < count;
         i++) {

        uint32_t rt = 0;
        uint32_t rn = 0;
        uint32_t imm12 = 0;

        uintptr_t target =
            0;


        /*
         * PixivOAuthUser metadata use:
         *
         * mov  x0,#0
         * bl   metadataAccessor
         * mov  x21,x0
         * ldur x8,[x0,#-8]
         * ldr  x23,[x8,#0x38]
         * mov  x0,x25
         * mov  x1,x20
         * mov  w2,#1
         * mov  x3,x21
         * blr  x23
         */

        if (insns[i] !=
                0xD2800000u ||

            !pxQoLIsBL(
                insns[i + 1]) ||

            !pxQoLIsMovReg(
                insns[i + 2],
                21,
                0) ||

            insns[i + 3] !=
                0xF85F8008u ||

            !pxQoLIsLDR64UnsignedImm(
                insns[i + 4],
                &rt,
                &rn,
                &imm12) ||

            rt != 23 ||
            rn != 8 ||
            imm12 != 7 ||

            /*
             * 0x38 / 8 = 7
             */

            !pxQoLIsMovReg(
                insns[i + 5],
                0,
                25) ||

            !pxQoLIsMovReg(
                insns[i + 6],
                1,
                20) ||

            insns[i + 7] !=
                0x52800022u ||

            /*
             * mov w2,#1
             */

            !pxQoLIsMovReg(
                insns[i + 8],
                3,
                21) ||

            insns[i + 9] !=
                0xD63F02E0u) {

            /*
             * blr x23
             */

            continue;
        }


        if (!pxQoLDecodeBLTarget(
                insns[i + 1],
                (uintptr_t)&insns[i + 1],
                &target) ||

            !pxqInText(
                text,
                textSize,
                target,
                sizeof(uint32_t))) {

            continue;
        }


        matchCount++;

        found =
            target;

        pxQoLLog(
            @"[PixivOAuthUser/Finder] metadata pattern hit: callsite=text+0x%llx pattern=text+0x%llx accessor=text+0x%llx",
            (unsigned long long)(
                callsite -
                (uintptr_t)text
            ),
            (unsigned long long)(
                (uintptr_t)&insns[i] -
                (uintptr_t)text
            ),
            (unsigned long long)(
                target -
                (uintptr_t)text
            )
        );
    }


    if (matchCount == 1 &&
        accessor) {

        *accessor =
            found;
    }

    return matchCount;
}


bool pxQoLFindPixivOAuthUserMatch(
    uint8_t *text,
    unsigned long textSize,
    pxQoLPixivOAuthUserMatch *result
)
{
    if (!text ||
        textSize == 0 ||
        !result) {

        return false;
    }


    /*
     * Failures must not leave stale targets in result.
     */

    memset(
        result,
        0,
        sizeof(*result)
    );


    pxQoLPixivOAuthUserMatch match;

    memset(
        &match,
        0,
        sizeof(match)
    );


    const uint32_t *insns =
        (const uint32_t *)text;

    const size_t count =
        textSize /
        sizeof(uint32_t);


    pxQoLLog(
        @"[PixivOAuthUser/Finder] text=%p textSize=0x%lx instructionCount=%zu",
        text,
        textSize,
        count
    );


    /*
     * ---------------------------------------------------------
     * Patch A
     * Initial writer(s)
     * ---------------------------------------------------------
     */

    uintptr_t sharedWrapper =
        0;

    size_t initialContextHitCount =
        0;

    size_t initialDecodedWrapperCount =
        0;

    size_t initialValidWrapperCount =
        0;


    for (size_t i = 7;
         i + 2 < count;
         i++) {

        uintptr_t wrapper =
            0;

        uintptr_t callsite =
            (uintptr_t)&insns[i];


        if (!pxqValidateInitialContext(
                insns,
                count,
                i)) {

            continue;
        }


        initialContextHitCount++;


        pxQoLLog(
            @"[PixivOAuthUser/Finder] initial context hit #%zu: callsite=text+0x%llx address=%p",
            initialContextHitCount,
            (unsigned long long)(
                callsite -
                (uintptr_t)text
            ),
            (void *)callsite
        );


        if (!pxQoLDecodeBLTarget(
                insns[i],
                callsite,
                &wrapper)) {

            pxQoLLog(
                @"[PixivOAuthUser/Finder] initial context rejected: BL decode failed at text+0x%llx",
                (unsigned long long)(
                    callsite -
                    (uintptr_t)text
                )
            );

            continue;
        }


        initialDecodedWrapperCount++;


        pxQoLLog(
            @"[PixivOAuthUser/Finder] initial BL decoded: callsite=text+0x%llx wrapper=%p",
            (unsigned long long)(
                callsite -
                (uintptr_t)text
            ),
            (void *)wrapper
        );


        if (!pxqValidateInitialWrapper(
                text,
                textSize,
                wrapper)) {

            pxQoLLog(
                @"[PixivOAuthUser/Finder] initial wrapper rejected: callsite=text+0x%llx wrapper=%p",
                (unsigned long long)(
                    callsite -
                    (uintptr_t)text
                ),
                (void *)wrapper
            );

            continue;
        }


        initialValidWrapperCount++;


        pxQoLLog(
            @"[PixivOAuthUser/Finder] initial wrapper VALID: callsite=text+0x%llx wrapper=text+0x%llx",
            (unsigned long long)(
                callsite -
                (uintptr_t)text
            ),
            (unsigned long long)(
                wrapper -
                (uintptr_t)text
            )
        );


        /*
         * Known valid structure:
         * 1 or 2 callsites only.
         */

        if (match.initialCallsiteCount >=
            PXQ_PIXIV_OAUTH_USER_MAX_INITIAL_CALLSITES) {

            pxQoLLog(
                @"[PixivOAuthUser/Finder] FAIL A1: more than %d valid initial callsites",
                PXQ_PIXIV_OAUTH_USER_MAX_INITIAL_CALLSITES
            );

            return false;
        }


        if (sharedWrapper != 0 &&
            wrapper != sharedWrapper) {

            pxQoLLog(
                @"[PixivOAuthUser/Finder] FAIL A2: initial callsites use different wrappers: first=%p current=%p",
                (void *)sharedWrapper,
                (void *)wrapper
            );

            return false;
        }


        sharedWrapper =
            wrapper;


        match.initialCallsites[
            match.initialCallsiteCount
        ] =
            callsite;


        match.initialCallsiteCount++;
    }


    pxQoLLog(
        @"[PixivOAuthUser/Finder] Patch A summary: contextHits=%zu decodedWrappers=%zu validWrappers=%zu accepted=%zu",
        initialContextHitCount,
        initialDecodedWrapperCount,
        initialValidWrapperCount,
        match.initialCallsiteCount
    );


    if (match.initialCallsiteCount == 0) {
        pxQoLLog(
            @"[PixivOAuthUser/Finder] FAIL A3: no valid initial writer"
        );

        return false;
    }


    match.initialOriginalWrapper =
        sharedWrapper;


    pxQoLLog(
        @"[PixivOAuthUser/Finder] Patch A resolved: callsites=%zu wrapper=text+0x%llx",
        match.initialCallsiteCount,
        (unsigned long long)(
            match.initialOriginalWrapper -
            (uintptr_t)text
        )
    );


    /*
     * ---------------------------------------------------------
     * PixivOAuthUser metadata accessor
     * ---------------------------------------------------------
     *
     * One qualified path may contain the direct metadata
     * use while another continuation path may not.
     *
     * Every discovered accessor must agree.
     */

    uintptr_t metadataAccessor =
        0;


    for (size_t i = 0;
         i < match.initialCallsiteCount;
         i++) {

        uintptr_t candidate =
            0;


        size_t found =
            pxqFindMetadataAccessorNearCallsite(
                text,
                textSize,
                match.initialCallsites[i],
                &candidate
            );


        pxQoLLog(
            @"[PixivOAuthUser/Finder] metadata search initial[%zu]: callsite=text+0x%llx matches=%zu candidate=%p",
            i,
            (unsigned long long)(
                match.initialCallsites[i] -
                (uintptr_t)text
            ),
            found,
            (void *)candidate
        );


        if (found > 1) {
            pxQoLLog(
                @"[PixivOAuthUser/Finder] FAIL M1: metadata accessor is not unique near initial[%zu]",
                i
            );

            return false;
        }


        if (found == 0)
            continue;


        if (metadataAccessor != 0 &&
            candidate != metadataAccessor) {

            pxQoLLog(
                @"[PixivOAuthUser/Finder] FAIL M2: metadata accessors disagree: first=%p current=%p",
                (void *)metadataAccessor,
                (void *)candidate
            );

            return false;
        }


        metadataAccessor =
            candidate;
    }


    if (metadataAccessor == 0) {
        pxQoLLog(
            @"[PixivOAuthUser/Finder] FAIL M3: metadata accessor not found"
        );

        return false;
    }


    match.metadataAccessor =
        metadataAccessor;


    pxQoLLog(
        @"[PixivOAuthUser/Finder] metadata accessor resolved: text+0x%llx",
        (unsigned long long)(
            match.metadataAccessor -
            (uintptr_t)text
        )
    );


    /*
     * ---------------------------------------------------------
     * Patch B
     * Later PixivOAuthUser assignment
     * ---------------------------------------------------------
     *
     * Do not search the six-field-copy sequence globally.
     * The device run proved that sequence occurs in multiple
     * Swift assignment functions.
     *
     * First identify the confirmed assignment-function shape:
     *
     * stp  x22,x21,[sp,#-0x30]!
     * stp  x20,x19,[sp,#0x10]
     * stp  x29,x30,[sp,#0x20]
     * add  x29,sp,#0x20
     * mov  x21,x2
     * mov  x20,x1
     * mov  x19,x0
     * ldr  q0,[x1]
     * str  q0,[x0]
     *
     * Then search only inside that function for:
     *
     * ldpsw x8,x9,[x21,#0x24]
     * ldrb  w10,[x20,x8]
     * strb  w10,[x19,x8]
     * ldrb  w8,[x20,x9]      <- patch target
     * strb  w8,[x19,x9]
     * ldpsw x8,x9,[x21,#0x2c]
     */

    static const uint32_t laterAssignmentPrologue[] = {
        0xA9BD57F6u,
        0xA9014FF4u,
        0xA9027BFDu,
        0x910083FDu,
        0xAA0203F5u,
        0xAA0103F4u,
        0xAA0003F3u,
        0x3DC00020u,
        0x3D800000u
    };


    static const uint32_t laterSequence[] = {
        0x6944A6A8u,
        0x38686A8Au,
        0x38286A6Au,
        0x38696A88u,
        0x38296A68u,
        0x6945A6A8u
    };


    const size_t laterFunctionScanCount =
        0x180 /
        sizeof(uint32_t);


    size_t laterPrologueHitCount =
        0;

    size_t laterAssignmentMatchCount =
        0;


    for (size_t i = 0;
         i +
            (
                sizeof(laterAssignmentPrologue) /
                sizeof(laterAssignmentPrologue[0])
            ) <= count;
         i++) {

        if (memcmp(
                &insns[i],
                laterAssignmentPrologue,
                sizeof(laterAssignmentPrologue)) != 0) {

            continue;
        }


        laterPrologueHitCount++;


        uintptr_t functionStart =
            (uintptr_t)&insns[i];


        pxQoLLog(
            @"[PixivOAuthUser/Finder] Patch B assignment prologue hit #%zu: function=text+0x%llx",
            laterPrologueHitCount,
            (unsigned long long)(
                functionStart -
                (uintptr_t)text
            )
        );


        size_t end =
            i +
            laterFunctionScanCount;

        if (end > count)
            end = count;


        size_t localSequenceCount =
            0;

        uintptr_t localPremiumLoad =
            0;


        for (size_t j =
                 i +
                 (
                     sizeof(laterAssignmentPrologue) /
                     sizeof(laterAssignmentPrologue[0])
                 );
             j + 6 <= end;
             j++) {

            /*
             * Stop at the end of this function.
             *
             * ret
             */
            if (insns[j] ==
                0xD65F03C0u) {

                break;
            }


            if (memcmp(
                    &insns[j],
                    laterSequence,
                    sizeof(laterSequence)) != 0) {

                continue;
            }


            localSequenceCount++;


            /*
             * Fourth instruction:
             *
             * ldrb w8,[x20,x9]
             */
            localPremiumLoad =
                (uintptr_t)&insns[
                    j + 3
                ];


            pxQoLLog(
                @"[PixivOAuthUser/Finder] Patch B local sequence hit: function=text+0x%llx sequence=text+0x%llx premiumLoad=text+0x%llx",
                (unsigned long long)(
                    functionStart -
                    (uintptr_t)text
                ),
                (unsigned long long)(
                    (uintptr_t)&insns[j] -
                    (uintptr_t)text
                ),
                (unsigned long long)(
                    localPremiumLoad -
                    (uintptr_t)text
                )
            );
        }


        pxQoLLog(
            @"[PixivOAuthUser/Finder] Patch B function summary: function=text+0x%llx localSequences=%zu",
            (unsigned long long)(
                functionStart -
                (uintptr_t)text
            ),
            localSequenceCount
        );


        /*
         * A qualified assignment function must contain exactly
         * one confirmed premium-copy sequence.
         */
        if (localSequenceCount != 1)
            continue;


        laterAssignmentMatchCount++;


        if (laterAssignmentMatchCount > 1) {
            pxQoLLog(
                @"[PixivOAuthUser/Finder] FAIL B1: more than one qualified later assignment function"
            );

            return false;
        }


        match.laterPremiumLoad =
            localPremiumLoad;
    }


    pxQoLLog(
        @"[PixivOAuthUser/Finder] Patch B summary: prologueHits=%zu qualifiedAssignments=%zu",
        laterPrologueHitCount,
        laterAssignmentMatchCount
    );


    if (laterAssignmentMatchCount != 1) {
        pxQoLLog(
            @"[PixivOAuthUser/Finder] FAIL B2: expected exactly 1 qualified later assignment, got %zu",
            laterAssignmentMatchCount
        );

        return false;
    }


    pxQoLLog(
        @"[PixivOAuthUser/Finder] Patch B resolved: premiumLoad=text+0x%llx",
        (unsigned long long)(
            match.laterPremiumLoad -
            (uintptr_t)text
        )
    );


    *result =
        match;


    pxQoLLog(
        @"[PixivOAuthUser/Finder] SUCCESS: initial=%zu wrapper=text+0x%llx metadata=text+0x%llx laterLoad=text+0x%llx",
        match.initialCallsiteCount,
        (unsigned long long)(
            match.initialOriginalWrapper -
            (uintptr_t)text
        ),
        (unsigned long long)(
            match.metadataAccessor -
            (uintptr_t)text
        ),
        (unsigned long long)(
            match.laterPremiumLoad -
            (uintptr_t)text
        )
    );


    return true;
}