#import "RuntimeOverride.h"
#import "../Contract/InterceptionContract.h"
#import "../../SwiftABI/Metadata.h"
#import "../../SwiftABI/ValueWitness.h"
#import "../../../LogHelper.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>


typedef void *(*PXQSwiftTwoArgumentAssignmentFunction)(
    void *source,
    void *destination
);


typedef void *(*PXQSwiftTypeReferencedAssignmentFunction)(
    void *source,
    void *destination,
    void *typeReference
);


typedef struct {
    PXQPixivOAuthUserAssignmentCallKind invocationKind;

    union {
        PXQSwiftTwoArgumentAssignmentFunction twoArgumentWrapper;
        PXQSwiftTypeReferencedAssignmentFunction typeReferencedWrapper;
    } originalAssignment;

    PXQSwiftMetadataAccessorFunction pixivOAuthUserMetadataAccessor;

} PXQAssignmentCallRuntimeContext;


static PXQAssignmentCallRuntimeContext
    gAssignmentCallRuntimeContext = {0};


static bool pxqCheckPixivOAuthUserOptionalPayload(
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


    /*
     * The 8.4.6 Pixiv code path was verified to use
     * getEnumTagSinglePayload from the PixivOAuthUser VWT for an
     * Optional<PixivOAuthUser> storage value. VWT layout knowledge
     * lives in SwiftABI/ValueWitness; Optional interpretation remains
     * here because this runtime path is PixivOAuthUser-specific.
     */
    PXQSwiftGetEnumTagSinglePayloadFunction getEnumTagSinglePayload =
        NULL;

    if (!pxqSwiftRuntimeGetEnumTagSinglePayloadFunction(
            pixivOAuthUserMetadata,
            &getEnumTagSinglePayload)) {

        return false;
    }


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


__attribute__((noinline))
static void *pxqAssignmentCallTwoArgumentTrampoline(
    void *source,
    void *destination
)
{
    PXQSwiftTwoArgumentAssignmentFunction originalWrapper =
        gAssignmentCallRuntimeContext.
            originalAssignment.twoArgumentWrapper;

    /*
     * Runtime context is published before any callsite is patched.
     * Preserve the original Swift assignment exactly once and first.
     */
    void *result =
        originalWrapper(
            source,
            destination
        );


    PXQSwiftMetadataAccessorFunction accessor =
        gAssignmentCallRuntimeContext.
            pixivOAuthUserMetadataAccessor;

    if (!accessor ||
        !destination) {

        return result;
    }


    void *metadata =
        accessor(0);

    if (!metadata)
        return result;


    if (!pxqApplyPixivOAuthUserPremiumOverride(
            destination,
            metadata)) {

        pxQoLLog(
            @"[PixivOAuthUser/Runtime] AssignmentCall TwoArgument isPremium resolver rejected metadata=%p destination=%p",
            metadata,
            destination
        );
    }


    return result;
}


__attribute__((noinline))
static void *pxqAssignmentCallTypeReferencedTrampoline(
    void *source,
    void *destination,
    void *typeReference
)
{
    PXQSwiftTypeReferencedAssignmentFunction originalWrapper =
        gAssignmentCallRuntimeContext.
            originalAssignment.typeReferencedWrapper;

    /*
     * Preserve x2/typeReference unchanged when forwarding to the exact
     * Swift assignment wrapper supplied by the normalized contract.
     */
    void *result =
        originalWrapper(
            source,
            destination,
            typeReference
        );


    PXQSwiftMetadataAccessorFunction accessor =
        gAssignmentCallRuntimeContext.
            pixivOAuthUserMetadataAccessor;

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

    if (!pxqCheckPixivOAuthUserOptionalPayload(
            destination,
            metadata,
            &hasPayload)) {

        pxQoLLog(
            @"[PixivOAuthUser/Runtime] AssignmentCall TypeReferenced Optional payload check rejected metadata=%p destination=%p typeReference=%p",
            metadata,
            destination,
            typeReference
        );

        return result;
    }


    /*
     * nil is a normal Optional state. Do not mutate its storage.
     */
    if (!hasPayload)
        return result;


    /*
     * For a present single-payload value the payload begins at the
     * same value address. Only after the VWT tag check do we treat
     * destination as PixivOAuthUser storage.
     */
    if (!pxqApplyPixivOAuthUserPremiumOverride(
            destination,
            metadata)) {

        pxQoLLog(
            @"[PixivOAuthUser/Runtime] AssignmentCall TypeReferenced isPremium resolver rejected metadata=%p destination=%p",
            metadata,
            destination
        );
    }


    return result;
}


bool pxqResolveAssignmentCallRuntimeEntry(
    PXQPixivOAuthUserAssignmentCallKind kind,
    uintptr_t *runtimeEntryAddress
)
{
    if (!runtimeEntryAddress)
        return false;


    uintptr_t resolvedEntryAddress =
        0;


    switch (kind) {

        case PXQ_PIXIV_OAUTH_USER_ASSIGNMENT_CALL_TWO_ARGUMENT:
            resolvedEntryAddress =
                (uintptr_t)
                &pxqAssignmentCallTwoArgumentTrampoline;
            break;

        case PXQ_PIXIV_OAUTH_USER_ASSIGNMENT_CALL_WITH_TYPE_REFERENCE:
            resolvedEntryAddress =
                (uintptr_t)
                &pxqAssignmentCallTypeReferencedTrampoline;
            break;

        default:
            return false;
    }


    *runtimeEntryAddress =
        resolvedEntryAddress;

    return true;
}


bool pxqPublishAssignmentCallRuntimeContext(
    const PXQPixivOAuthUserAssignmentCallContract *contract
)
{
    if (!contract ||
        contract->originalAssignmentWrapper == 0 ||
        contract->pixivOAuthUserMetadataAccessor == 0) {

        return false;
    }


    PXQAssignmentCallRuntimeContext context = {0};

    context.invocationKind =
        contract->kind;

    context.pixivOAuthUserMetadataAccessor =
        (PXQSwiftMetadataAccessorFunction)
        contract->pixivOAuthUserMetadataAccessor;


    switch (contract->kind) {

        case PXQ_PIXIV_OAUTH_USER_ASSIGNMENT_CALL_TWO_ARGUMENT:
            context.originalAssignment.twoArgumentWrapper =
                (PXQSwiftTwoArgumentAssignmentFunction)
                contract->originalAssignmentWrapper;
            break;

        case PXQ_PIXIV_OAUTH_USER_ASSIGNMENT_CALL_WITH_TYPE_REFERENCE:
            context.originalAssignment.typeReferencedWrapper =
                (PXQSwiftTypeReferencedAssignmentFunction)
                contract->originalAssignmentWrapper;
            break;

        default:
            return false;
    }


    /*
     * Publish only after a complete local context has been built.
     * A failed publication attempt must not damage a context that may
     * already be required by a previously patched callsite.
     */
    gAssignmentCallRuntimeContext =
        context;

    return true;
}
