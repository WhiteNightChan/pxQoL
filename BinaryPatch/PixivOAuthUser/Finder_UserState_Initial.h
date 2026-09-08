#ifndef PXQ_PIXIV_OAUTH_USER_FINDER_USER_STATE_INITIAL_H
#define PXQ_PIXIV_OAUTH_USER_FINDER_USER_STATE_INITIAL_H

#import "Finder.h"

bool pxQoLFindPixivOAuthUserInitialUserState(
    uint8_t *text,
    unsigned long textSize,
    pxQoLPixivOAuthUserInitialUserStateMatch *result
);

#endif
