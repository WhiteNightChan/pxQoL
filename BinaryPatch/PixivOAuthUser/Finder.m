#import "Finder.h"
#import "Finder_UserState_Initial.h"
#import "Finder_UserState_Derived.h"
#import "../../LogHelper.h"

#include <string.h>


static const char *pxqInitialUserStateVariantName(
    pxQoLPixivOAuthUserInitialUserStateVariant variant
)
{
    switch (variant) {

        case PXQ_PIXIV_OAUTH_USER_INITIAL_USER_STATE_VARIANT_TWO_ARG_ASSIGNMENT:
            return "TWO_ARG_ASSIGNMENT";

        case PXQ_PIXIV_OAUTH_USER_INITIAL_USER_STATE_VARIANT_TYPE_REF_X2_ASSIGNMENT:
            return "TYPE_REF_X2_ASSIGNMENT";

        case PXQ_PIXIV_OAUTH_USER_INITIAL_USER_STATE_VARIANT_TYPE_REF_X2_COPY_ASSIGNMENT:
            return "TYPE_REF_X2_COPY_ASSIGNMENT";

        default:
            return "NONE";
    }
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


    const size_t count =
        textSize /
        sizeof(uint32_t);


    pxQoLLog(
        @"[PixivOAuthUser/Finder] text=%p textSize=0x%lx instructionCount=%zu",
        text,
        textSize,
        count
    );


    if (!pxQoLFindPixivOAuthUserInitialUserState(
            text,
            textSize,
            &match.initialUserState)) {

        return false;
    }


    if (!pxQoLFindPixivOAuthUserDerivedUserState(
            text,
            textSize,
            &match.derivedUserState)) {

        return false;
    }


    *result =
        match;


    pxQoLLog(
        @"[PixivOAuthUser/Finder] SUCCESS initialUserStateVariant=%s: initialUserState=%zu wrapper=text+0x%llx metadata=text+0x%llx derivedUserStateFinalizers=%zu",
        pxqInitialUserStateVariantName(
            match.initialUserState.variant
        ),
        match.initialUserState.callsiteCount,
        (unsigned long long)(
            match.initialUserState.originalWrapper -
            (uintptr_t)text
        ),
        (unsigned long long)(
            match.initialUserState.pixivOAuthUserMetadataAccessor -
            (uintptr_t)text
        ),
        match.derivedUserState.finalizeCount
    );


    return true;
}
