#import "Patch.h"
#import "Finder.h"
#import "../Core/pxQoLARM64.h"
#import "../Core/pxQoLMachO.h"
#import "../Core/pxQoLMemoryPatch.h"

#include <stdint.h>
#include <string.h>

#import "../../LogHelper.h"

typedef void *(*PXQInitialUserStateAssignmentWrapperFunc)(
    void *source,
    void *destination
);

typedef void *(*PXQInitialUserStateTypedAssignmentWrapperFunc)(
    void *source,
    void *destination,
    void *typeRef
);

typedef uint32_t (*PXQGetEnumTagSinglePayloadFunc)(
    const void *value,
    uint32_t emptyCases,
    const void *metadata
);

typedef void *(*PXQMetadataAccessorFunc)(
    uintptr_t request
);


static PXQInitialUserStateAssignmentWrapperFunc
    gInitialUserStateOriginalWrapper = NULL;

static PXQInitialUserStateTypedAssignmentWrapperFunc
    gInitialUserStateTypedOriginalWrapper = NULL;

static PXQMetadataAccessorFunc
    gPixivOAuthUserMetadataAccessor = NULL;

static bool
    gLoggedResolvedIsPremiumOffset = false;

static bool
    gLoggedDerivedUserStateSuccess = false;


/*
 * -------------------------------------------------------------
 * Swift runtime metadata resolver
 * -------------------------------------------------------------
 *
 * Runtime layout used here was verified on-device for PixivOAuthUser:
 *
 * Struct metadata:
 *   +0x08  nominal type descriptor pointer
 *
 * TargetStructDescriptor:
 *   +0x08  relative pointer to type name
 *   +0x10  relative pointer to FieldDescriptor
 *   +0x14  NumFields
 *   +0x18  FieldOffsetVectorOffset
 *
 * FieldDescriptor:
 *   +0x0a  FieldRecordSize
 *   +0x0c  NumFields
 *   +0x10  first FieldRecord
 *
 * FieldRecord:
 *   +0x08  relative pointer to field name
 *
 * No fixed field index and no fixed object offset is used.
 */

static bool pxqResolveIsPremiumOffset(
    const void *metadata,
    int32_t *outOffset
)
{
    if (!metadata ||
        !outOffset) {

        return false;
    }


    const uint8_t *metadataBytes =
        (const uint8_t *)metadata;


    const uint8_t *descriptor =
        *(const uint8_t * const *)(
            metadataBytes +
            0x08
        );

    if (!descriptor)
        return false;


    const uint8_t *nameField =
        descriptor +
        0x08;

    int32_t nameRelative =
        *(const int32_t *)nameField;

    if (nameRelative == 0)
        return false;


    const char *typeName =
        (const char *)(
            nameField +
            nameRelative
        );

    if (!typeName ||
        strcmp(
            typeName,
            "PixivOAuthUser"
        ) != 0) {

        return false;
    }


    const uint8_t *fieldsField =
        descriptor +
        0x10;

    int32_t fieldsRelative =
        *(const int32_t *)fieldsField;

    if (fieldsRelative == 0)
        return false;


    const uint8_t *fields =
        fieldsField +
        fieldsRelative;


    uint32_t numFields =
        *(const uint32_t *)(
            descriptor +
            0x14
        );

    uint32_t fieldOffsetVectorOffset =
        *(const uint32_t *)(
            descriptor +
            0x18
        );


    /*
     * Conservative sanity bounds.
     *
     * These are not Pixiv version constants. They only prevent a
     * malformed/misidentified descriptor from causing an unbounded
     * metadata walk.
     */
    if (numFields == 0 ||
        numFields > 64 ||
        fieldOffsetVectorOffset == 0 ||
        fieldOffsetVectorOffset > 0x100) {

        return false;
    }


    uint16_t fieldRecordSize =
        *(const uint16_t *)(
            fields +
            0x0a
        );

    uint32_t fieldDescriptorNumFields =
        *(const uint32_t *)(
            fields +
            0x0c
        );


    if (fieldRecordSize < 12 ||
        fieldRecordSize > 64 ||
        fieldDescriptorNumFields !=
            numFields) {

        return false;
    }


    size_t isPremiumMatchCount =
        0;

    uint32_t isPremiumFieldIndex =
        0;


    const uint8_t *firstRecord =
        fields +
        0x10;


    for (uint32_t i = 0;
         i < fieldDescriptorNumFields;
         i++) {

        const uint8_t *record =
            firstRecord +
            ((size_t)i *
             (size_t)fieldRecordSize);

        const uint8_t *fieldNameField =
            record +
            0x08;

        int32_t fieldNameRelative =
            *(const int32_t *)fieldNameField;

        if (fieldNameRelative == 0)
            continue;


        const char *fieldName =
            (const char *)(
                fieldNameField +
                fieldNameRelative
            );


        if (fieldName &&
            strcmp(
                fieldName,
                "isPremium"
            ) == 0) {

            isPremiumMatchCount++;
            isPremiumFieldIndex =
                i;
        }
    }


    /*
     * Duplicate or missing field names are rejected.
     */
    if (isPremiumMatchCount != 1)
        return false;


    size_t fieldOffsetVectorStart =
        (size_t)fieldOffsetVectorOffset *
        sizeof(uintptr_t);

    size_t fieldSlotOffset =
        fieldOffsetVectorStart +
        ((size_t)isPremiumFieldIndex *
         sizeof(uint32_t));


    int32_t objectOffset =
        *(const int32_t *)(
            metadataBytes +
            fieldSlotOffset
        );


    /*
     * A stored-property byte offset must be non-negative.
     * Keep a generous upper bound solely as a corruption guard.
     */
    if (objectOffset < 0 ||
        objectOffset > 0x1000) {

        return false;
    }


    *outOffset =
        objectOffset;

    return true;
}


static bool pxqPixivOAuthUserOptionalHasPayload(
    const void *value,
    const void *pixivOAuthUserMetadata,
    bool *outHasPayload
)
{
    if (!value ||
        !pixivOAuthUserMetadata ||
        !outHasPayload) {

        return false;
    }


    const uint8_t *metadataBytes =
        (const uint8_t *)pixivOAuthUserMetadata;

    const uint8_t *valueWitnessTable =
        *(const uint8_t * const *)(
            metadataBytes -
            sizeof(uintptr_t)
        );

    if (!valueWitnessTable)
        return false;


    /*
     * Swift Value Witness Table +0x30 is
     * getEnumTagSinglePayload.
     *
     * The 8.4.6 Pixiv code path was verified to use the
     * PixivOAuthUser VWT this way for an Optional<PixivOAuthUser>
     * storage value:
     *
     *   tag = getEnumTagSinglePayload(value, 1, metadata)
     *
     *   tag == 0  -> payload is present
     *   tag == 1  -> empty / nil
     *
     * Reject any other result instead of guessing.
     */
    uintptr_t getEnumTagAddress =
        *(const uintptr_t *)(
            valueWitnessTable +
            0x30
        );

    if (getEnumTagAddress == 0)
        return false;


    PXQGetEnumTagSinglePayloadFunc getEnumTagSinglePayload =
        (PXQGetEnumTagSinglePayloadFunc)
        getEnumTagAddress;

    uint32_t tag =
        getEnumTagSinglePayload(
            value,
            1,
            pixivOAuthUserMetadata
        );


    if (tag > 1)
        return false;


    *outHasPayload =
        (tag == 0);

    return true;
}


static bool pxqForcePremium(
    void *destination,
    const void *metadata
)
{
    if (!destination ||
        !metadata) {

        return false;
    }


    int32_t isPremiumOffset =
        0;

    if (!pxqResolveIsPremiumOffset(
            metadata,
            &isPremiumOffset)) {

        return false;
    }


    if (!gLoggedResolvedIsPremiumOffset) {
        pxQoLLog(
            @"[PixivOAuthUser/Runtime] resolved isPremium objectOffset=%d",
            (int)isPremiumOffset
        );

        gLoggedResolvedIsPremiumOffset =
            true;
    }


    *((uint8_t *)destination +
      (size_t)isPremiumOffset) = 1;

    return true;
}


/*
 * -------------------------------------------------------------
 * InitialUserState trampolines
 * -------------------------------------------------------------
 *
 * TWO_ARG_ASSIGNMENT:
 *
 *   x0 = source
 *   x1 = destination
 *
 * TYPE_REF_X2_ASSIGNMENT:
 *
 *   x0 = source
 *   x1 = destination
 *   x2 = Optional<PixivOAuthUser> type-reference/cache cell
 *
 * Both paths execute the original Swift assignment first.
 */

__attribute__((noinline))
static void *pxQoLInitialUserStatePremiumTrampoline(
    void *source,
    void *destination
)
{
    /*
     * Preserve the original Swift assignment completely first.
     * gInitialUserStateOriginalWrapper is installed before any callsite is patched.
     */
    void *result =
        gInitialUserStateOriginalWrapper(
            source,
            destination
        );


    PXQMetadataAccessorFunc accessor =
        gPixivOAuthUserMetadataAccessor;

    if (!accessor ||
        !destination) {

        return result;
    }


    void *metadata =
        accessor(0);

    if (!metadata)
        return result;


    if (!pxqForcePremium(
            destination,
            metadata)) {

        pxQoLLog(
            @"[PixivOAuthUser/Runtime] InitialUserState isPremium resolver rejected metadata=%p destination=%p",
            metadata,
            destination
        );
    }


    return result;
}


__attribute__((noinline))
static void *pxQoLInitialUserStateTypedPremiumTrampoline(
    void *source,
    void *destination,
    void *typeRef
)
{
    /*
     * Preserve x2/typeRef when forwarding to the original typed
     * Swift assignment wrapper. The wrapper itself owns resolution
     * of that lazy type-reference/cache cell.
     */
    void *result =
        gInitialUserStateTypedOriginalWrapper(
            source,
            destination,
            typeRef
        );


    PXQMetadataAccessorFunc accessor =
        gPixivOAuthUserMetadataAccessor;

    if (!accessor ||
        !destination) {

        return result;
    }


    void *metadata =
        accessor(0);

    if (!metadata)
        return result;


    bool hasPayload =
        false;

    if (!pxqPixivOAuthUserOptionalHasPayload(
            destination,
            metadata,
            &hasPayload)) {

        pxQoLLog(
            @"[PixivOAuthUser/Runtime] InitialUserState typed Optional payload check rejected metadata=%p destination=%p typeRef=%p",
            metadata,
            destination,
            typeRef
        );

        return result;
    }


    /*
     * nil is a normal Optional state. Do not touch its storage.
     */
    if (!hasPayload)
        return result;


    /*
     * For a present single-payload value the payload begins at the
     * same value address. Only after the VWT tag check do we treat
     * destination as PixivOAuthUser storage.
     */
    if (!pxqForcePremium(
            destination,
            metadata)) {

        pxQoLLog(
            @"[PixivOAuthUser/Runtime] InitialUserState typed isPremium resolver rejected metadata=%p destination=%p",
            metadata,
            destination
        );
    }


    return result;
}


/*
 * -------------------------------------------------------------
 * DerivedUserState finalization trampolines
 * -------------------------------------------------------------
 *
 * Finder publishes one or more strongly validated assignment
 * finalizers together with the register-allocation variant.
 *
 * Variant A:
 *
 *   x19 = destination
 *   x21 = PixivOAuthUser metadata
 *   mov x0,x19              <- replaced by BL
 *
 * Variant B:
 *
 *   x21 = destination
 *   x19 = PixivOAuthUser metadata
 *   mov x0,x21              <- replaced by BL
 *
 * Both naked bridges tail-branch to the same C helper. The helper
 * validates runtime metadata identity and resolves the field named
 * exactly "isPremium" before writing. If a structurally matching
 * function belongs to another Swift type, pxqForcePremium() rejects
 * it and the helper simply returns destination in x0, preserving the
 * semantic effect of the replaced MOV.
 */

__attribute__((noinline, used))
void *pxQoLDerivedUserStatePremiumFinalizeHelper(
    void *destination,
    void *metadata
)
{
    bool forced =
        pxqForcePremium(
            destination,
            metadata
        );

    if (!forced) {
        pxQoLLog(
            @"[PixivOAuthUser/Runtime] DerivedUserState resolver rejected metadata=%p destination=%p",
            metadata,
            destination
        );
    }
    else if (!gLoggedDerivedUserStateSuccess) {
        pxQoLLog(
            @"[PixivOAuthUser/Runtime] DerivedUserState applied destination=%p metadata=%p",
            destination,
            metadata
        );

        gLoggedDerivedUserStateSuccess =
            true;
    }


    return destination;
}


#if defined(__aarch64__)

__attribute__((naked, noinline, used))
static void *pxQoLDerivedUserStatePremiumTrampolineX19X21(void)
{
    __asm__(
        "mov x0, x19\n"
        "mov x1, x21\n"
        "b _pxQoLDerivedUserStatePremiumFinalizeHelper\n"
    );
}


__attribute__((naked, noinline, used))
static void *pxQoLDerivedUserStatePremiumTrampolineX21X19(void)
{
    __asm__(
        "mov x0, x21\n"
        "mov x1, x19\n"
        "b _pxQoLDerivedUserStatePremiumFinalizeHelper\n"
    );
}

#else

/*
 * This tweak targets arm64 iOS only. Keep non-arm64 builds from
 * silently producing bridges with different register semantics.
 */
__attribute__((noinline, used))
static void *pxQoLDerivedUserStatePremiumTrampolineX19X21(void)
{
    return NULL;
}


__attribute__((noinline, used))
static void *pxQoLDerivedUserStatePremiumTrampolineX21X19(void)
{
    return NULL;
}

#endif


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


    bool initialUserStateVariantSupported =
        (match.initialUserState.variant ==
            PXQ_PIXIV_OAUTH_USER_INITIAL_USER_STATE_VARIANT_TWO_ARG_ASSIGNMENT ||
         match.initialUserState.variant ==
            PXQ_PIXIV_OAUTH_USER_INITIAL_USER_STATE_VARIANT_TYPE_REF_X2_ASSIGNMENT);


    if (!initialUserStateVariantSupported ||
        match.initialUserState.callsiteCount == 0 ||
        match.initialUserState.callsiteCount >
            PXQ_PIXIV_OAUTH_USER_MAX_INITIAL_USER_STATE_CALLSITES ||
        (match.initialUserState.variant ==
            PXQ_PIXIV_OAUTH_USER_INITIAL_USER_STATE_VARIANT_TYPE_REF_X2_ASSIGNMENT &&
         match.initialUserState.callsiteCount != 1) ||
        match.initialUserState.originalWrapper == 0 ||
        match.initialUserState.pixivOAuthUserMetadataAccessor == 0 ||
        match.derivedUserState.finalizeCount == 0 ||
        match.derivedUserState.finalizeCount >
            PXQ_PIXIV_OAUTH_USER_MAX_DERIVED_USER_STATE_FINALIZERS) {

        pxQoLLog(
            @"[PixivOAuthUser] FAIL [4] invalid finder result"
        );
        return NO;
    }


    for (size_t i = 0;
         i < match.derivedUserState.finalizeCount;
         i++) {

        if (match.derivedUserState.finalizers[i].
                finalizeCallsite == 0 ||

            (match.derivedUserState.finalizers[i].variant !=
                PXQ_PIXIV_OAUTH_USER_DERIVED_USER_STATE_VARIANT_DEST_X19_METADATA_X21 &&

             match.derivedUserState.finalizers[i].variant !=
                PXQ_PIXIV_OAUTH_USER_DERIVED_USER_STATE_VARIANT_DEST_X21_METADATA_X19)) {

            pxQoLLog(
                @"[PixivOAuthUser] FAIL [4] invalid DerivedUserState finalizer[%zu]",
                i
            );

            return NO;
        }
    }


    uintptr_t imageBase =
        (uintptr_t)header;


    pxQoLLog(
        @"[PixivOAuthUser] initialUserStateCallsiteCount=%zu",
        match.initialUserState.callsiteCount
    );


    for (size_t i = 0;
         i < match.initialUserState.callsiteCount;
         i++) {

        pxQoLLog(
            @"[PixivOAuthUser] initialUserState[%zu]=pixiv+0x%llx",
            i,
            (unsigned long long)(
                match.initialUserState.callsites[i] -
                imageBase
            )
        );
    }


    pxQoLLog(
        @"[PixivOAuthUser] initialUserStateOriginalWrapper=pixiv+0x%llx",
        (unsigned long long)(
            match.initialUserState.originalWrapper -
            imageBase
        )
    );


    pxQoLLog(
        @"[PixivOAuthUser] pixivOAuthUserMetadataAccessor=pixiv+0x%llx",
        (unsigned long long)(
            match.initialUserState.pixivOAuthUserMetadataAccessor -
            imageBase
        )
    );


    pxQoLLog(
        @"[PixivOAuthUser] derivedUserStateFinalizeCount=%zu",
        match.derivedUserState.finalizeCount
    );


    for (size_t i = 0;
         i < match.derivedUserState.finalizeCount;
         i++) {

        pxQoLLog(
            @"[PixivOAuthUser] derivedUserState[%zu]=pixiv+0x%llx variant=%u",
            i,
            (unsigned long long)(
                match.derivedUserState.finalizers[i].
                    finalizeCallsite -
                imageBase
            ),
            (unsigned int)
                match.derivedUserState.finalizers[i].variant
        );
    }


    /*
     * ---------------------------------------------------------
     * Build every patch instruction before changing memory.
     * ---------------------------------------------------------
     */

    uint32_t initialUserStateInstructions[
        PXQ_PIXIV_OAUTH_USER_MAX_INITIAL_USER_STATE_CALLSITES
    ] = {0};


    uintptr_t initialUserStateTrampolineAddress =
        0;


    switch (match.initialUserState.variant) {

        case PXQ_PIXIV_OAUTH_USER_INITIAL_USER_STATE_VARIANT_TWO_ARG_ASSIGNMENT:
            initialUserStateTrampolineAddress =
                (uintptr_t)
                &pxQoLInitialUserStatePremiumTrampoline;
            break;

        case PXQ_PIXIV_OAUTH_USER_INITIAL_USER_STATE_VARIANT_TYPE_REF_X2_ASSIGNMENT:
            initialUserStateTrampolineAddress =
                (uintptr_t)
                &pxQoLInitialUserStateTypedPremiumTrampoline;
            break;

        default:
            pxQoLLog(
                @"[PixivOAuthUser] FAIL [5] unsupported InitialUserState variant=%u",
                (unsigned int)match.initialUserState.variant
            );
            return NO;
    }


    for (size_t i = 0;
         i < match.initialUserState.callsiteCount;
         i++) {

        if (!pxQoLMakeBL(
                match.initialUserState.callsites[i],
                initialUserStateTrampolineAddress,
                &initialUserStateInstructions[i])) {

            pxQoLLog(
                @"[PixivOAuthUser] FAIL [5] InitialUserState trampoline BL out of range at initial[%zu]",
                i
            );

            pxQoLLog(
                @"[PixivOAuthUser]   source=%p target=%p",
                (void *)match.initialUserState.callsites[i],
                (void *)initialUserStateTrampolineAddress
            );

            return NO;
        }
    }


#if !defined(__aarch64__)

    pxQoLLog(
        @"[PixivOAuthUser] FAIL [6] DerivedUserState trampolines require arm64"
    );
    return NO;

#else

    uint32_t derivedUserStateInstructions[
        PXQ_PIXIV_OAUTH_USER_MAX_DERIVED_USER_STATE_FINALIZERS
    ] = {0};


    for (size_t i = 0;
         i < match.derivedUserState.finalizeCount;
         i++) {

        uintptr_t trampolineAddress =
            0;


        switch (match.derivedUserState.finalizers[i].variant) {

            case PXQ_PIXIV_OAUTH_USER_DERIVED_USER_STATE_VARIANT_DEST_X19_METADATA_X21:
                trampolineAddress =
                    (uintptr_t)
                    &pxQoLDerivedUserStatePremiumTrampolineX19X21;
                break;

            case PXQ_PIXIV_OAUTH_USER_DERIVED_USER_STATE_VARIANT_DEST_X21_METADATA_X19:
                trampolineAddress =
                    (uintptr_t)
                    &pxQoLDerivedUserStatePremiumTrampolineX21X19;
                break;

            default:
                pxQoLLog(
                    @"[PixivOAuthUser] FAIL [6] unsupported DerivedUserState variant at index=%zu variant=%u",
                    i,
                    (unsigned int)
                        match.derivedUserState.finalizers[i].variant
                );

                return NO;
        }


        if (!pxQoLMakeBL(
                match.derivedUserState.finalizers[i].
                    finalizeCallsite,
                trampolineAddress,
                &derivedUserStateInstructions[i])) {

            pxQoLLog(
                @"[PixivOAuthUser] FAIL [6] DerivedUserState trampoline BL out of range at index=%zu variant=%u",
                i,
                (unsigned int)
                    match.derivedUserState.finalizers[i].variant
            );

            pxQoLLog(
                @"[PixivOAuthUser]   source=%p target=%p",
                (void *)
                    match.derivedUserState.finalizers[i].
                        finalizeCallsite,
                (void *)trampolineAddress
            );

            return NO;
        }
    }

#endif


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
     * Globals must be valid before any InitialUserState callsite can branch
     * to the trampoline.
     */
    switch (match.initialUserState.variant) {

        case PXQ_PIXIV_OAUTH_USER_INITIAL_USER_STATE_VARIANT_TWO_ARG_ASSIGNMENT:
            gInitialUserStateOriginalWrapper =
                (PXQInitialUserStateAssignmentWrapperFunc)
                match.initialUserState.originalWrapper;
            break;

        case PXQ_PIXIV_OAUTH_USER_INITIAL_USER_STATE_VARIANT_TYPE_REF_X2_ASSIGNMENT:
            gInitialUserStateTypedOriginalWrapper =
                (PXQInitialUserStateTypedAssignmentWrapperFunc)
                match.initialUserState.originalWrapper;
            break;

        default:
            /*
             * Rejected above before any instruction generation.
             */
            return NO;
    }


    gPixivOAuthUserMetadataAccessor =
        (PXQMetadataAccessorFunc)
        match.initialUserState.pixivOAuthUserMetadataAccessor;


    struct LHMemoryPatch patches[
        PXQ_PIXIV_OAUTH_USER_MAX_INITIAL_USER_STATE_CALLSITES +
        PXQ_PIXIV_OAUTH_USER_MAX_DERIVED_USER_STATE_FINALIZERS
    ];

    int patchCount =
        0;


    for (size_t i = 0;
         i < match.initialUserState.callsiteCount;
         i++) {

        patches[patchCount++] =
            (struct LHMemoryPatch) {
                .destination =
                    (void *)match.initialUserState.callsites[i],
                .data =
                    &initialUserStateInstructions[i],
                .size =
                    sizeof(initialUserStateInstructions[i]),
                .options =
                    NULL
            };
    }


#if defined(__aarch64__)

    for (size_t i = 0;
         i < match.derivedUserState.finalizeCount;
         i++) {

        patches[patchCount++] =
            (struct LHMemoryPatch) {
                .destination =
                    (void *)
                    match.derivedUserState.finalizers[i].
                        finalizeCallsite,
                .data =
                    &derivedUserStateInstructions[i],
                .size =
                    sizeof(derivedUserStateInstructions[i]),
                .options =
                    NULL
            };
    }

#endif


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
     * Keep the raw result for diagnostics, then verify every patched
     * 32-bit ARM64 instruction directly from memory.
     */
    pxQoLLog(
        @"[PixivOAuthUser] LHPatchMemory result=%d count=%d",
        patchResult,
        patchCount
    );


    for (int i = 0;
         i < patchCount;
         i++) {

        if (patches[i].size !=
            sizeof(uint32_t)) {

            pxQoLLog(
                @"[PixivOAuthUser] FAIL [8] unexpected patch size at index=%d size=%zu",
                i,
                patches[i].size
            );

            /*
             * Do not clear gInitialUserStateOriginalWrapper / gPixivOAuthUserMetadataAccessor.
             * LHPatchMemory is not assumed to be transactional;
             * an InitialUserState BL may already point to the trampoline.
             */
            return NO;
        }


        uint32_t actualInstruction =
            0;


        if (!pxQoLReadU32(
                (uintptr_t)patches[i].destination,
                &actualInstruction)) {

            pxQoLLog(
                @"[PixivOAuthUser] FAIL [8] read-back failed at index=%d address=%p",
                i,
                patches[i].destination
            );

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
