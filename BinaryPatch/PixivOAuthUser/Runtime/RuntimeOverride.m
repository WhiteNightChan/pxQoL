#import "RuntimeOverride.h"
#import "../Semantics/Semantics.h"
#import "../../../LogHelper.h"

#include <stddef.h>
#include <stdint.h>


static bool
    gLoggedResolvedIsPremiumOffset = false;


bool pxqApplyPixivOAuthUserPremiumOverride(
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

    if (!pxqResolvePixivOAuthUserPremiumStorageOffset(
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
