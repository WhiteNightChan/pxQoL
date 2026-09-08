#import "Finder_UserState_Initial_Internal.h"
#import "../Core/pxQoLARM64.h"
#import "../../LogHelper.h"

#import <mach/mach.h>

#include <string.h>


#pragma mark - InitialUserState Variant C

typedef struct {
    uintptr_t callsite;
    uintptr_t wrapper;
    uintptr_t typeRef;

    uint32_t sourceReg;
    uint32_t destinationReg;
    uint32_t stackImm;

} pxqInitialUserStateVariantCCandidate;


static bool pxqReadMemory(
    uintptr_t address,
    void *buffer,
    size_t size
)
{
    if (address == 0 ||
        !buffer ||
        size == 0) {

        return false;
    }


    vm_size_t outSize =
        0;

    kern_return_t kr =
        vm_read_overwrite(
            mach_task_self(),
            (vm_address_t)address,
            (vm_size_t)size,
            (vm_address_t)buffer,
            &outSize
        );


    return
        kr == KERN_SUCCESS &&
        outSize == (vm_size_t)size;
}


static bool pxqAddSignedDelta(
    uintptr_t base,
    int64_t delta,
    uintptr_t *result
)
{
    if (!result)
        return false;


    if (delta >= 0) {

        uint64_t positive =
            (uint64_t)delta;

        if (positive >
            (uint64_t)UINTPTR_MAX -
            (uint64_t)base) {

            return false;
        }


        *result =
            base +
            (uintptr_t)positive;

        return true;
    }


    uint64_t magnitude =
        (uint64_t)(-(delta + 1)) +
        1u;


    if ((uint64_t)base <
        magnitude) {

        return false;
    }


    *result =
        base -
        (uintptr_t)magnitude;

    return true;
}


static bool pxqAddRelative32(
    uintptr_t base,
    int32_t relative,
    uintptr_t *result
)
{
    return pxqAddSignedDelta(
        base,
        (int64_t)relative,
        result
    );
}



static bool pxqReadCString(
    uintptr_t address,
    char *buffer,
    size_t capacity
)
{
    if (address == 0 ||
        !buffer ||
        capacity < 2) {

        return false;
    }


    for (size_t i = 0;
         i < capacity;
         i++) {

        uint8_t value =
            0;


        if (i >
            (size_t)(UINTPTR_MAX - address)) {

            return false;
        }


        if (!pxqReadMemory(
                address + i,
                &value,
                sizeof(value))) {

            return false;
        }


        buffer[i] =
            (char)value;


        if (value == 0)
            return true;
    }


    buffer[
        capacity - 1
    ] =
        '\0';


    return false;
}


static bool pxqDecodeTBNZX0Bit63Target(
    uint32_t insn,
    uintptr_t pc,
    uintptr_t *target
)
{
    /*
     * TBNZ X0,#63,<target>
     *
     * Ignore only imm14. Keep:
     *
     * - TBNZ opcode
     * - X-register bit-number high bit
     * - bit number 63
     * - Rt == x0
     */

    if ((insn & 0xFFF8001Fu) !=
        0xB7F80000u) {

        return false;
    }


    int64_t imm14 =
        (int64_t)(
            (insn >> 5) &
            0x3FFFu
        );


    if (imm14 &
        0x2000) {

        imm14 |=
            ~0x3FFFLL;
    }


    return pxqAddSignedDelta(
        pc,
        imm14 << 2,
        target
    );
}


static bool pxqValidateVariantCLazyMetadataHelper(
    uint8_t *text,
    unsigned long textSize,
    uintptr_t helper
)
{
    const size_t scanSize =
        0x50;


    if (!pxqInText(
            text,
            textSize,
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

        if (!pxQoLIsMovReg(
                insns[i],
                19,
                0) ||

            !pxQoLIsLDR64UnsignedImm(
                insns[i + 1],
                &loadRt,
                &loadRn,
                &loadImm) ||

            loadRt != 0 ||
            loadRn != 0 ||
            loadImm != 0 ||

            !pxqDecodeTBNZX0Bit63Target(
                insns[i + 2],
                (uintptr_t)&insns[i + 2],
                &unresolved)) {

            continue;
        }


        if (unresolved < helper ||
            unresolved >=
                helper + scanSize ||

            !pxqInText(
                text,
                textSize,
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

            !pxQoLIsBL(
                u[4]) ||

            u[5] !=
                0xF9000260u ||

            /*
             * str x0,[x19]
             */

            !pxQoLIsB(
                u[6])) {

            continue;
        }


        uintptr_t resolvedPath =
            0;


        if (!pxQoLDecodeBranchTarget(
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


static bool pxqValidateInitialUserStateVariantCWrapper(
    uint8_t *text,
    unsigned long textSize,
    uintptr_t wrapper,
    uintptr_t *metadataHelper
)
{
    const size_t scanSize =
        0x50;


    if (!metadataHelper ||
        !pxqInText(
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


    /*
     * Variant C wrapper ABI:
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


        if (!pxQoLIsMovReg(
                insns[i],
                19,
                1) ||

            !pxQoLIsMovReg(
                insns[i + 1],
                20,
                0) ||

            !pxQoLIsMovReg(
                insns[i + 2],
                0,
                2) ||

            !pxQoLIsBL(
                insns[i + 3]) ||

            !pxQoLIsMovReg(
                insns[i + 4],
                2,
                0) ||

            !pxQoLDecodeLDUR64(
                insns[i + 5],
                &ldurRt,
                &ldurRn,
                &ldurImm) ||

            ldurRt != 8 ||
            ldurRn != 0 ||
            ldurImm != -8 ||

            !pxQoLIsLDR64UnsignedImm(
                insns[i + 6],
                &loadRt,
                &loadRn,
                &loadImm) ||

            loadRt != 8 ||
            loadRn != 8 ||
            loadImm != 5 ||

            /*
             * 0x28 / 8 = 5
             */

            !pxQoLIsMovReg(
                insns[i + 7],
                0,
                19) ||

            !pxQoLIsMovReg(
                insns[i + 8],
                1,
                20) ||

            !pxQoLDecodeBLR(
                insns[i + 9],
                &blrRn) ||

            blrRn != 8 ||

            !pxQoLIsMovReg(
                insns[i + 10],
                0,
                19) ||

            !pxQoLDecodeBLTarget(
                insns[i + 3],
                (uintptr_t)&insns[i + 3],
                &helper) ||

            !pxqInText(
                text,
                textSize,
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


static bool pxqParseInitialUserStateVariantCCaller(
    uint8_t *text,
    unsigned long textSize,
    const uint32_t *insns,
    size_t count,
    size_t i,
    pxqInitialUserStateVariantCCandidate *candidate
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
     * Variant C caller:
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

    if (!pxQoLDecodeADD64ImmediateNoShift(
            insns[i - 9],
            &beginRd,
            &beginRn,
            &beginImm) ||

        beginRd != 1 ||
        beginRn != 31 ||

        !pxQoLDecodeMovReg(
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

        !pxQoLIsBL(
            insns[i - 5]) ||

        !pxQoLDecodeADRP(
            insns[i - 4],
            (uintptr_t)&insns[i - 4],
            &adrpRd,
            &typePage) ||

        adrpRd != 2 ||

        !pxQoLDecodeADD64ImmediateNoShift(
            insns[i - 3],
            &typeAddRd,
            &typeAddRn,
            &typeAddImm) ||

        typeAddRd != 2 ||
        typeAddRn != 2 ||

        !pxQoLDecodeMovReg(
            insns[i - 2],
            &sourceDst,
            &sourceReg) ||

        sourceDst != 0 ||

        !pxQoLDecodeMovReg(
            insns[i - 1],
            &destinationDst1,
            &destinationReg1) ||

        destinationDst1 != 1 ||
        destinationReg1 !=
            destinationReg0 ||

        !pxQoLIsBL(
            insns[i]) ||

        !pxQoLDecodeADD64ImmediateNoShift(
            insns[i + 1],
            &endRd,
            &endRn,
            &endImm) ||

        endRd != 0 ||
        endRn != 31 ||
        endImm != beginImm ||

        !pxQoLIsBL(
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


    if (!pxQoLDecodeBLTarget(
            insns[i],
            (uintptr_t)&insns[i],
            &wrapper) ||

        !pxqInText(
            text,
            textSize,
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


static bool pxqValidatePixivOAuthUserDescriptor(
    uint8_t *text,
    unsigned long textSize,
    uintptr_t descriptor,
    uintptr_t *metadataAccessor,
    uint32_t *descriptorFieldCount,
    uint32_t *fieldOffsetVectorOffset
)
{
    if (!text ||
        textSize == 0 ||
        descriptor == 0 ||
        !metadataAccessor) {

        return false;
    }


    uint32_t flags = 0;
    uint32_t rawNameRelative = 0;
    uint32_t rawAccessorRelative = 0;
    uint32_t rawFieldsRelative = 0;
    uint32_t numFields = 0;
    uint32_t fieldVectorOffset = 0;


    if (!pxQoLReadU32(
            descriptor + 0x00,
            &flags) ||

        !pxQoLReadU32(
            descriptor + 0x08,
            &rawNameRelative) ||

        !pxQoLReadU32(
            descriptor + 0x0C,
            &rawAccessorRelative) ||

        !pxQoLReadU32(
            descriptor + 0x10,
            &rawFieldsRelative) ||

        !pxQoLReadU32(
            descriptor + 0x14,
            &numFields) ||

        !pxQoLReadU32(
            descriptor + 0x18,
            &fieldVectorOffset)) {

        return false;
    }


    /*
     * Swift ContextDescriptorKind::Struct == 17.
     *
     * Use only the kind bits, not the version-specific/full flags.
     */

    if ((flags & 0x1Fu) !=
            17u ||

        rawNameRelative == 0 ||
        rawAccessorRelative == 0 ||
        rawFieldsRelative == 0 ||

        numFields == 0 ||
        numFields > 64) {

        return false;
    }


    uintptr_t nameAddress =
        0;

    uintptr_t accessor =
        0;

    uintptr_t fields =
        0;


    if (!pxqAddRelative32(
            descriptor + 0x08,
            (int32_t)rawNameRelative,
            &nameAddress) ||

        !pxqAddRelative32(
            descriptor + 0x0C,
            (int32_t)rawAccessorRelative,
            &accessor) ||

        !pxqAddRelative32(
            descriptor + 0x10,
            (int32_t)rawFieldsRelative,
            &fields)) {

        return false;
    }


    char typeName[64];


    if (!pxqReadCString(
            nameAddress,
            typeName,
            sizeof(typeName)) ||

        strcmp(
            typeName,
            "PixivOAuthUser") != 0) {

        return false;
    }


    if (!pxqInText(
            text,
            textSize,
            accessor,
            sizeof(uint32_t))) {

        return false;
    }


    uint32_t fieldHeader =
        0;

    uint32_t fieldCount =
        0;


    if (!pxQoLReadU32(
            fields + 0x08,
            &fieldHeader) ||

        !pxQoLReadU32(
            fields + 0x0C,
            &fieldCount)) {

        return false;
    }


    uint32_t recordSize =
        fieldHeader >> 16;


    if (recordSize < 12 ||
        recordSize > 0x100 ||
        fieldCount != numFields) {

        return false;
    }


    size_t isPremiumCount =
        0;


    for (uint32_t i = 0;
         i < fieldCount;
         i++) {

        uint64_t recordOffset =
            0x10ull +
            (uint64_t)i *
            (uint64_t)recordSize;


        if (recordOffset >
            (uint64_t)UINTPTR_MAX -
            (uint64_t)fields) {

            return false;
        }


        uintptr_t record =
            fields +
            (uintptr_t)recordOffset;

        uint32_t rawFieldNameRelative =
            0;


        if (!pxQoLReadU32(
                record + 0x08,
                &rawFieldNameRelative) ||

            rawFieldNameRelative == 0) {

            return false;
        }


        uintptr_t fieldNameAddress =
            0;


        if (!pxqAddRelative32(
                record + 0x08,
                (int32_t)rawFieldNameRelative,
                &fieldNameAddress)) {

            return false;
        }


        char fieldName[128];


        if (!pxqReadCString(
                fieldNameAddress,
                fieldName,
                sizeof(fieldName))) {

            return false;
        }


        if (strcmp(
                fieldName,
                "isPremium") == 0) {

            isPremiumCount++;
        }
    }


    if (isPremiumCount != 1)
        return false;


    *metadataAccessor =
        accessor;


    if (descriptorFieldCount)
        *descriptorFieldCount =
            numFields;


    if (fieldOffsetVectorOffset)
        *fieldOffsetVectorOffset =
            fieldVectorOffset;


    return true;
}


static bool pxqResolveVariantCTypeRef(
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


    uint64_t raw =
        0;


    if (!pxQoLReadU64(
            typeRef,
            &raw)) {

        return false;
    }


    /*
     * Variant C is currently proven only for the unresolved
     * Swift lazy type-reference cell form:
     *
     *   low32  = signed relative pointer from cell to mangled name
     *   high32 = negative mangled-name length
     *
     * Once Swift resolves the cache, bit63 clears and the cell
     * becomes metadata. That resolved form is intentionally not
     * guessed at in Phase 3A.
     */

    if ((raw &
         0x8000000000000000ull) == 0) {

        return false;
    }


    int32_t mangledRelative =
        (int32_t)(
            raw &
            0xFFFFFFFFu
        );

    int32_t encodedLength =
        (int32_t)(
            raw >>
            32
        );


    if (encodedLength >= 0)
        return false;


    int64_t mangledLength =
        -(int64_t)encodedLength;


    /*
     * Narrow, proven symbolic mangling:
     *
     *   0x02 <rel32 indirect Context> 'S' 'g'
     *
     * Exactly seven bytes, resolving to Optional<PixivOAuthUser>.
     */

    if (mangledLength != 7)
        return false;


    uintptr_t mangled =
        0;


    if (!pxqAddRelative32(
            typeRef,
            mangledRelative,
            &mangled)) {

        return false;
    }


    uint8_t bytes[7];


    if (!pxqReadMemory(
            mangled,
            bytes,
            sizeof(bytes)) ||

        bytes[0] !=
            0x02 ||

        bytes[5] !=
            (uint8_t)'S' ||

        bytes[6] !=
            (uint8_t)'g') {

        return false;
    }


    int32_t descriptorSlotRelative =
        0;


    memcpy(
        &descriptorSlotRelative,
        &bytes[1],
        sizeof(descriptorSlotRelative)
    );


    uintptr_t descriptorSlot =
        0;


    if (!pxqAddRelative32(
            mangled + 1,
            descriptorSlotRelative,
            &descriptorSlot)) {

        return false;
    }


    uint64_t descriptorRaw =
        0;


    if (!pxQoLReadU64(
            descriptorSlot,
            &descriptorRaw) ||

        descriptorRaw == 0) {

        return false;
    }


    uintptr_t resolvedDescriptor =
        (uintptr_t)descriptorRaw;

    uintptr_t accessor =
        0;


    if (!pxqValidatePixivOAuthUserDescriptor(
            text,
            textSize,
            resolvedDescriptor,
            &accessor,
            descriptorFieldCount,
            fieldOffsetVectorOffset)) {

        return false;
    }


    *descriptor =
        resolvedDescriptor;

    *metadataAccessor =
        accessor;


    return true;
}


bool pxqResolveVariantCInitialUserStateAndMetadata(
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


    pxqInitialUserStateVariantCCandidate promotedCandidate;

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

        pxqInitialUserStateVariantCCandidate candidate;


        if (!pxqParseInitialUserStateVariantCCaller(
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


        if (!pxqValidateInitialUserStateVariantCWrapper(
                text,
                textSize,
                candidate.wrapper,
                &metadataHelper)) {

            wrapperRejected++;

            pxQoLLog(
                @"[PixivOAuthUser/Finder] Variant C structural candidate #%zu rejected: wrapper validation failed callsite=text+0x%llx wrapper=text+0x%llx",
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


        if (!pxqValidateVariantCLazyMetadataHelper(
                text,
                textSize,
                metadataHelper)) {

            helperRejected++;

            pxQoLLog(
                @"[PixivOAuthUser/Finder] Variant C structural candidate #%zu rejected: lazy metadata helper validation failed callsite=text+0x%llx helper=text+0x%llx",
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


        if (!pxqResolveVariantCTypeRef(
                text,
                textSize,
                candidate.typeRef,
                &descriptor,
                &metadataAccessor,
                &descriptorFields,
                &fieldVectorOffset)) {

            semanticTypeRejected++;

            pxQoLLog(
                @"[PixivOAuthUser/Finder] Variant C structural candidate #%zu rejected: typeRef is not proven Optional<PixivOAuthUser> callsite=text+0x%llx typeRef=%p",
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
            @"[PixivOAuthUser/Finder] Variant C semantic candidate #%zu: callsite=text+0x%llx wrapper=text+0x%llx source=x%u destination=x%u stackImm=0x%x typeRef=%p helper=text+0x%llx descriptor=%p metadata=text+0x%llx fields=%u fieldOffsetVectorOffset=%u",
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
        @"[PixivOAuthUser/Finder] Variant C summary: exactShape=%zu wrapperRejected=%zu helperRejected=%zu semanticTypeRejected=%zu semanticPromoted=%zu",
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

    if (promotedCount != 1) {

        pxQoLLog(
            @"[PixivOAuthUser/Finder] Variant C rejected: expected exactly 1 semantic Optional<PixivOAuthUser> InitialUserState candidate, got %zu",
            promotedCount
        );

        return false;
    }


    memset(
        match,
        0,
        sizeof(*match)
    );


    match->callsites[0] =
        promotedCandidate.callsite;

    match->callsiteCount =
        1;

    match->originalWrapper =
        promotedCandidate.wrapper;

    match->pixivOAuthUserMetadataAccessor =
        promotedMetadataAccessor;


    pxQoLLog(
        @"[PixivOAuthUser/Finder] Variant C resolved: callsite=text+0x%llx wrapper=text+0x%llx typeRef=%p helper=text+0x%llx descriptor=%p metadata=text+0x%llx fields=%u fieldOffsetVectorOffset=%u",
        (unsigned long long)(
            match->callsites[0] -
            (uintptr_t)text
        ),
        (unsigned long long)(
            match->originalWrapper -
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


    return true;
}


