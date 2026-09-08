#ifndef PXQ_PIXIV_OAUTH_USER_FINDER_USER_STATE_DERIVED_H
#define PXQ_PIXIV_OAUTH_USER_FINDER_USER_STATE_DERIVED_H

#import "Finder.h"

bool pxQoLFindPixivOAuthUserDerivedUserState(
    uint8_t *text,
    unsigned long textSize,
    pxQoLPixivOAuthUserDerivedUserStateMatch *result
);

#endif
