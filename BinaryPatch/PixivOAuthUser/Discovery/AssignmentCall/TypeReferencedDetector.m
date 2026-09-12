#import "AssignmentCallDiscoveryInternal.h"
#import "../../../Core/ARM64.h"
#import "../../../Core/MemoryAccess.h"
#import "../../../SwiftABI/Metadata.h"
#import "../../../SwiftABI/ValueWitness.h"
#import "../../Semantics/Semantics.h"
#import "../../../../LogHelper.h"


#include <string.h>


#pragma mark - AssignmentCall TypeReferenced Take

typedef struct {
    uintptr_t callsite;
    uintptr_t wrapper;
    uintptr_t typeRef;

    uint32_t sourceReg;
    uint32_t destinationReg;
    uint32_t stackImm;

} PXQTypeReferencedAssignmentCallCandidate;


static bool pxqValidateLazyTypeMetadataResolver(
    uint8_t *text,
    unsigned long textSize,
    uintptr_t helper
)
{
    const size_t scanSize =
        0x50;


    if (!pxqAddressRangeContains(
            (uintptr_t)text,
            (size_t)textSize,
            helper,
            scanSize)) {

        return false;
    }


    const uint32_t *insns =
        (const uint32_t *)helper;

    const size_t count =
        scanSize /
        sizeof(uint32_t);


    for (size_t i = 0;
         i + 2 < count;
         i++) {

        uint32_t loadRt = 0;
        uint32_t loadRn = 0;
        uint32_t loadImm = 0;
        uint32_t branchRt = 0;
        uint32_t branchBitNumber = 0;

        uintptr_t unresolved =
            0;


        /*
         * Proven lazy mangled-type cache resolver shape:
         *
         * mov  x19,x0
         * ldr  x0,[x0]
         * tbnz x0,#63,<unresolved>
         *
         * unresolved:
         * neg  x1,x0,ASR #32
         * add  x0,x19,x0,SXTW
         * mov  x2,#0
         * mov  x3,#0
         * bl   _swift_getTypeByMangledNameInContext
         * str  x0,[x19]
         * b    <resolved-return-path>
         */

        if (!pxqARM64IsMoveRegister(
                insns[i],
                19,
                0) ||

            !pxqARM64IsLDR64UnsignedImmediate(
                insns[i + 1],
                &loadRt,
                &loadRn,
                &loadImm) ||

            loadRt != 0 ||
            loadRn != 0 ||
            loadImm != 0 ||

            !pxqARM64DecodeTBNZ(
                insns[i + 2],
                (uintptr_t)&insns[i + 2],
                &branchRt,
                &branchBitNumber,
                &unresolved) ||

            branchRt != 0 ||
            branchBitNumber != 63) {

            continue;
        }


        if (unresolved < helper ||
            unresolved >=
                helper + scanSize ||

            !pxqAddressRangeContains(
                (uintptr_t)text,
                (size_t)textSize,
                unresolved,
                7 * sizeof(uint32_t))) {

            continue;
        }


        const uint32_t *u =
            (const uint32_t *)unresolved;


        if (u[0] !=
                0xCB8083E1u ||

            /*
             * neg x1,x0,ASR #32
             */

            u[1] !=
                0x8B20C260u ||

            /*
             * add x0,x19,x0,SXTW
             */

            u[2] !=
                0xD2800002u ||

            /*
             * mov x2,#0
             */

            u[3] !=
                0xD2800003u ||

            /*
             * mov x3,#0
             */

            !pxqARM64IsBL(
                u[4]) ||

            u[5] !=
                0xF9000260u ||

            /*
             * str x0,[x19]
             */

            !pxqARM64IsB(
                u[6])) {

            continue;
        }


        uintptr_t resolvedPath =
            0;


        if (!pxqARM64DecodeBranchTarget(
                u[6],
                (uintptr_t)&u[6],
                &resolvedPath) ||

            resolvedPath < helper ||
            resolvedPath >=
                helper + scanSize) {

            continue;
        }


        return true;
    }


    return false;
}


static bool pxqValidateTypeReferencedTakeAssignmentWrapper(
    uint8_t *text,
    unsigned long textSize,
    uintptr_t wrapper,
    uintptr_t *metadataHelper
)
{
    const size_t scanSize =
        0x50;


    if (!metadataHelper ||
        !pxqAddressRangeContains(
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


    /*
     * TypeReferenced Take wrapper ABI:
     *
     * x0 = source
     * x1 = destination
     * x2 = type-reference/cache cell
     *
     * Proven wrapper body:
     *
     * mov  x19,x1
     * mov  x20,x0
     * mov  x0,x2
     * bl   <lazy metadata helper>
     * mov  x2,x0
     * ldur x8,[x0,#-8]
     * ldr  x8,[x8,#0x28]
     * mov  x0,x19
     * mov  x1,x20
     * blr  x8
     * mov  x0,x19
     */

    for (size_t i = 0;
         i + 10 < count;
         i++) {

        uint32_t ldurRt = 0;
        uint32_t ldurRn = 0;
        int32_t ldurImm = 0;

        uint32_t loadRt = 0;
        uint32_t loadRn = 0;
        uint32_t loadImm = 0;

        uint32_t blrRn = 0;

        uintptr_t helper =
            0;


        if (!pxqARM64IsMoveRegister(
                insns[i],
                19,
                1) ||

            !pxqARM64IsMoveRegister(
                insns[i + 1],
                20,
                0) ||

            !pxqARM64IsMoveRegister(
                insns[i + 2],
                0,
                2) ||

            !pxqARM64IsBL(
                insns[i + 3]) ||

            !pxqARM64IsMoveRegister(
                insns[i + 4],
                2,
                0) ||

            !pxqARM64DecodeLDUR64(
                insns[i + 5],
                &ldurRt,
                &ldurRn,
                &ldurImm) ||

            ldurRt != 8 ||
            ldurRn != 0 ||
            ldurImm !=
                PXQ_SWIFT_VALUE_WITNESS_TABLE_METADATA_RELATIVE_OFFSET ||

            !pxqARM64IsLDR64UnsignedImmediate(
                insns[i + 6],
                &loadRt,
                &loadRn,
                &loadImm) ||

            loadRt != 8 ||
            loadRn != 8 ||
            loadImm !=
                PXQ_SWIFT_VALUE_WITNESS_ASSIGN_WITH_TAKE_POINTER_INDEX ||

            /*
             * 0x28 / 8 = 5
             */

            !pxqARM64IsMoveRegister(
                insns[i + 7],
                0,
                19) ||

            !pxqARM64IsMoveRegister(
                insns[i + 8],
                1,
                20) ||

            !pxqARM64DecodeBLR(
                insns[i + 9],
                &blrRn) ||

            blrRn != 8 ||

            !pxqARM64IsMoveRegister(
                insns[i + 10],
                0,
                19) ||

            !pxqARM64DecodeBLTarget(
                insns[i + 3],
                (uintptr_t)&insns[i + 3],
                &helper) ||

            !pxqAddressRangeContains(
                (uintptr_t)text,
                (size_t)textSize,
                helper,
                sizeof(uint32_t))) {

            continue;
        }


        *metadataHelper =
            helper;

        return true;
    }


    return false;
}


static bool pxqValidateTypeReferencedCopyAssignmentWrapper(
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


    /*
     * TypeReferenced Copy wrapper proof:
     *
     * resolve metadata
     *   -> metadata VWT at [metadata - 8]
     *   -> VWT slot +0x18
     *   -> indirect call through that slot
     *
     * +0x18 is the Swift VWT assignWithCopy operation.
     *
     * Do not require a specific prologue or saved-register allocation.
     * Those are compiler-allocation details and differ independently
     * from the x0/x1/x2 call ABI.
     */

    for (size_t i = 0;
         i + 2 < count;
         i++) {

        uint32_t vwtReg = 0;
        uint32_t metadataReg = 0;
        int32_t vwtImm = 0;

        uint32_t functionReg = 0;
        uint32_t loadBaseReg = 0;
        uint32_t loadImm = 0;


        if (!pxqARM64DecodeLDUR64(
                insns[i],
                &vwtReg,
                &metadataReg,
                &vwtImm) ||

            vwtImm !=
                PXQ_SWIFT_VALUE_WITNESS_TABLE_METADATA_RELATIVE_OFFSET ||

            !pxqARM64IsLDR64UnsignedImmediate(
                insns[i + 1],
                &functionReg,
                &loadBaseReg,
                &loadImm) ||

            loadBaseReg != vwtReg ||

            loadImm !=
                PXQ_SWIFT_VALUE_WITNESS_ASSIGN_WITH_COPY_POINTER_INDEX) {

            /*
             * 0x18 / sizeof(uintptr_t) = 3
             */
            continue;
        }


        /*
         * The call-through may be separated from the VWT load by
         * register moves that prepare source/destination.
         */

        size_t callEnd =
            i + 6;

        if (callEnd > count)
            callEnd = count;


        for (size_t j = i + 2;
             j < callEnd;
             j++) {

            uint32_t blrRn = 0;


            if (pxqARM64DecodeBLR(
                    insns[j],
                    &blrRn) &&
                blrRn == functionReg) {

                return true;
            }
        }
    }


    return false;
}


static bool pxqParseTypeReferencedTakeAssignmentCall(
    uint8_t *text,
    unsigned long textSize,
    const uint32_t *insns,
    size_t count,
    size_t i,
    PXQTypeReferencedAssignmentCallCandidate *candidate
)
{
    if (!text ||
        !insns ||
        !candidate ||
        i < 9 ||
        i + 2 >= count) {

        return false;
    }


    uint32_t beginRd = 0;
    uint32_t beginRn = 0;
    uint32_t beginImm = 0;

    uint32_t destinationDst0 = 0;
    uint32_t destinationReg0 = 0;

    uint32_t adrpRd = 0;
    uintptr_t typePage = 0;

    uint32_t typeAddRd = 0;
    uint32_t typeAddRn = 0;
    uint32_t typeAddImm = 0;

    uint32_t sourceDst = 0;
    uint32_t sourceReg = 0;

    uint32_t destinationDst1 = 0;
    uint32_t destinationReg1 = 0;

    uint32_t endRd = 0;
    uint32_t endRn = 0;
    uint32_t endImm = 0;

    uintptr_t wrapper =
        0;

    uintptr_t typeRef =
        0;


    /*
     * TypeReferenced Take caller:
     *
     * add  x1,sp,#ACCESS_IMM
     * mov  x0,DEST
     * mov  w2,#0x21
     * mov  x3,#0
     * bl   beginAccess
     *
     * adrp x2,TYPE_PAGE
     * add  x2,x2,#TYPE_OFF
     *
     * mov  x0,SOURCE
     * mov  x1,DEST
     * bl   <wrapper>          <- i
     *
     * add  x0,sp,#ACCESS_IMM
     * bl   endAccess
     */

    if (!pxqARM64DecodeADD64ImmediateNoShift(
            insns[i - 9],
            &beginRd,
            &beginRn,
            &beginImm) ||

        beginRd != 1 ||
        beginRn != 31 ||

        !pxqARM64DecodeMoveRegister(
            insns[i - 8],
            &destinationDst0,
            &destinationReg0) ||

        destinationDst0 != 0 ||

        insns[i - 7] !=
            0x52800422u ||

        /*
         * mov w2,#0x21
         */

        insns[i - 6] !=
            0xD2800003u ||

        /*
         * mov x3,#0
         */

        !pxqARM64IsBL(
            insns[i - 5]) ||

        !pxqARM64DecodeADRP(
            insns[i - 4],
            (uintptr_t)&insns[i - 4],
            &adrpRd,
            &typePage) ||

        adrpRd != 2 ||

        !pxqARM64DecodeADD64ImmediateNoShift(
            insns[i - 3],
            &typeAddRd,
            &typeAddRn,
            &typeAddImm) ||

        typeAddRd != 2 ||
        typeAddRn != 2 ||

        !pxqARM64DecodeMoveRegister(
            insns[i - 2],
            &sourceDst,
            &sourceReg) ||

        sourceDst != 0 ||

        !pxqARM64DecodeMoveRegister(
            insns[i - 1],
            &destinationDst1,
            &destinationReg1) ||

        destinationDst1 != 1 ||
        destinationReg1 !=
            destinationReg0 ||

        !pxqARM64IsBL(
            insns[i]) ||

        !pxqARM64DecodeADD64ImmediateNoShift(
            insns[i + 1],
            &endRd,
            &endRn,
            &endImm) ||

        endRd != 0 ||
        endRn != 31 ||
        endImm != beginImm ||

        !pxqARM64IsBL(
            insns[i + 2])) {

        return false;
    }


    if (destinationReg0 == 31 ||
        sourceReg == 31 ||
        destinationReg0 ==
            sourceReg) {

        return false;
    }


    if ((uint64_t)typeAddImm >
        (uint64_t)UINTPTR_MAX -
        (uint64_t)typePage) {

        return false;
    }


    typeRef =
        typePage +
        (uintptr_t)typeAddImm;


    if (!pxqARM64DecodeBLTarget(
            insns[i],
            (uintptr_t)&insns[i],
            &wrapper) ||

        !pxqAddressRangeContains(
            (uintptr_t)text,
            (size_t)textSize,
            wrapper,
            sizeof(uint32_t))) {

        return false;
    }


    memset(
        candidate,
        0,
        sizeof(*candidate)
    );


    candidate->callsite =
        (uintptr_t)&insns[i];

    candidate->wrapper =
        wrapper;

    candidate->typeRef =
        typeRef;

    candidate->sourceReg =
        sourceReg;

    candidate->destinationReg =
        destinationReg0;

    candidate->stackImm =
        beginImm;


    return true;
}


static bool pxqParseTypeReferencedCopyAssignmentCall(
    uint8_t *text,
    unsigned long textSize,
    const uint32_t *insns,
    size_t count,
    size_t i,
    PXQTypeReferencedAssignmentCallCandidate *candidate
)
{
    if (!text ||
        !insns ||
        !candidate ||
        i < 10 ||
        i + 2 >= count) {

        return false;
    }


    uint32_t beginRd = 0;
    uint32_t beginRn = 0;
    uint32_t beginImm = 0;

    uint32_t destinationDst0 = 0;
    uint32_t destinationReg0 = 0;

    uint32_t adrpRd = 0;
    uintptr_t typePage = 0;

    uint32_t typeAddRd = 0;
    uint32_t typeAddRn = 0;
    uint32_t typeAddImm = 0;

    uint32_t sourceDst = 0;
    uint32_t sourceReg = 0;

    uint32_t destinationDst1 = 0;
    uint32_t destinationReg1 = 0;

    uint32_t typeMoveDst = 0;
    uint32_t typeReg = 0;

    uint32_t endRd = 0;
    uint32_t endRn = 0;
    uint32_t endImm = 0;

    uintptr_t wrapper =
        0;

    uintptr_t typeRef =
        0;


    /*
     * TypeReferenced Copy caller family:
     *
     * add  x1,sp,#ACCESS_IMM
     * mov  x0,DEST
     * mov  w2,#0x21
     * mov  x3,#0
     * bl   beginAccess
     *
     * adrp TYPE_REG,TYPE_PAGE
     * add  TYPE_REG,TYPE_REG,#TYPE_OFF
     *
     * mov  x0,SOURCE
     * mov  x1,DEST
     * mov  x2,TYPE_REG
     * bl   <assignWithCopy wrapper>   <- i
     *
     * add  x0,sp,#ACCESS_IMM
     * bl   endAccess
     *
     * The call ABI and data-flow relationships are fixed. The compiler's
     * saved-register allocation and ACCESS_IMM are not.
     *
     * Confirmed layouts include:
     *
     * 8.1.3:
     *   source=x22 destination=x23 type=x24 ACCESS_IMM=0x8
     *
     * 7.20.1:
     *   source=x23 destination=x24 type=x19 ACCESS_IMM=0x28
     */

    if (!pxqARM64DecodeADD64ImmediateNoShift(
            insns[i - 10],
            &beginRd,
            &beginRn,
            &beginImm) ||

        beginRd != 1 ||
        beginRn != 31 ||

        !pxqARM64DecodeMoveRegister(
            insns[i - 9],
            &destinationDst0,
            &destinationReg0) ||

        destinationDst0 != 0 ||

        insns[i - 8] !=
            0x52800422u ||

        /*
         * mov w2,#0x21
         */

        insns[i - 7] !=
            0xD2800003u ||

        /*
         * mov x3,#0
         */

        !pxqARM64IsBL(
            insns[i - 6]) ||

        !pxqARM64DecodeADRP(
            insns[i - 5],
            (uintptr_t)&insns[i - 5],
            &adrpRd,
            &typePage) ||

        !pxqARM64DecodeADD64ImmediateNoShift(
            insns[i - 4],
            &typeAddRd,
            &typeAddRn,
            &typeAddImm) ||

        typeAddRd != adrpRd ||
        typeAddRn != adrpRd ||

        !pxqARM64DecodeMoveRegister(
            insns[i - 3],
            &sourceDst,
            &sourceReg) ||

        sourceDst != 0 ||

        !pxqARM64DecodeMoveRegister(
            insns[i - 2],
            &destinationDst1,
            &destinationReg1) ||

        destinationDst1 != 1 ||
        destinationReg1 !=
            destinationReg0 ||

        !pxqARM64DecodeMoveRegister(
            insns[i - 1],
            &typeMoveDst,
            &typeReg) ||

        typeMoveDst != 2 ||
        typeReg != adrpRd ||

        !pxqARM64IsBL(
            insns[i]) ||

        !pxqARM64DecodeADD64ImmediateNoShift(
            insns[i + 1],
            &endRd,
            &endRn,
            &endImm) ||

        endRd != 0 ||
        endRn != 31 ||
        endImm != beginImm ||

        !pxqARM64IsBL(
            insns[i + 2])) {

        return false;
    }


    if (destinationReg0 == 31 ||
        sourceReg == 31 ||
        typeReg == 31 ||
        destinationReg0 ==
            sourceReg ||
        typeReg == destinationReg0 ||
        typeReg == sourceReg) {

        return false;
    }


    if ((uint64_t)typeAddImm >
        (uint64_t)UINTPTR_MAX -
        (uint64_t)typePage) {

        return false;
    }


    typeRef =
        typePage +
        (uintptr_t)typeAddImm;


    if (!pxqARM64DecodeBLTarget(
            insns[i],
            (uintptr_t)&insns[i],
            &wrapper) ||

        !pxqAddressRangeContains(
            (uintptr_t)text,
            (size_t)textSize,
            wrapper,
            sizeof(uint32_t))) {

        return false;
    }


    memset(
        candidate,
        0,
        sizeof(*candidate)
    );


    candidate->callsite =
        (uintptr_t)&insns[i];

    candidate->wrapper =
        wrapper;

    candidate->typeRef =
        typeRef;

    candidate->sourceReg =
        sourceReg;

    candidate->destinationReg =
        destinationReg0;

    candidate->stackImm =
        beginImm;


    return true;
}


static bool pxqResolveOptionalPixivOAuthUserTypeEvidence(
    uint8_t *text,
    unsigned long textSize,
    uintptr_t typeRef,
    uintptr_t *descriptor,
    uintptr_t *metadataAccessor,
    uint32_t *descriptorFieldCount,
    uint32_t *fieldOffsetVectorOffset
)
{
    if (!text ||
        textSize == 0 ||
        typeRef == 0 ||
        !descriptor ||
        !metadataAccessor) {

        return false;
    }


    uintptr_t resolvedDescriptor =
        0;


    if (!pxqSwiftMetadataResolveUnresolvedOptionalNominalTypeReference(
            typeRef,
            &resolvedDescriptor)) {

        return false;
    }


    PXQPixivOAuthUserTypeDescriptorEvidence evidence =
        {0};


    if (!pxqValidatePixivOAuthUserTypeDescriptor(
            text,
            textSize,
            resolvedDescriptor,
            &evidence)) {

        return false;
    }


    *descriptor =
        resolvedDescriptor;

    *metadataAccessor =
        evidence.pixivOAuthUserMetadataAccessor;


    if (descriptorFieldCount)
        *descriptorFieldCount =
            evidence.fieldCount;


    if (fieldOffsetVectorOffset)
        *fieldOffsetVectorOffset =
            evidence.fieldOffsetVectorOffset;


    return true;
}


PXQAssignmentCallResolutionStatus pxqDetectTypeReferencedCopyAssignmentCall(
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


    size_t exactShapeCount =
        0;

    size_t wrapperRejected =
        0;

    size_t semanticTypeRejected =
        0;

    size_t promotedCount =
        0;


    PXQTypeReferencedAssignmentCallCandidate promotedCandidate;

    memset(
        &promotedCandidate,
        0,
        sizeof(promotedCandidate)
    );


    uintptr_t promotedDescriptor =
        0;

    uintptr_t promotedMetadataAccessor =
        0;

    uint32_t promotedFieldCount =
        0;

    uint32_t promotedFieldVectorOffset =
        0;


    for (size_t i = 10;
         i + 2 < count;
         i++) {

        PXQTypeReferencedAssignmentCallCandidate candidate;


        if (!pxqParseTypeReferencedCopyAssignmentCall(
                text,
                textSize,
                insns,
                count,
                i,
                &candidate)) {

            continue;
        }


        exactShapeCount++;


        if (!pxqValidateTypeReferencedCopyAssignmentWrapper(
                text,
                textSize,
                candidate.wrapper)) {

            wrapperRejected++;

            pxQoLLog(
                @"[PixivOAuthUser/Discovery/AssignmentCall/TypeReferenced] TypeReferenced Copy structural candidate #%zu rejected: assignWithCopy wrapper validation failed callsite=text+0x%llx wrapper=text+0x%llx",
                exactShapeCount,
                (unsigned long long)(
                    candidate.callsite -
                    (uintptr_t)text
                ),
                (unsigned long long)(
                    candidate.wrapper -
                    (uintptr_t)text
                )
            );

            continue;
        }


        uintptr_t descriptor =
            0;

        uintptr_t metadataAccessor =
            0;

        uint32_t descriptorFields =
            0;

        uint32_t fieldVectorOffset =
            0;


        /*
         * Caller data flow proves the x0/x1/x2 ABI and the dedicated
         * wrapper validator proves assignWithCopy. Require the x2 cache
         * cell to resolve semantically to Optional<PixivOAuthUser>.
         */
        if (!pxqResolveOptionalPixivOAuthUserTypeEvidence(
                text,
                textSize,
                candidate.typeRef,
                &descriptor,
                &metadataAccessor,
                &descriptorFields,
                &fieldVectorOffset)) {

            semanticTypeRejected++;

            pxQoLLog(
                @"[PixivOAuthUser/Discovery/AssignmentCall/TypeReferenced] TypeReferenced Copy structural candidate #%zu rejected: typeRef is not proven Optional<PixivOAuthUser> callsite=text+0x%llx typeRef=%p",
                exactShapeCount,
                (unsigned long long)(
                    candidate.callsite -
                    (uintptr_t)text
                ),
                (void *)candidate.typeRef
            );

            continue;
        }


        promotedCount++;


        pxQoLLog(
            @"[PixivOAuthUser/Discovery/AssignmentCall/TypeReferenced] TypeReferenced Copy semantic candidate #%zu: callsite=text+0x%llx wrapper=text+0x%llx source=x%u destination=x%u stackImm=0x%x typeRef=%p descriptor=%p metadata=text+0x%llx fields=%u fieldOffsetVectorOffset=%u",
            promotedCount,
            (unsigned long long)(
                candidate.callsite -
                (uintptr_t)text
            ),
            (unsigned long long)(
                candidate.wrapper -
                (uintptr_t)text
            ),
            candidate.sourceReg,
            candidate.destinationReg,
            candidate.stackImm,
            (void *)candidate.typeRef,
            (void *)descriptor,
            (unsigned long long)(
                metadataAccessor -
                (uintptr_t)text
            ),
            descriptorFields,
            fieldVectorOffset
        );


        if (promotedCount == 1) {

            promotedCandidate =
                candidate;

            promotedDescriptor =
                descriptor;

            promotedMetadataAccessor =
                metadataAccessor;

            promotedFieldCount =
                descriptorFields;

            promotedFieldVectorOffset =
                fieldVectorOffset;
        }
    }


    pxQoLLog(
        @"[PixivOAuthUser/Discovery/AssignmentCall/TypeReferenced] TypeReferenced Copy summary: exactShape=%zu wrapperRejected=%zu semanticTypeRejected=%zu semanticPromoted=%zu",
        exactShapeCount,
        wrapperRejected,
        semanticTypeRejected,
        promotedCount
    );


    if (promotedCount == 0) {

        pxQoLLog(
            @"[PixivOAuthUser/Discovery/AssignmentCall/TypeReferenced] TypeReferenced Copy unresolved: no qualified semantic Optional<PixivOAuthUser> AssignmentCall candidate"
        );

        return PXQ_ASSIGNMENT_CALL_RESOLUTION_NO_QUALIFIED_CANDIDATE;
    }


    if (promotedCount != 1) {

        pxQoLLog(
            @"[PixivOAuthUser/Discovery/AssignmentCall/TypeReferenced] TypeReferenced Copy rejected: expected exactly 1 semantic Optional<PixivOAuthUser> AssignmentCall candidate, got %zu",
            promotedCount
        );

        return PXQ_ASSIGNMENT_CALL_RESOLUTION_REJECTED_AMBIGUOUS;
    }


    memset(
        match,
        0,
        sizeof(*match)
    );


    match->callSites[0] =
        promotedCandidate.callsite;

    match->callSiteCount =
        1;

    match->originalAssignmentWrapper =
        promotedCandidate.wrapper;

    match->pixivOAuthUserMetadataAccessor =
        promotedMetadataAccessor;


    pxQoLLog(
        @"[PixivOAuthUser/Discovery/AssignmentCall/TypeReferenced] TypeReferenced Copy resolved: callsite=text+0x%llx wrapper=text+0x%llx typeRef=%p descriptor=%p metadata=text+0x%llx fields=%u fieldOffsetVectorOffset=%u",
        (unsigned long long)(
            match->callSites[0] -
            (uintptr_t)text
        ),
        (unsigned long long)(
            match->originalAssignmentWrapper -
            (uintptr_t)text
        ),
        (void *)promotedCandidate.typeRef,
        (void *)promotedDescriptor,
        (unsigned long long)(
            match->pixivOAuthUserMetadataAccessor -
            (uintptr_t)text
        ),
        promotedFieldCount,
        promotedFieldVectorOffset
    );


    return PXQ_ASSIGNMENT_CALL_RESOLUTION_RESOLVED;
}


PXQAssignmentCallResolutionStatus pxqDetectTypeReferencedTakeAssignmentCall(
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


    size_t exactShapeCount =
        0;

    size_t wrapperRejected =
        0;

    size_t helperRejected =
        0;

    size_t semanticTypeRejected =
        0;

    size_t promotedCount =
        0;


    PXQTypeReferencedAssignmentCallCandidate promotedCandidate;

    memset(
        &promotedCandidate,
        0,
        sizeof(promotedCandidate)
    );


    uintptr_t promotedMetadataHelper =
        0;

    uintptr_t promotedDescriptor =
        0;

    uintptr_t promotedMetadataAccessor =
        0;

    uint32_t promotedFieldCount =
        0;

    uint32_t promotedFieldVectorOffset =
        0;


    for (size_t i = 9;
         i + 2 < count;
         i++) {

        PXQTypeReferencedAssignmentCallCandidate candidate;


        if (!pxqParseTypeReferencedTakeAssignmentCall(
                text,
                textSize,
                insns,
                count,
                i,
                &candidate)) {

            continue;
        }


        exactShapeCount++;


        uintptr_t metadataHelper =
            0;


        if (!pxqValidateTypeReferencedTakeAssignmentWrapper(
                text,
                textSize,
                candidate.wrapper,
                &metadataHelper)) {

            wrapperRejected++;

            pxQoLLog(
                @"[PixivOAuthUser/Discovery/AssignmentCall/TypeReferenced] TypeReferenced Take structural candidate #%zu rejected: wrapper validation failed callsite=text+0x%llx wrapper=text+0x%llx",
                exactShapeCount,
                (unsigned long long)(
                    candidate.callsite -
                    (uintptr_t)text
                ),
                (unsigned long long)(
                    candidate.wrapper -
                    (uintptr_t)text
                )
            );

            continue;
        }


        if (!pxqValidateLazyTypeMetadataResolver(
                text,
                textSize,
                metadataHelper)) {

            helperRejected++;

            pxQoLLog(
                @"[PixivOAuthUser/Discovery/AssignmentCall/TypeReferenced] TypeReferenced Take structural candidate #%zu rejected: lazy metadata helper validation failed callsite=text+0x%llx helper=text+0x%llx",
                exactShapeCount,
                (unsigned long long)(
                    candidate.callsite -
                    (uintptr_t)text
                ),
                (unsigned long long)(
                    metadataHelper -
                    (uintptr_t)text
                )
            );

            continue;
        }


        uintptr_t descriptor =
            0;

        uintptr_t metadataAccessor =
            0;

        uint32_t descriptorFields =
            0;

        uint32_t fieldVectorOffset =
            0;


        if (!pxqResolveOptionalPixivOAuthUserTypeEvidence(
                text,
                textSize,
                candidate.typeRef,
                &descriptor,
                &metadataAccessor,
                &descriptorFields,
                &fieldVectorOffset)) {

            semanticTypeRejected++;

            pxQoLLog(
                @"[PixivOAuthUser/Discovery/AssignmentCall/TypeReferenced] TypeReferenced Take structural candidate #%zu rejected: typeRef is not proven Optional<PixivOAuthUser> callsite=text+0x%llx typeRef=%p",
                exactShapeCount,
                (unsigned long long)(
                    candidate.callsite -
                    (uintptr_t)text
                ),
                (void *)candidate.typeRef
            );

            continue;
        }


        promotedCount++;


        pxQoLLog(
            @"[PixivOAuthUser/Discovery/AssignmentCall/TypeReferenced] TypeReferenced Take semantic candidate #%zu: callsite=text+0x%llx wrapper=text+0x%llx source=x%u destination=x%u stackImm=0x%x typeRef=%p helper=text+0x%llx descriptor=%p metadata=text+0x%llx fields=%u fieldOffsetVectorOffset=%u",
            promotedCount,
            (unsigned long long)(
                candidate.callsite -
                (uintptr_t)text
            ),
            (unsigned long long)(
                candidate.wrapper -
                (uintptr_t)text
            ),
            candidate.sourceReg,
            candidate.destinationReg,
            candidate.stackImm,
            (void *)candidate.typeRef,
            (unsigned long long)(
                metadataHelper -
                (uintptr_t)text
            ),
            (void *)descriptor,
            (unsigned long long)(
                metadataAccessor -
                (uintptr_t)text
            ),
            descriptorFields,
            fieldVectorOffset
        );


        if (promotedCount == 1) {

            promotedCandidate =
                candidate;

            promotedMetadataHelper =
                metadataHelper;

            promotedDescriptor =
                descriptor;

            promotedMetadataAccessor =
                metadataAccessor;

            promotedFieldCount =
                descriptorFields;

            promotedFieldVectorOffset =
                fieldVectorOffset;
        }
    }


    pxQoLLog(
        @"[PixivOAuthUser/Discovery/AssignmentCall/TypeReferenced] TypeReferenced Take summary: exactShape=%zu wrapperRejected=%zu helperRejected=%zu semanticTypeRejected=%zu semanticPromoted=%zu",
        exactShapeCount,
        wrapperRejected,
        helperRejected,
        semanticTypeRejected,
        promotedCount
    );


    /*
     * Production identity is semantic, not heuristic.
     *
     * direct metadata-reference counts, nearby LDRB counts,
     * callsite proximity, and app-version numbers do not
     * participate.
     */

    if (promotedCount == 0) {

        pxQoLLog(
            @"[PixivOAuthUser/Discovery/AssignmentCall/TypeReferenced] TypeReferenced Take unresolved: no qualified semantic Optional<PixivOAuthUser> AssignmentCall candidate"
        );

        return PXQ_ASSIGNMENT_CALL_RESOLUTION_NO_QUALIFIED_CANDIDATE;
    }


    if (promotedCount != 1) {

        pxQoLLog(
            @"[PixivOAuthUser/Discovery/AssignmentCall/TypeReferenced] TypeReferenced Take rejected: expected exactly 1 semantic Optional<PixivOAuthUser> AssignmentCall candidate, got %zu",
            promotedCount
        );

        return PXQ_ASSIGNMENT_CALL_RESOLUTION_REJECTED_AMBIGUOUS;
    }


    memset(
        match,
        0,
        sizeof(*match)
    );


    match->callSites[0] =
        promotedCandidate.callsite;

    match->callSiteCount =
        1;

    match->originalAssignmentWrapper =
        promotedCandidate.wrapper;

    match->pixivOAuthUserMetadataAccessor =
        promotedMetadataAccessor;


    pxQoLLog(
        @"[PixivOAuthUser/Discovery/AssignmentCall/TypeReferenced] TypeReferenced Take resolved: callsite=text+0x%llx wrapper=text+0x%llx typeRef=%p helper=text+0x%llx descriptor=%p metadata=text+0x%llx fields=%u fieldOffsetVectorOffset=%u",
        (unsigned long long)(
            match->callSites[0] -
            (uintptr_t)text
        ),
        (unsigned long long)(
            match->originalAssignmentWrapper -
            (uintptr_t)text
        ),
        (void *)promotedCandidate.typeRef,
        (unsigned long long)(
            promotedMetadataHelper -
            (uintptr_t)text
        ),
        (void *)promotedDescriptor,
        (unsigned long long)(
            match->pixivOAuthUserMetadataAccessor -
            (uintptr_t)text
        ),
        promotedFieldCount,
        promotedFieldVectorOffset
    );


    return PXQ_ASSIGNMENT_CALL_RESOLUTION_RESOLVED;
}


