#ifndef PXQ_BINARY_PATCH_PIXIV_OAUTH_USER_SEMANTICS_H
#define PXQ_BINARY_PATCH_PIXIV_OAUTH_USER_SEMANTICS_H

#include <stdbool.h>
#include <stdint.h>


typedef struct {
    uintptr_t pixivOAuthUserMetadataAccessor;
    uint32_t fieldCount;
    uint32_t fieldOffsetVectorOffset;
} PXQPixivOAuthUserTypeDescriptorEvidence;


/* Static semantic proof for an untrusted descriptor discovered in the image. */
bool pxqValidatePixivOAuthUserTypeDescriptor(
    uint8_t *text,
    unsigned long textSize,
    uintptr_t descriptor,
    PXQPixivOAuthUserTypeDescriptorEvidence *evidence
);

/* Runtime semantic guard and dynamic storage-offset resolution. */
bool pxqResolvePixivOAuthUserPremiumStorageOffset(
    const void *metadata,
    int32_t *storageOffset
);

#endif
