#ifndef PXQ_PIXIV_OAUTH_USER_FINDER_USER_STATE_INITIAL_INTERNAL_H
#define PXQ_PIXIV_OAUTH_USER_FINDER_USER_STATE_INITIAL_INTERNAL_H

#import "Finder.h"


static inline bool pxqInText(
    uint8_t *text,
    unsigned long textSize,
    uintptr_t address,
    size_t size
)
{
    uintptr_t start =
        (uintptr_t)text;

    if (address < start)
        return false;

    uintptr_t offset =
        address - start;

    if (offset > (uintptr_t)textSize)
        return false;

    return size <=
        (size_t)textSize -
        (size_t)offset;
}


bool pxqResolveGeneralizedInitialUserStateAndMetadata(
    uint8_t *text,
    unsigned long textSize,
    pxQoLPixivOAuthUserInitialUserStateMatch *result
);


bool pxqResolveVariantCInitialUserStateAndMetadata(
    uint8_t *text,
    unsigned long textSize,
    pxQoLPixivOAuthUserInitialUserStateMatch *result
);


#endif
