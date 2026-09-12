#import "AssignmentCallDiscovery.h"
#import "AssignmentCallDiscoveryInternal.h"
#import "../../../../LogHelper.h"

#include <string.h>


static const char *pxqAssignmentCallResolutionStatusName(
    PXQAssignmentCallResolutionStatus status
)
{
    switch (status) {

        case PXQ_ASSIGNMENT_CALL_RESOLUTION_RESOLVED:
            return "Resolved";

        case PXQ_ASSIGNMENT_CALL_RESOLUTION_NO_QUALIFIED_CANDIDATE:
            return "NoQualifiedCandidate";

        case PXQ_ASSIGNMENT_CALL_RESOLUTION_REJECTED_AMBIGUOUS:
            return "RejectedAmbiguous";

        case PXQ_ASSIGNMENT_CALL_RESOLUTION_REJECTED_INVALID:
            return "RejectedInvalid";

        default:
            return "InternalFailure";
    }
}


bool pxqDiscoverPixivOAuthUserAssignmentCallInterception(
    uint8_t *text,
    unsigned long textSize,
    PXQPixivOAuthUserAssignmentCallContract *result
)
{
    if (!text ||
        textSize == 0 ||
        !result) {

        return false;
    }


    memset(
        result,
        0,
        sizeof(*result)
    );


    /*
     * Keep the existing production order exactly:
     *
     * TwoArgument
     *     -> on any existing TwoArgument failure, try TypeReferenced Take
     * TypeReferenced Take
     *     -> only NoQualifiedCandidate may fall back to Copy
     * TypeReferenced Copy
     *
     * The status distinction is intentionally introduced only to prevent
     * ambiguous/invalid/internal Take failures from being treated as
     * "not found" and silently falling through to Copy.
     */

    PXQPixivOAuthUserAssignmentCallContract twoArgumentContract;

    memset(
        &twoArgumentContract,
        0,
        sizeof(twoArgumentContract)
    );


    PXQAssignmentCallResolutionStatus twoArgumentStatus =
        pxqDetectTwoArgumentAssignmentCall(
            text,
            textSize,
            &twoArgumentContract
        );


    if (twoArgumentStatus ==
        PXQ_ASSIGNMENT_CALL_RESOLUTION_RESOLVED) {

        twoArgumentContract.kind =
            PXQ_PIXIV_OAUTH_USER_ASSIGNMENT_CALL_TWO_ARGUMENT;

        *result =
            twoArgumentContract;

        pxQoLLog(
            @"[PixivOAuthUser/Discovery/AssignmentCall] selected kind=TWO_ARGUMENT evidence=assignWithTake"
        );

        return true;
    }


    pxQoLLog(
        @"[PixivOAuthUser/Discovery/AssignmentCall] TwoArgument unresolved status=%s; trying TypeReferenced Take",
        pxqAssignmentCallResolutionStatusName(
            twoArgumentStatus
        )
    );


    PXQPixivOAuthUserAssignmentCallContract takeContract;

    memset(
        &takeContract,
        0,
        sizeof(takeContract)
    );


    PXQAssignmentCallResolutionStatus takeStatus =
        pxqDetectTypeReferencedTakeAssignmentCall(
            text,
            textSize,
            &takeContract
        );


    if (takeStatus ==
        PXQ_ASSIGNMENT_CALL_RESOLUTION_RESOLVED) {

        takeContract.kind =
            PXQ_PIXIV_OAUTH_USER_ASSIGNMENT_CALL_WITH_TYPE_REFERENCE;

        *result =
            takeContract;

        pxQoLLog(
            @"[PixivOAuthUser/Discovery/AssignmentCall] selected kind=WITH_TYPE_REFERENCE evidence=assignWithTake"
        );

        return true;
    }


    if (takeStatus !=
        PXQ_ASSIGNMENT_CALL_RESOLUTION_NO_QUALIFIED_CANDIDATE) {

        pxQoLLog(
            @"[PixivOAuthUser/Discovery/AssignmentCall] FAIL: TypeReferenced Take rejected status=%s; Copy fallback prohibited",
            pxqAssignmentCallResolutionStatusName(
                takeStatus
            )
        );

        return false;
    }


    pxQoLLog(
        @"[PixivOAuthUser/Discovery/AssignmentCall] TypeReferenced Take status=NoQualifiedCandidate; trying assignWithCopy fallback"
    );


    PXQPixivOAuthUserAssignmentCallContract copyContract;

    memset(
        &copyContract,
        0,
        sizeof(copyContract)
    );


    PXQAssignmentCallResolutionStatus copyStatus =
        pxqDetectTypeReferencedCopyAssignmentCall(
            text,
            textSize,
            &copyContract
        );


    if (copyStatus !=
        PXQ_ASSIGNMENT_CALL_RESOLUTION_RESOLVED) {

        pxQoLLog(
            @"[PixivOAuthUser/Discovery/AssignmentCall] FAIL: TypeReferenced Copy unresolved status=%s",
            pxqAssignmentCallResolutionStatusName(
                copyStatus
            )
        );

        return false;
    }


    copyContract.kind =
        PXQ_PIXIV_OAUTH_USER_ASSIGNMENT_CALL_WITH_TYPE_REFERENCE;

    *result =
        copyContract;


    pxQoLLog(
        @"[PixivOAuthUser/Discovery/AssignmentCall] selected kind=WITH_TYPE_REFERENCE evidence=assignWithCopy"
    );


    return true;
}
