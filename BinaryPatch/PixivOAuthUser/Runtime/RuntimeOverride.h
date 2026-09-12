#ifndef PXQ_BINARY_PATCH_PIXIV_OAUTH_USER_RUNTIME_OVERRIDE_H
#define PXQ_BINARY_PATCH_PIXIV_OAUTH_USER_RUNTIME_OVERRIDE_H

#include <stdbool.h>


bool pxqApplyPixivOAuthUserPremiumOverride(
    void *destination,
    const void *metadata
);


#endif
