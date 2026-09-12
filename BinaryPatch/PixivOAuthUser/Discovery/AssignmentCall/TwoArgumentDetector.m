#import "AssignmentCallDiscoveryInternal.h"
#import "../../../Core/ARM64.h"
#import "../../../Core/MemoryAccess.h"
#import "../../../SwiftABI/ValueWitness.h"
#import "../../../../LogHelper.h"

#include <string.h>


static bool pxqValidateTwoArgumentTakeAssignmentWrapper(
    uint8_t *text,
    unsigned long textSize,
    uintptr_t wrapper
)
{
    const size_t scanSize =
        0x50;

    if (!pxqAddressRangeContains(
            (uintptr_t)text,
            (size_t)textSize,
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

        if (pxqARM64IsMoveRegister(
                insns[i],
                19,
                1) &&
            pxqARM64IsMoveRegister(
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

        if (!pxqARM64IsMoveRegister(
                insns[i],
                2,
                0) ||

            !pxqARM64DecodeLDUR64(
                insns[i + 1],
                &ldurRt,
                &ldurRn,
                &ldurImm) ||

            ldurRt != 8 ||
            ldurRn != 0 ||
            ldurImm !=
                PXQ_SWIFT_VALUE_WITNESS_TABLE_METADATA_RELATIVE_OFFSET ||

            !pxqARM64IsLDR64UnsignedImmediate(
                insns[i + 2],
                &rt,
                &rn,
                &imm12) ||

            rt != 8 ||
            rn != 8 ||
            imm12 !=
                PXQ_SWIFT_VALUE_WITNESS_ASSIGN_WITH_TAKE_POINTER_INDEX ||

            /*
             * 0x28 / 8 = 5
             */

            !pxqARM64IsMoveRegister(
                insns[i + 3],
                0,
                19) ||

            !pxqARM64IsMoveRegister(
                insns[i + 4],
                1,
                20) ||

            !pxqARM64DecodeBLR(
                insns[i + 5],
                &blrRn) ||

            blrRn != 8 ||

            !pxqARM64IsMoveRegister(
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
} PXQTwoArgumentAssignmentCallCandidate;


static bool pxqParseTwoArgumentAssignmentCallCandidate(
    const uint32_t *insns,
    size_t count,
    size_t i,
    PXQTwoArgumentAssignmentCallCandidate *candidate
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
     * Register-independent version of the proven AssignmentCall
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

    if (!pxqARM64DecodeADD64RegisterNoShift(
            insns[i - 7],
            &firstRd,
            &baseReg,
            &offsetReg) ||

        firstRd != 0 ||

        !pxqARM64DecodeADD64ImmediateNoShift(
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

        !pxqARM64IsBL(
            insns[i - 3]) ||

        !pxqARM64DecodeADD64RegisterNoShift(
            insns[i - 2],
            &secondRd,
            &baseReg2,
            &offsetReg2) ||

        secondRd != 1 ||
        baseReg2 != baseReg ||
        offsetReg2 != offsetReg ||

        !pxqARM64DecodeMoveRegister(
            insns[i - 1],
            &movRd,
            &sourceReg) ||

        movRd != 0 ||

        !pxqARM64IsBL(
            insns[i]) ||

        !pxqARM64DecodeADD64ImmediateNoShift(
            insns[i + 1],
            &endRd,
            &accessReg2,
            &endImm) ||

        endRd != 0 ||
        accessReg2 != accessReg ||
        endImm != 0x10 ||

        !pxqARM64IsBL(
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
    PXQ_METADATA_CORRELATION_BASE_OFFSET_ADDRESS = 1,
    PXQ_METADATA_CORRELATION_VALUE_OFFSET_ARGUMENTS = 2
} PXQMetadataCorrelationShape;


typedef struct {
    PXQMetadataCorrelationShape shape;

    uintptr_t accessor;

    uint32_t metadataReg;
    uint32_t witnessReg;

    /*
     * BaseOffsetAddress shape:
     *     value = BASE + OFFSET
     */
    uint32_t valueBaseReg;
    uint32_t valueOffsetReg;

    /*
     * ValueOffsetArguments shape:
     *     x0 <- VALUE
     *     x1 <- OFFSET
     */
    uint32_t valueReg;
    uint32_t offsetArgReg;
} PXQMetadataCorrelationCandidate;


static bool pxqParseMetadataCorrelationPrefix(
    uint8_t *text,
    unsigned long textSize,
    const uint32_t *insns,
    size_t count,
    size_t i,
    PXQMetadataCorrelationCandidate *gate
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
     * bl   assignmentCallMetadataAccessor
     * mov  xMETA,x0
     * ldur xVWT,[x0,#-8]
     * ldr  xWITNESS,[xVWT,#0x38]
     */

    if (insns[i] !=
            0xD2800000u ||

        /*
         * mov x0,#0
         */

        !pxqARM64IsBL(
            insns[i + 1]) ||

        !pxqARM64DecodeMoveRegister(
            insns[i + 2],
            &metadataReg,
            &metadataSource) ||

        metadataSource != 0 ||

        !pxqARM64DecodeLDUR64(
            insns[i + 3],
            &vwtReg,
            &ldurBase,
            &ldurImm) ||

        ldurBase != 0 ||
        ldurImm !=
            PXQ_SWIFT_VALUE_WITNESS_TABLE_METADATA_RELATIVE_OFFSET ||

        !pxqARM64IsLDR64UnsignedImmediate(
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


    if (!pxqARM64DecodeBLTarget(
            insns[i + 1],
            (uintptr_t)&insns[i + 1],
            &target) ||

        !pxqAddressRangeContains(
            (uintptr_t)text,
            (size_t)textSize,
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


static bool pxqParseBaseOffsetMetadataCorrelation(
    uint8_t *text,
    unsigned long textSize,
    const uint32_t *insns,
    size_t count,
    size_t i,
    PXQMetadataCorrelationCandidate *gate
)
{
    if (!gate ||
        i + 8 >= count) {

        return false;
    }


    PXQMetadataCorrelationCandidate parsed;

    if (!pxqParseMetadataCorrelationPrefix(
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
     * BaseOffsetAddress shape, proven on 8.6.9:
     *
     * mov  x0,#0
     * bl   assignmentCallMetadataAccessor
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
     *     BASE   == AssignmentCall BASE
     *     OFFSET == AssignmentCall OFFSET
     */

    if (!pxqARM64DecodeADD64RegisterNoShift(
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

        !pxqARM64DecodeBLR(
            insns[i + 8],
            &blrReg) ||

        blrReg != parsed.witnessReg) {

        return false;
    }


    if (baseReg == 31 ||
        offsetReg == 31) {

        return false;
    }


    parsed.shape =
        PXQ_METADATA_CORRELATION_BASE_OFFSET_ADDRESS;

    parsed.valueBaseReg =
        baseReg;

    parsed.valueOffsetReg =
        offsetReg;

    *gate =
        parsed;

    return true;
}


static bool pxqParseValueOffsetMetadataCorrelation(
    uint8_t *text,
    unsigned long textSize,
    const uint32_t *insns,
    size_t count,
    size_t i,
    PXQMetadataCorrelationCandidate *gate
)
{
    if (!gate ||
        i + 9 >= count) {

        return false;
    }


    PXQMetadataCorrelationCandidate parsed;

    if (!pxqParseMetadataCorrelationPrefix(
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
     * ValueOffsetArguments shape, proven on 8.8.1:
     *
     * mov  x0,#0
     * bl   assignmentCallMetadataAccessor
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
     *     OFFSET == AssignmentCall OFFSET
     *
     * x3 must carry the metadata returned by the accessor.
     * VALUE is deliberately not tied to a fixed physical
     * register because the verified evidence does not justify
     * such a constraint.
     */

    if (!pxqARM64DecodeMoveRegister(
            insns[i + 5],
            &arg0Dst,
            &valueReg) ||

        arg0Dst != 0 ||

        !pxqARM64DecodeMoveRegister(
            insns[i + 6],
            &arg1Dst,
            &offsetArgReg) ||

        arg1Dst != 1 ||

        insns[i + 7] !=
            0x52800022u ||

        /*
         * mov w2,#1
         */

        !pxqARM64DecodeMoveRegister(
            insns[i + 8],
            &metadataArgDst,
            &metadataArgSrc) ||

        metadataArgDst != 3 ||
        metadataArgSrc !=
            parsed.metadataReg ||

        !pxqARM64DecodeBLR(
            insns[i + 9],
            &blrReg) ||

        blrReg != parsed.witnessReg) {

        return false;
    }


    if (valueReg == 31 ||
        offsetArgReg == 31) {

        return false;
    }


    parsed.shape =
        PXQ_METADATA_CORRELATION_VALUE_OFFSET_ARGUMENTS;

    parsed.valueReg =
        valueReg;

    parsed.offsetArgReg =
        offsetArgReg;

    *gate =
        parsed;

    return true;
}


PXQAssignmentCallResolutionStatus pxqDetectTwoArgumentAssignmentCall(
    uint8_t *text,
    unsigned long textSize,
    PXQPixivOAuthUserAssignmentCallContract *match
)
{
    if (!text ||
        textSize == 0 ||
        !match) {

        return PXQ_ASSIGNMENT_CALL_RESOLUTION_INTERNAL_FAILURE;
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
        PXQ_MAX_TWO_ARGUMENT_ASSIGNMENT_CALL_CANDIDATES = 64
    };


    PXQTwoArgumentAssignmentCallCandidate structuralCandidates[
        PXQ_MAX_TWO_ARGUMENT_ASSIGNMENT_CALL_CANDIDATES
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
     * Phase 1: collect structural AssignmentCall candidates
     * ---------------------------------------------------------
     *
     * A candidate must satisfy:
     *
     * - register-independent proven 10-instruction AssignmentCall context
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

        PXQTwoArgumentAssignmentCallCandidate candidate;

        memset(
            &candidate,
            0,
            sizeof(candidate)
        );


        if (!pxqParseTwoArgumentAssignmentCallCandidate(
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


        if (!pxqARM64DecodeBLTarget(
                insns[i],
                callsite,
                &wrapper) ||

            !pxqValidateTwoArgumentTakeAssignmentWrapper(
                text,
                textSize,
                wrapper)) {

            wrapperRejectedCount++;

            continue;
        }


        if (structuralCandidateCount >=
            PXQ_MAX_TWO_ARGUMENT_ASSIGNMENT_CALL_CANDIDATES) {

            pxQoLLog(
                @"[PixivOAuthUser/Discovery/AssignmentCall/TwoArgument] TwoArgument rejected: more than %d structural AssignmentCall candidates before metadata correlation",
                PXQ_MAX_TWO_ARGUMENT_ASSIGNMENT_CALL_CANDIDATES
            );

            return PXQ_ASSIGNMENT_CALL_RESOLUTION_REJECTED_AMBIGUOUS;
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
            @"[PixivOAuthUser/Discovery/AssignmentCall/TwoArgument] TwoArgument AssignmentCall structural candidate #%zu: callsite=text+0x%llx wrapper=text+0x%llx destination=x%u+x%u source=x%u",
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
        @"[PixivOAuthUser/Discovery/AssignmentCall/TwoArgument] TwoArgument AssignmentCall collection summary: rawContexts=%zu structuralCandidates=%zu wrapperRejected=%zu",
        rawContextCount,
        structuralCandidateCount,
        wrapperRejectedCount
    );


    if (structuralCandidateCount == 0) {

        pxQoLLog(
            @"[PixivOAuthUser/Discovery/AssignmentCall/TwoArgument] TwoArgument rejected: no structural AssignmentCall candidate survived wrapper validation"
        );

        return PXQ_ASSIGNMENT_CALL_RESOLUTION_NO_QUALIFIED_CANDIDATE;
    }


    /*
     * ---------------------------------------------------------
     * Phase 2: semantic metadata correlation
     * ---------------------------------------------------------
     *
     * Search only in the confirmed 0x200-byte window preceding
     * each structural AssignmentCall callsite.
     *
     * BaseOffsetAddress shape, proven on 8.6.9 and 8.4.8:
     *
     *     AssignmentCall destination = BASE + OFFSET
     *     metadata gate value = SAME_BASE + SAME_OFFSET
     *
     * ValueOffsetArguments shape, proven on 8.8.1:
     *
     *     AssignmentCall destination uses OFFSET
     *     metadata witness x1 receives SAME_OFFSET
     *     metadata witness x3 receives xMETA
     *
     * A structural candidate is promoted to a correlated production
     * candidate only when:
     *
     * - at least one supported semantic metadata-correlation shape matches
     * - all matching gates for that candidate resolve to one accessor
     *
     * Candidates with no semantic match are ignored.
     * Candidates with internally disagreeing accessors are not promoted.
     */

    const size_t searchBack =
        0x200 /
        sizeof(uint32_t);


    PXQTwoArgumentAssignmentCallCandidate correlatedCandidates[
        PXQ_PIXIV_OAUTH_USER_MAX_ASSIGNMENT_CALL_SITES
    ];

    uintptr_t correlatedAccessors[
        PXQ_PIXIV_OAUTH_USER_MAX_ASSIGNMENT_CALL_SITES
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

    size_t totalBaseOffsetAddressMatches =
        0;

    size_t totalValueOffsetArgumentsMatches =
        0;

    size_t ambiguousCandidateCount =
        0;


    for (size_t c = 0;
         c < structuralCandidateCount;
         c++) {

        const PXQTwoArgumentAssignmentCallCandidate *candidate =
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

        size_t localBaseOffsetAddressMatches =
            0;

        size_t localValueOffsetArgumentsMatches =
            0;

        uintptr_t localAccessor =
            0;

        bool localAccessorAmbiguous =
            false;


        for (size_t i = start;
             i + 4 < callIndex &&
             i + 4 < count;
             i++) {

            PXQMetadataCorrelationCandidate gate;

            memset(
                &gate,
                0,
                sizeof(gate)
            );


            bool matched =
                false;


            /*
             * BaseOffsetAddress shape:
             * BASE+OFFSET must match AssignmentCall exactly.
             */

            if (i + 8 < callIndex &&
                i + 8 < count &&
                pxqParseBaseOffsetMetadataCorrelation(
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

                localBaseOffsetAddressMatches++;
                totalBaseOffsetAddressMatches++;


                pxQoLLog(
                    @"[PixivOAuthUser/Discovery/AssignmentCall/TwoArgument] TwoArgument metadata BaseOffsetAddress shape match: assignmentCall=text+0x%llx wrapper=text+0x%llx gate=text+0x%llx accessor=text+0x%llx value=x%u+x%u",
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
             * ValueOffsetArguments shape:
             * x1 must receive the same OFFSET register used
             * by AssignmentCall.
             *
             * Only try ValueOffsetArguments shape if BaseOffsetAddress shape did not already
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
                    pxqParseValueOffsetMetadataCorrelation(
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

                    localValueOffsetArgumentsMatches++;
                    totalValueOffsetArgumentsMatches++;


                    pxQoLLog(
                        @"[PixivOAuthUser/Discovery/AssignmentCall/TwoArgument] TwoArgument metadata ValueOffsetArguments shape match: assignmentCall=text+0x%llx wrapper=text+0x%llx gate=text+0x%llx accessor=text+0x%llx witnessArgs=x0<-x%u x1<-x%u x3<-x%u",
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
                @"[PixivOAuthUser/Discovery/AssignmentCall/TwoArgument] TwoArgument metadata summary structural[%zu]: callsite=text+0x%llx wrapper=text+0x%llx structuralMatches=0 baseOffsetAddress=0 valueOffsetArguments=0 correlated=0",
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
                @"[PixivOAuthUser/Discovery/AssignmentCall/TwoArgument] TwoArgument metadata summary structural[%zu]: callsite=text+0x%llx wrapper=text+0x%llx structuralMatches=%zu baseOffsetAddress=%zu valueOffsetArguments=%zu correlated=0 accessor=<ambiguous>",
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
                localBaseOffsetAddressMatches,
                localValueOffsetArgumentsMatches
            );

            continue;
        }


        correlatedCandidateCount++;


        if (correlatedCandidateCount >
            PXQ_PIXIV_OAUTH_USER_MAX_ASSIGNMENT_CALL_SITES) {

            pxQoLLog(
                @"[PixivOAuthUser/Discovery/AssignmentCall/TwoArgument] TwoArgument rejected: more than %d metadata-correlated AssignmentCall candidates",
                PXQ_PIXIV_OAUTH_USER_MAX_ASSIGNMENT_CALL_SITES
            );

            return PXQ_ASSIGNMENT_CALL_RESOLUTION_REJECTED_AMBIGUOUS;
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
            @"[PixivOAuthUser/Discovery/AssignmentCall/TwoArgument] TwoArgument metadata summary structural[%zu]: callsite=text+0x%llx wrapper=text+0x%llx structuralMatches=%zu baseOffsetAddress=%zu valueOffsetArguments=%zu correlated=1 accessor=text+0x%llx",
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
            localBaseOffsetAddressMatches,
            localValueOffsetArgumentsMatches,
            (unsigned long long)(
                localAccessor -
                (uintptr_t)text
            )
        );
    }


    pxQoLLog(
        @"[PixivOAuthUser/Discovery/AssignmentCall/TwoArgument] TwoArgument metadata total: structuralCandidates=%zu correlatedCandidates=%zu ambiguousCandidates=%zu structuralMatches=%zu baseOffsetAddress=%zu valueOffsetArguments=%zu",
        structuralCandidateCount,
        correlatedCandidateCount,
        ambiguousCandidateCount,
        totalStructuralMatches,
        totalBaseOffsetAddressMatches,
        totalValueOffsetArgumentsMatches
    );


    /*
     * ---------------------------------------------------------
     * Phase 3: final production validation
     * ---------------------------------------------------------
     *
     * Apply production invariants ONLY to metadata-correlated
     * candidates:
     *
     * - 1..MAX correlated AssignmentCall callsites
     * - all correlated candidates share one validated wrapper
     * - all correlated candidates share one metadata accessor
     */

    if (correlatedCandidateCount == 0) {

        pxQoLLog(
            @"[PixivOAuthUser/Discovery/AssignmentCall/TwoArgument] TwoArgument rejected: no semantic metadata-correlation shape correlated with AssignmentCall"
        );

        return PXQ_ASSIGNMENT_CALL_RESOLUTION_NO_QUALIFIED_CANDIDATE;
    }


    uintptr_t sharedWrapper =
        correlatedCandidates[0].wrapper;

    uintptr_t assignmentCallMetadataAccessor =
        correlatedAccessors[0];


    if (sharedWrapper == 0 ||
        assignmentCallMetadataAccessor == 0) {

        return PXQ_ASSIGNMENT_CALL_RESOLUTION_REJECTED_INVALID;
    }


    for (size_t i = 1;
         i < correlatedCandidateCount;
         i++) {

        if (correlatedCandidates[i].wrapper !=
            sharedWrapper) {

            pxQoLLog(
                @"[PixivOAuthUser/Discovery/AssignmentCall/TwoArgument] TwoArgument rejected: metadata-correlated AssignmentCall candidates use different wrappers"
            );

            return PXQ_ASSIGNMENT_CALL_RESOLUTION_REJECTED_AMBIGUOUS;
        }


        if (correlatedAccessors[i] !=
            assignmentCallMetadataAccessor) {

            pxQoLLog(
                @"[PixivOAuthUser/Discovery/AssignmentCall/TwoArgument] TwoArgument rejected: metadata-correlated AssignmentCall candidates use different metadata accessors"
            );

            return PXQ_ASSIGNMENT_CALL_RESOLUTION_REJECTED_AMBIGUOUS;
        }
    }


    /*
     * Publish only after all three phases succeed.
     */

    match->callSiteCount =
        correlatedCandidateCount;


    for (size_t i = 0;
         i < correlatedCandidateCount;
         i++) {

        match->callSites[i] =
            correlatedCandidates[i].callsite;
    }


    match->originalAssignmentWrapper =
        sharedWrapper;

    match->pixivOAuthUserMetadataAccessor =
        assignmentCallMetadataAccessor;


    pxQoLLog(
        @"[PixivOAuthUser/Discovery/AssignmentCall/TwoArgument] TwoArgument resolved: structuralCandidates=%zu correlatedCallsites=%zu wrapper=text+0x%llx metadata=text+0x%llx structuralMetadataMatches=%zu baseOffsetAddress=%zu valueOffsetArguments=%zu",
        structuralCandidateCount,
        match->callSiteCount,
        (unsigned long long)(
            match->originalAssignmentWrapper -
            (uintptr_t)text
        ),
        (unsigned long long)(
            match->pixivOAuthUserMetadataAccessor -
            (uintptr_t)text
        ),
        totalStructuralMatches,
        totalBaseOffsetAddressMatches,
        totalValueOffsetArgumentsMatches
    );


    return PXQ_ASSIGNMENT_CALL_RESOLUTION_RESOLVED;
}


