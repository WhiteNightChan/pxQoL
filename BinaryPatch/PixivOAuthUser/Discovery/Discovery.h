#ifndef PXQ_BINARY_PATCH_PIXIV_OAUTH_USER_DISCOVERY_H
#define PXQ_BINARY_PATCH_PIXIV_OAUTH_USER_DISCOVERY_H

#include <stdbool.h>
#include <stdint.h>

#import "../Contract/InterceptionContract.h"


bool pxqDiscoverPixivOAuthUserInterceptionContract(
    uint8_t *text,
    unsigned long textSize,
    PXQPixivOAuthUserInterceptionContract *result
);

#endif
