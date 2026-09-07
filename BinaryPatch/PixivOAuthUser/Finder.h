#ifndef pxQoLPixivOAuthUserFinder_h
#define pxQoLPixivOAuthUserFinder_h

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#define PXQ_PIXIV_OAUTH_USER_MAX_INITIAL_CALLSITES 2

typedef struct {
    uintptr_t initialCallsites[
        PXQ_PIXIV_OAUTH_USER_MAX_INITIAL_CALLSITES
    ];

    size_t initialCallsiteCount;

    uintptr_t initialOriginalWrapper;
    uintptr_t metadataAccessor;
    uintptr_t laterPremiumLoad;

} pxQoLPixivOAuthUserMatch;


bool pxQoLFindPixivOAuthUserMatch(
    uint8_t *text,
    unsigned long textSize,
    pxQoLPixivOAuthUserMatch *result
);

#endif