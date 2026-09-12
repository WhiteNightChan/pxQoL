#ifndef PXQ_BINARY_PATCH_PIXIV_OAUTH_USER_ASSIGNMENT_CALL_DISCOVERY_INTERNAL_H
#define PXQ_BINARY_PATCH_PIXIV_OAUTH_USER_ASSIGNMENT_CALL_DISCOVERY_INTERNAL_H

#include <stdint.h>

#import "../../Contract/InterceptionContract.h"


typedef enum {
    PXQ_ASSIGNMENT_CALL_RESOLUTION_INTERNAL_FAILURE = 0,
    PXQ_ASSIGNMENT_CALL_RESOLUTION_RESOLVED = 1,
    PXQ_ASSIGNMENT_CALL_RESOLUTION_NO_QUALIFIED_CANDIDATE = 2,
    PXQ_ASSIGNMENT_CALL_RESOLUTION_REJECTED_AMBIGUOUS = 3,
    PXQ_ASSIGNMENT_CALL_RESOLUTION_REJECTED_INVALID = 4

} PXQAssignmentCallResolutionStatus;


PXQAssignmentCallResolutionStatus pxqDetectTwoArgumentAssignmentCall(
    uint8_t *text,
    unsigned long textSize,
    PXQPixivOAuthUserAssignmentCallContract *result
);

PXQAssignmentCallResolutionStatus pxqDetectTypeReferencedTakeAssignmentCall(
    uint8_t *text,
    unsigned long textSize,
    PXQPixivOAuthUserAssignmentCallContract *result
);

PXQAssignmentCallResolutionStatus pxqDetectTypeReferencedCopyAssignmentCall(
    uint8_t *text,
    unsigned long textSize,
    PXQPixivOAuthUserAssignmentCallContract *result
);

#endif
