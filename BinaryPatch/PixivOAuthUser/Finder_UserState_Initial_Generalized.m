#import "Finder_UserState_Initial_Internal.h"
#import "../Core/pxQoLARM64.h"
#import "../../LogHelper.h"

#include <string.h>


static bool pxqValidateInitialUserStateWrapper(
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

        uint32_t ldurRt = 0;
        uint32_t ldurRn = 0;
        int32_t ldurImm = 0;

        uint32_t blrRn = 0;

        if (!pxQoLIsMovReg(
                insns[i],
                2,
                0) ||

            !pxQoLDecodeLDUR64(
                insns[i + 1],
                &ldurRt,
                &ldurRn,
                &ldurImm) ||

            ldurRt != 8 ||
            ldurRn != 0 ||
            ldurImm != -8 ||

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

            !pxQoLDecodeBLR(
                insns[i + 5],
                &blrRn) ||

            blrRn != 8 ||

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


typedef struct {
    uintptr_t callsite;
    uintptr_t wrapper;

    uint32_t baseReg;
    uint32_t offsetReg;
    uint32_t sourceReg;
    uint32_t accessReg;
} pxqGeneralizedInitialUserStateCandidate;


static bool pxqValidateInitialUserStateContextGeneralized(
    const uint32_t *insns,
    size_t count,
    size_t i,
    pxqGeneralizedInitialUserStateCandidate *candidate
)
{
    if (!insns ||
        !candidate ||
        i < 7 ||
        i + 2 >= count) {

        return false;
    }


    uint32_t firstRd = 0;
    uint32_t baseReg = 0;
    uint32_t offsetReg = 0;

    uint32_t beginRd = 0;
    uint32_t accessReg = 0;
    uint32_t beginImm = 0;

    uint32_t secondRd = 0;
    uint32_t baseReg2 = 0;
    uint32_t offsetReg2 = 0;

    uint32_t movRd = 0;
    uint32_t sourceReg = 0;

    uint32_t endRd = 0;
    uint32_t accessReg2 = 0;
    uint32_t endImm = 0;


    /*
     * Register-independent version of the proven InitialUserState
     * 10-instruction context:
     *
     * add x0, BASE, OFFSET
     * add x1, ACCESS, #0x10
     * mov w2, #0x21
     * mov x3, #0
     * bl  ...
     * add x1, BASE, OFFSET
     * mov x0, SOURCE
     * bl  <wrapper>           <- i
     * add x0, ACCESS, #0x10
     * bl  ...
     */

    if (!pxQoLDecodeADD64RegisterNoShift(
            insns[i - 7],
            &firstRd,
            &baseReg,
            &offsetReg) ||

        firstRd != 0 ||

        !pxQoLDecodeADD64ImmediateNoShift(
            insns[i - 6],
            &beginRd,
            &accessReg,
            &beginImm) ||

        beginRd != 1 ||
        beginImm != 0x10 ||

        insns[i - 5] !=
            0x52800422u ||

        /*
         * mov w2,#0x21
         */

        insns[i - 4] !=
            0xD2800003u ||

        /*
         * mov x3,#0
         */

        !pxQoLIsBL(
            insns[i - 3]) ||

        !pxQoLDecodeADD64RegisterNoShift(
            insns[i - 2],
            &secondRd,
            &baseReg2,
            &offsetReg2) ||

        secondRd != 1 ||
        baseReg2 != baseReg ||
        offsetReg2 != offsetReg ||

        !pxQoLDecodeMovReg(
            insns[i - 1],
            &movRd,
            &sourceReg) ||

        movRd != 0 ||

        !pxQoLIsBL(
            insns[i]) ||

        !pxQoLDecodeADD64ImmediateNoShift(
            insns[i + 1],
            &endRd,
            &accessReg2,
            &endImm) ||

        endRd != 0 ||
        accessReg2 != accessReg ||
        endImm != 0x10 ||

        !pxQoLIsBL(
            insns[i + 2])) {

        return false;
    }


    /*
     * SP/ZR are not valid stored-value registers here.
     */
    if (baseReg == 31 ||
        offsetReg == 31 ||
        sourceReg == 31 ||
        accessReg == 31) {

        return false;
    }


    memset(
        candidate,
        0,
        sizeof(*candidate)
    );

    candidate->baseReg =
        baseReg;

    candidate->offsetReg =
        offsetReg;

    candidate->sourceReg =
        sourceReg;

    candidate->accessReg =
        accessReg;

    return true;
}


typedef enum {
    PXQ_GENERALIZED_METADATA_VARIANT_A = 1,
    PXQ_GENERALIZED_METADATA_VARIANT_B = 2
} pxqGeneralizedMetadataVariant;


typedef struct {
    pxqGeneralizedMetadataVariant variant;

    uintptr_t accessor;

    uint32_t metadataReg;
    uint32_t witnessReg;

    /*
     * Variant A:
     *     value = BASE + OFFSET
     */
    uint32_t valueBaseReg;
    uint32_t valueOffsetReg;

    /*
     * Variant B:
     *     x0 <- VALUE
     *     x1 <- OFFSET
     */
    uint32_t valueReg;
    uint32_t offsetArgReg;
} pxqGeneralizedMetadataGate;


static bool pxqParseGeneralizedMetadataPrefix(
    uint8_t *text,
    unsigned long textSize,
    const uint32_t *insns,
    size_t count,
    size_t i,
    pxqGeneralizedMetadataGate *gate
)
{
    if (!text ||
        !insns ||
        !gate ||
        i + 4 >= count) {

        return false;
    }


    uint32_t metadataReg = 0;
    uint32_t metadataSource = 0;

    uint32_t vwtReg = 0;
    uint32_t ldurBase = 0;
    int32_t ldurImm = 0;

    uint32_t witnessReg = 0;
    uint32_t witnessBase = 0;
    uint32_t witnessImm12 = 0;

    uintptr_t target = 0;


    /*
     * Shared metadata prefix:
     *
     * mov  x0,#0
     * bl   initialUserStateMetadataAccessor
     * mov  xMETA,x0
     * ldur xVWT,[x0,#-8]
     * ldr  xWITNESS,[xVWT,#0x38]
     */

    if (insns[i] !=
            0xD2800000u ||

        /*
         * mov x0,#0
         */

        !pxQoLIsBL(
            insns[i + 1]) ||

        !pxQoLDecodeMovReg(
            insns[i + 2],
            &metadataReg,
            &metadataSource) ||

        metadataSource != 0 ||

        !pxQoLDecodeLDUR64(
            insns[i + 3],
            &vwtReg,
            &ldurBase,
            &ldurImm) ||

        ldurBase != 0 ||
        ldurImm != -8 ||

        !pxQoLIsLDR64UnsignedImm(
            insns[i + 4],
            &witnessReg,
            &witnessBase,
            &witnessImm12) ||

        witnessBase != vwtReg ||
        witnessImm12 != 7) {

        return false;
    }


    /*
     * 0x38 / 8 = 7
     */

    if (metadataReg == 31 ||
        vwtReg == 31 ||
        witnessReg == 31) {

        return false;
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

        return false;
    }


    memset(
        gate,
        0,
        sizeof(*gate)
    );

    gate->accessor =
        target;

    gate->metadataReg =
        metadataReg;

    gate->witnessReg =
        witnessReg;

    return true;
}


static bool pxqParseGeneralizedMetadataVariantA(
    uint8_t *text,
    unsigned long textSize,
    const uint32_t *insns,
    size_t count,
    size_t i,
    pxqGeneralizedMetadataGate *gate
)
{
    if (!gate ||
        i + 8 >= count) {

        return false;
    }


    pxqGeneralizedMetadataGate parsed;

    if (!pxqParseGeneralizedMetadataPrefix(
            text,
            textSize,
            insns,
            count,
            i,
            &parsed)) {

        return false;
    }


    uint32_t valueRd = 0;
    uint32_t baseReg = 0;
    uint32_t offsetReg = 0;

    uint32_t blrReg = 0;


    /*
     * Variant A, proven on 8.6.9:
     *
     * mov  x0,#0
     * bl   initialUserStateMetadataAccessor
     * mov  xMETA,x0
     * ldur xVWT,[x0,#-8]
     * ldr  xWITNESS,[xVWT,#0x38]
     * add  x0,BASE,OFFSET
     * mov  w1,#1
     * mov  w2,#1
     * blr  xWITNESS
     *
     * Production correlation requires:
     *
     *     BASE   == InitialUserState BASE
     *     OFFSET == InitialUserState OFFSET
     */

    if (!pxQoLDecodeADD64RegisterNoShift(
            insns[i + 5],
            &valueRd,
            &baseReg,
            &offsetReg) ||

        valueRd != 0 ||

        insns[i + 6] !=
            0x52800021u ||

        /*
         * mov w1,#1
         */

        insns[i + 7] !=
            0x52800022u ||

        /*
         * mov w2,#1
         */

        !pxQoLDecodeBLR(
            insns[i + 8],
            &blrReg) ||

        blrReg != parsed.witnessReg) {

        return false;
    }


    if (baseReg == 31 ||
        offsetReg == 31) {

        return false;
    }


    parsed.variant =
        PXQ_GENERALIZED_METADATA_VARIANT_A;

    parsed.valueBaseReg =
        baseReg;

    parsed.valueOffsetReg =
        offsetReg;

    *gate =
        parsed;

    return true;
}


static bool pxqParseGeneralizedMetadataVariantB(
    uint8_t *text,
    unsigned long textSize,
    const uint32_t *insns,
    size_t count,
    size_t i,
    pxqGeneralizedMetadataGate *gate
)
{
    if (!gate ||
        i + 9 >= count) {

        return false;
    }


    pxqGeneralizedMetadataGate parsed;

    if (!pxqParseGeneralizedMetadataPrefix(
            text,
            textSize,
            insns,
            count,
            i,
            &parsed)) {

        return false;
    }


    uint32_t arg0Dst = 0;
    uint32_t valueReg = 0;

    uint32_t arg1Dst = 0;
    uint32_t offsetArgReg = 0;

    uint32_t metadataArgDst = 0;
    uint32_t metadataArgSrc = 0;

    uint32_t blrReg = 0;


    /*
     * Variant B, proven on 8.8.1:
     *
     * mov  x0,#0
     * bl   initialUserStateMetadataAccessor
     * mov  xMETA,x0
     * ldur xVWT,[x0,#-8]
     * ldr  xWITNESS,[xVWT,#0x38]
     * mov  x0,VALUE
     * mov  x1,OFFSET
     * mov  w2,#1
     * mov  x3,xMETA
     * blr  xWITNESS
     *
     * Production correlation requires:
     *
     *     OFFSET == InitialUserState OFFSET
     *
     * x3 must carry the metadata returned by the accessor.
     * VALUE is deliberately not tied to a fixed physical
     * register because the verified evidence does not justify
     * such a constraint.
     */

    if (!pxQoLDecodeMovReg(
            insns[i + 5],
            &arg0Dst,
            &valueReg) ||

        arg0Dst != 0 ||

        !pxQoLDecodeMovReg(
            insns[i + 6],
            &arg1Dst,
            &offsetArgReg) ||

        arg1Dst != 1 ||

        insns[i + 7] !=
            0x52800022u ||

        /*
         * mov w2,#1
         */

        !pxQoLDecodeMovReg(
            insns[i + 8],
            &metadataArgDst,
            &metadataArgSrc) ||

        metadataArgDst != 3 ||
        metadataArgSrc !=
            parsed.metadataReg ||

        !pxQoLDecodeBLR(
            insns[i + 9],
            &blrReg) ||

        blrReg != parsed.witnessReg) {

        return false;
    }


    if (valueReg == 31 ||
        offsetArgReg == 31) {

        return false;
    }


    parsed.variant =
        PXQ_GENERALIZED_METADATA_VARIANT_B;

    parsed.valueReg =
        valueReg;

    parsed.offsetArgReg =
        offsetArgReg;

    *gate =
        parsed;

    return true;
}


bool pxqResolveGeneralizedInitialUserStateAndMetadata(
    uint8_t *text,
    unsigned long textSize,
    pxQoLPixivOAuthUserInitialUserStateMatch *match
)
{
    if (!text ||
        textSize == 0 ||
        !match) {

        return false;
    }


    const uint32_t *insns =
        (const uint32_t *)text;

    const size_t count =
        textSize /
        sizeof(uint32_t);


    /*
     * Structural collection capacity is deliberately larger than
     * the production publish limit.
     *
     * Final production validation is performed only after semantic
     * metadata correlation. This allows unrelated structural
     * lookalikes to be discarded before the 1..2/shared-wrapper
     * requirements are applied.
     */
    enum {
        PXQ_GENERALIZED_MAX_STRUCTURAL_CANDIDATES = 64
    };


    pxqGeneralizedInitialUserStateCandidate structuralCandidates[
        PXQ_GENERALIZED_MAX_STRUCTURAL_CANDIDATES
    ];

    memset(
        structuralCandidates,
        0,
        sizeof(structuralCandidates)
    );


    size_t rawContextCount =
        0;

    size_t structuralCandidateCount =
        0;

    size_t wrapperRejectedCount =
        0;


    /*
     * ---------------------------------------------------------
     * Phase 1: collect structural InitialUserState candidates
     * ---------------------------------------------------------
     *
     * A candidate must satisfy:
     *
     * - register-independent proven 10-instruction InitialUserState context
     * - BL target resolves into __text
     * - BL target validates as the proven VWT+0x28 assignment wrapper
     *
     * IMPORTANT:
     *
     * Do NOT require all candidates to share one wrapper here.
     * Do NOT apply the production 1..2 candidate limit here.
     *
     * Those constraints are applied only after metadata correlation.
     */

    for (size_t i = 7;
         i + 2 < count;
         i++) {

        pxqGeneralizedInitialUserStateCandidate candidate;

        memset(
            &candidate,
            0,
            sizeof(candidate)
        );


        if (!pxqValidateInitialUserStateContextGeneralized(
                insns,
                count,
                i,
                &candidate)) {

            continue;
        }


        rawContextCount++;


        uintptr_t callsite =
            (uintptr_t)&insns[i];

        uintptr_t wrapper =
            0;


        if (!pxQoLDecodeBLTarget(
                insns[i],
                callsite,
                &wrapper) ||

            !pxqValidateInitialUserStateWrapper(
                text,
                textSize,
                wrapper)) {

            wrapperRejectedCount++;

            continue;
        }


        if (structuralCandidateCount >=
            PXQ_GENERALIZED_MAX_STRUCTURAL_CANDIDATES) {

            pxQoLLog(
                @"[PixivOAuthUser/Finder] GENERALIZED rejected: more than %d structural InitialUserState candidates before metadata correlation",
                PXQ_GENERALIZED_MAX_STRUCTURAL_CANDIDATES
            );

            return false;
        }


        candidate.callsite =
            callsite;

        candidate.wrapper =
            wrapper;


        structuralCandidates[
            structuralCandidateCount
        ] =
            candidate;

        structuralCandidateCount++;


        pxQoLLog(
            @"[PixivOAuthUser/Finder] GENERALIZED InitialUserState structural candidate #%zu: callsite=text+0x%llx wrapper=text+0x%llx destination=x%u+x%u source=x%u",
            structuralCandidateCount,
            (unsigned long long)(
                callsite -
                (uintptr_t)text
            ),
            (unsigned long long)(
                wrapper -
                (uintptr_t)text
            ),
            candidate.baseReg,
            candidate.offsetReg,
            candidate.sourceReg
        );
    }


    pxQoLLog(
        @"[PixivOAuthUser/Finder] GENERALIZED InitialUserState collection summary: rawContexts=%zu structuralCandidates=%zu wrapperRejected=%zu",
        rawContextCount,
        structuralCandidateCount,
        wrapperRejectedCount
    );


    if (structuralCandidateCount == 0) {

        pxQoLLog(
            @"[PixivOAuthUser/Finder] GENERALIZED rejected: no structural InitialUserState candidate survived wrapper validation"
        );

        return false;
    }


    /*
     * ---------------------------------------------------------
     * Phase 2: semantic metadata correlation
     * ---------------------------------------------------------
     *
     * Search only in the confirmed 0x200-byte window preceding
     * each structural InitialUserState callsite.
     *
     * Variant A, proven on 8.6.9 and 8.4.8:
     *
     *     InitialUserState destination = BASE + OFFSET
     *     metadata gate value = SAME_BASE + SAME_OFFSET
     *
     * Variant B, proven on 8.8.1:
     *
     *     InitialUserState destination uses OFFSET
     *     metadata witness x1 receives SAME_OFFSET
     *     metadata witness x3 receives xMETA
     *
     * A structural candidate is promoted to a correlated production
     * candidate only when:
     *
     * - at least one semantic Variant A/B gate matches
     * - all matching gates for that candidate resolve to one accessor
     *
     * Candidates with no semantic match are ignored.
     * Candidates with internally disagreeing accessors are not promoted.
     */

    const size_t searchBack =
        0x200 /
        sizeof(uint32_t);


    pxqGeneralizedInitialUserStateCandidate correlatedCandidates[
        PXQ_PIXIV_OAUTH_USER_MAX_INITIAL_USER_STATE_CALLSITES
    ];

    uintptr_t correlatedAccessors[
        PXQ_PIXIV_OAUTH_USER_MAX_INITIAL_USER_STATE_CALLSITES
    ];

    memset(
        correlatedCandidates,
        0,
        sizeof(correlatedCandidates)
    );

    memset(
        correlatedAccessors,
        0,
        sizeof(correlatedAccessors)
    );


    size_t correlatedCandidateCount =
        0;

    size_t totalStructuralMatches =
        0;

    size_t totalVariantAMatches =
        0;

    size_t totalVariantBMatches =
        0;

    size_t ambiguousCandidateCount =
        0;


    for (size_t c = 0;
         c < structuralCandidateCount;
         c++) {

        const pxqGeneralizedInitialUserStateCandidate *candidate =
            &structuralCandidates[c];


        const size_t callIndex =
            (size_t)(
                candidate->callsite -
                (uintptr_t)text
            ) /
            sizeof(uint32_t);


        const size_t start =
            callIndex > searchBack
                ? callIndex - searchBack
                : 0;


        size_t localStructuralMatches =
            0;

        size_t localVariantAMatches =
            0;

        size_t localVariantBMatches =
            0;

        uintptr_t localAccessor =
            0;

        bool localAccessorAmbiguous =
            false;


        for (size_t i = start;
             i + 4 < callIndex &&
             i + 4 < count;
             i++) {

            pxqGeneralizedMetadataGate gate;

            memset(
                &gate,
                0,
                sizeof(gate)
            );


            bool matched =
                false;


            /*
             * Variant A:
             * BASE+OFFSET must match InitialUserState exactly.
             */

            if (i + 8 < callIndex &&
                i + 8 < count &&
                pxqParseGeneralizedMetadataVariantA(
                    text,
                    textSize,
                    insns,
                    count,
                    i,
                    &gate) &&

                gate.valueBaseReg ==
                    candidate->baseReg &&

                gate.valueOffsetReg ==
                    candidate->offsetReg) {

                matched =
                    true;

                localVariantAMatches++;
                totalVariantAMatches++;


                pxQoLLog(
                    @"[PixivOAuthUser/Finder] GENERALIZED metadata Variant A match: initial=text+0x%llx wrapper=text+0x%llx gate=text+0x%llx accessor=text+0x%llx value=x%u+x%u",
                    (unsigned long long)(
                        candidate->callsite -
                        (uintptr_t)text
                    ),
                    (unsigned long long)(
                        candidate->wrapper -
                        (uintptr_t)text
                    ),
                    (unsigned long long)(
                        (uintptr_t)&insns[i] -
                        (uintptr_t)text
                    ),
                    (unsigned long long)(
                        gate.accessor -
                        (uintptr_t)text
                    ),
                    gate.valueBaseReg,
                    gate.valueOffsetReg
                );
            }


            /*
             * Variant B:
             * x1 must receive the same OFFSET register used
             * by InitialUserState.
             *
             * Only try Variant B if Variant A did not already
             * accept this gate.
             */

            if (!matched) {

                memset(
                    &gate,
                    0,
                    sizeof(gate)
                );


                if (i + 9 < callIndex &&
                    i + 9 < count &&
                    pxqParseGeneralizedMetadataVariantB(
                        text,
                        textSize,
                        insns,
                        count,
                        i,
                        &gate) &&

                    gate.offsetArgReg ==
                        candidate->offsetReg) {

                    matched =
                        true;

                    localVariantBMatches++;
                    totalVariantBMatches++;


                    pxQoLLog(
                        @"[PixivOAuthUser/Finder] GENERALIZED metadata Variant B match: initial=text+0x%llx wrapper=text+0x%llx gate=text+0x%llx accessor=text+0x%llx witnessArgs=x0<-x%u x1<-x%u x3<-x%u",
                        (unsigned long long)(
                            candidate->callsite -
                            (uintptr_t)text
                        ),
                        (unsigned long long)(
                            candidate->wrapper -
                            (uintptr_t)text
                        ),
                        (unsigned long long)(
                            (uintptr_t)&insns[i] -
                            (uintptr_t)text
                        ),
                        (unsigned long long)(
                            gate.accessor -
                            (uintptr_t)text
                        ),
                        gate.valueReg,
                        gate.offsetArgReg,
                        gate.metadataReg
                    );
                }
            }


            if (!matched)
                continue;


            localStructuralMatches++;
            totalStructuralMatches++;


            if (localAccessor == 0) {

                localAccessor =
                    gate.accessor;
            }
            else if (gate.accessor !=
                     localAccessor) {

                localAccessorAmbiguous =
                    true;
            }
        }


        if (localStructuralMatches == 0) {

            pxQoLLog(
                @"[PixivOAuthUser/Finder] GENERALIZED metadata summary structural[%zu]: callsite=text+0x%llx wrapper=text+0x%llx structuralMatches=0 variantA=0 variantB=0 correlated=0",
                c,
                (unsigned long long)(
                    candidate->callsite -
                    (uintptr_t)text
                ),
                (unsigned long long)(
                    candidate->wrapper -
                    (uintptr_t)text
                )
            );

            continue;
        }


        if (localAccessorAmbiguous ||
            localAccessor == 0) {

            ambiguousCandidateCount++;

            pxQoLLog(
                @"[PixivOAuthUser/Finder] GENERALIZED metadata summary structural[%zu]: callsite=text+0x%llx wrapper=text+0x%llx structuralMatches=%zu variantA=%zu variantB=%zu correlated=0 accessor=<ambiguous>",
                c,
                (unsigned long long)(
                    candidate->callsite -
                    (uintptr_t)text
                ),
                (unsigned long long)(
                    candidate->wrapper -
                    (uintptr_t)text
                ),
                localStructuralMatches,
                localVariantAMatches,
                localVariantBMatches
            );

            continue;
        }


        correlatedCandidateCount++;


        if (correlatedCandidateCount >
            PXQ_PIXIV_OAUTH_USER_MAX_INITIAL_USER_STATE_CALLSITES) {

            pxQoLLog(
                @"[PixivOAuthUser/Finder] GENERALIZED rejected: more than %d metadata-correlated InitialUserState candidates",
                PXQ_PIXIV_OAUTH_USER_MAX_INITIAL_USER_STATE_CALLSITES
            );

            return false;
        }


        correlatedCandidates[
            correlatedCandidateCount - 1
        ] =
            *candidate;

        correlatedAccessors[
            correlatedCandidateCount - 1
        ] =
            localAccessor;


        pxQoLLog(
            @"[PixivOAuthUser/Finder] GENERALIZED metadata summary structural[%zu]: callsite=text+0x%llx wrapper=text+0x%llx structuralMatches=%zu variantA=%zu variantB=%zu correlated=1 accessor=text+0x%llx",
            c,
            (unsigned long long)(
                candidate->callsite -
                (uintptr_t)text
            ),
            (unsigned long long)(
                candidate->wrapper -
                (uintptr_t)text
            ),
            localStructuralMatches,
            localVariantAMatches,
            localVariantBMatches,
            (unsigned long long)(
                localAccessor -
                (uintptr_t)text
            )
        );
    }


    pxQoLLog(
        @"[PixivOAuthUser/Finder] GENERALIZED metadata total: structuralCandidates=%zu correlatedCandidates=%zu ambiguousCandidates=%zu structuralMatches=%zu variantA=%zu variantB=%zu",
        structuralCandidateCount,
        correlatedCandidateCount,
        ambiguousCandidateCount,
        totalStructuralMatches,
        totalVariantAMatches,
        totalVariantBMatches
    );


    /*
     * ---------------------------------------------------------
     * Phase 3: final production validation
     * ---------------------------------------------------------
     *
     * Apply production invariants ONLY to metadata-correlated
     * candidates:
     *
     * - 1..MAX correlated InitialUserState callsites
     * - all correlated candidates share one validated wrapper
     * - all correlated candidates share one metadata accessor
     */

    if (correlatedCandidateCount == 0) {

        pxQoLLog(
            @"[PixivOAuthUser/Finder] GENERALIZED rejected: no semantic Variant A/B metadata gate correlated with InitialUserState"
        );

        return false;
    }


    uintptr_t sharedWrapper =
        correlatedCandidates[0].wrapper;

    uintptr_t initialUserStateMetadataAccessor =
        correlatedAccessors[0];


    if (sharedWrapper == 0 ||
        initialUserStateMetadataAccessor == 0) {

        return false;
    }


    for (size_t i = 1;
         i < correlatedCandidateCount;
         i++) {

        if (correlatedCandidates[i].wrapper !=
            sharedWrapper) {

            pxQoLLog(
                @"[PixivOAuthUser/Finder] GENERALIZED rejected: metadata-correlated InitialUserState candidates use different wrappers"
            );

            return false;
        }


        if (correlatedAccessors[i] !=
            initialUserStateMetadataAccessor) {

            pxQoLLog(
                @"[PixivOAuthUser/Finder] GENERALIZED rejected: metadata-correlated InitialUserState candidates use different metadata accessors"
            );

            return false;
        }
    }


    /*
     * Publish only after all three phases succeed.
     */

    match->callsiteCount =
        correlatedCandidateCount;


    for (size_t i = 0;
         i < correlatedCandidateCount;
         i++) {

        match->callsites[i] =
            correlatedCandidates[i].callsite;
    }


    match->originalWrapper =
        sharedWrapper;

    match->pixivOAuthUserMetadataAccessor =
        initialUserStateMetadataAccessor;


    pxQoLLog(
        @"[PixivOAuthUser/Finder] GENERALIZED resolved: structuralCandidates=%zu correlatedCallsites=%zu wrapper=text+0x%llx metadata=text+0x%llx structuralMetadataMatches=%zu variantA=%zu variantB=%zu",
        structuralCandidateCount,
        match->callsiteCount,
        (unsigned long long)(
            match->originalWrapper -
            (uintptr_t)text
        ),
        (unsigned long long)(
            match->pixivOAuthUserMetadataAccessor -
            (uintptr_t)text
        ),
        totalStructuralMatches,
        totalVariantAMatches,
        totalVariantBMatches
    );


    return true;
}


