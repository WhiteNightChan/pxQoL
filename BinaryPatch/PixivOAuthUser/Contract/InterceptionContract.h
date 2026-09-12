#ifndef PXQ_BINARY_PATCH_PIXIV_OAUTH_USER_INTERCEPTION_CONTRACT_H
#define PXQ_BINARY_PATCH_PIXIV_OAUTH_USER_INTERCEPTION_CONTRACT_H

#include <stddef.h>
#include <stdint.h>


#define PXQ_PIXIV_OAUTH_USER_MAX_ASSIGNMENT_CALL_SITES 2
#define PXQ_PIXIV_OAUTH_USER_MAX_ASSIGNMENT_RETURN_SITES 4


typedef enum {
    PXQ_PIXIV_OAUTH_USER_ASSIGNMENT_CALL_NONE = 0,
    PXQ_PIXIV_OAUTH_USER_ASSIGNMENT_CALL_TWO_ARGUMENT = 1,
    PXQ_PIXIV_OAUTH_USER_ASSIGNMENT_CALL_WITH_TYPE_REFERENCE = 2

} PXQPixivOAuthUserAssignmentCallKind;


typedef struct {
    PXQPixivOAuthUserAssignmentCallKind kind;

    uintptr_t callSites[
        PXQ_PIXIV_OAUTH_USER_MAX_ASSIGNMENT_CALL_SITES
    ];

    size_t callSiteCount;

    uintptr_t originalAssignmentWrapper;
    uintptr_t pixivOAuthUserMetadataAccessor;

} PXQPixivOAuthUserAssignmentCallContract;


typedef struct {
    uint8_t destinationRegister;
    uint8_t metadataRegister;

} PXQAssignmentReturnCapture;


typedef struct {
    uintptr_t patchSite;
    PXQAssignmentReturnCapture capture;

} PXQPixivOAuthUserAssignmentReturnSite;


typedef struct {
    PXQPixivOAuthUserAssignmentReturnSite sites[
        PXQ_PIXIV_OAUTH_USER_MAX_ASSIGNMENT_RETURN_SITES
    ];

    size_t siteCount;

} PXQPixivOAuthUserAssignmentReturnContract;


typedef struct {
    PXQPixivOAuthUserAssignmentCallContract assignmentCall;
    PXQPixivOAuthUserAssignmentReturnContract assignmentReturn;

} PXQPixivOAuthUserInterceptionContract;


#endif
