#import "Finder_UserState_Initial.h"
#import "Finder_UserState_Initial_Internal.h"
#import "../../LogHelper.h"

#include <string.h>


bool pxQoLFindPixivOAuthUserInitialUserState(
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


    /*
     * ---------------------------------------------------------
     * Existing GENERALIZED resolver first
     * ---------------------------------------------------------
     *
     * Existing supported versions stay on the already verified
     * production path. Variant C participates only as a fallback.
     */

    pxQoLPixivOAuthUserInitialUserStateMatch generalizedMatch;

    memset(
        &generalizedMatch,
        0,
        sizeof(generalizedMatch)
    );


    if (pxqResolveGeneralizedInitialUserStateAndMetadata(
            text,
            textSize,
            &generalizedMatch)) {

        generalizedMatch.variant =
            PXQ_PIXIV_OAUTH_USER_INITIAL_USER_STATE_VARIANT_TWO_ARG_ASSIGNMENT;


        *match =
            generalizedMatch;


        pxQoLLog(
            @"[PixivOAuthUser/Finder] InitialUserState/metadata resolution mode=GENERALIZED-ONLY variant=TWO_ARG_ASSIGNMENT"
        );


        return true;
    }


    pxQoLLog(
        @"[PixivOAuthUser/Finder] GENERALIZED InitialUserState/metadata resolution failed; trying Variant C semantic fallback"
    );


    /*
     * ---------------------------------------------------------
     * Variant C semantic fallback
     * ---------------------------------------------------------
     *
     * Required chain:
     *
     * exact caller
     *   -> typed 3-argument assignment wrapper
     *   -> Swift lazy mangled-type metadata helper
     *   -> x2 unresolved type-reference/cache cell
     *   -> Optional<PixivOAuthUser> symbolic mangling
     *   -> PixivOAuthUser Struct descriptor
     *   -> exactly one field named "isPremium"
     *   -> bare PixivOAuthUser metadata accessor
     *
     * Exactly one semantic candidate is mandatory.
     */

    pxQoLPixivOAuthUserInitialUserStateMatch variantCMatch;

    memset(
        &variantCMatch,
        0,
        sizeof(variantCMatch)
    );


    if (!pxqResolveVariantCInitialUserStateAndMetadata(
            text,
            textSize,
            &variantCMatch)) {

        pxQoLLog(
            @"[PixivOAuthUser/Finder] FAIL: InitialUserState/metadata resolution failed for GENERALIZED and Variant C"
        );

        return false;
    }


    variantCMatch.variant =
        PXQ_PIXIV_OAUTH_USER_INITIAL_USER_STATE_VARIANT_TYPE_REF_X2_ASSIGNMENT;


    *match =
        variantCMatch;


    pxQoLLog(
        @"[PixivOAuthUser/Finder] InitialUserState/metadata resolution mode=VARIANT-C variant=TYPE_REF_X2_ASSIGNMENT"
    );


    return true;
}

