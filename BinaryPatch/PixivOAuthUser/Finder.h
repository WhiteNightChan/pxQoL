#ifndef pxQoLPixivOAuthUserFinder_h
#define pxQoLPixivOAuthUserFinder_h

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#define PXQ_PIXIV_OAUTH_USER_MAX_INITIAL_USER_STATE_CALLSITES 2
#define PXQ_PIXIV_OAUTH_USER_MAX_DERIVED_USER_STATE_FINALIZERS 4


typedef enum {
    PXQ_PIXIV_OAUTH_USER_INITIAL_USER_STATE_VARIANT_NONE = 0,

    /*
     * Existing generalized InitialUserState layout:
     *
     *   x0 = source
     *   x1 = destination
     *   bl  assignmentWrapper
     */
    PXQ_PIXIV_OAUTH_USER_INITIAL_USER_STATE_VARIANT_TWO_ARG_ASSIGNMENT = 1,

    /*
     * Typed InitialUserState layout:
     *
     *   x0 = source
     *   x1 = destination
     *   x2 = type-reference/cache cell
     *   bl  assignmentWrapper
     *
     * Finder support is implemented as the semantic fallback.
     * Patch-side ABI support remains a separate step.
     */
    PXQ_PIXIV_OAUTH_USER_INITIAL_USER_STATE_VARIANT_TYPE_REF_X2_ASSIGNMENT = 2

} pxQoLPixivOAuthUserInitialUserStateVariant;


typedef struct {
    pxQoLPixivOAuthUserInitialUserStateVariant variant;

    uintptr_t callsites[
        PXQ_PIXIV_OAUTH_USER_MAX_INITIAL_USER_STATE_CALLSITES
    ];

    size_t callsiteCount;

    uintptr_t originalWrapper;
    uintptr_t pixivOAuthUserMetadataAccessor;

} pxQoLPixivOAuthUserInitialUserStateMatch;


typedef enum {
    PXQ_PIXIV_OAUTH_USER_DERIVED_USER_STATE_VARIANT_NONE = 0,

    /*
     * Confirmed on newer layouts such as 8.8.1:
     *
     *   x19 = destination
     *   x21 = PixivOAuthUser metadata
     *   ...
     *   mov x0,x19
     */
    PXQ_PIXIV_OAUTH_USER_DERIVED_USER_STATE_VARIANT_DEST_X19_METADATA_X21 = 1,

    /*
     * Confirmed by watchpoint + Ghidra on 8.4.10:
     *
     *   x21 = destination
     *   x19 = PixivOAuthUser metadata
     *   ...
     *   mov x0,x21
     */
    PXQ_PIXIV_OAUTH_USER_DERIVED_USER_STATE_VARIANT_DEST_X21_METADATA_X19 = 2

} pxQoLPixivOAuthUserDerivedUserStateVariant;


typedef struct {
    uintptr_t finalizeCallsite;
    pxQoLPixivOAuthUserDerivedUserStateVariant variant;

} pxQoLPixivOAuthUserDerivedUserStateFinalize;


typedef struct {
    pxQoLPixivOAuthUserDerivedUserStateFinalize finalizers[
        PXQ_PIXIV_OAUTH_USER_MAX_DERIVED_USER_STATE_FINALIZERS
    ];

    size_t finalizeCount;

} pxQoLPixivOAuthUserDerivedUserStateMatch;


typedef struct {
    pxQoLPixivOAuthUserInitialUserStateMatch initialUserState;
    pxQoLPixivOAuthUserDerivedUserStateMatch derivedUserState;

} pxQoLPixivOAuthUserMatch;


bool pxQoLFindPixivOAuthUserMatch(
    uint8_t *text,
    unsigned long textSize,
    pxQoLPixivOAuthUserMatch *result
);

#endif
