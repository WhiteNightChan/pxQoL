#import "Discovery.h"
#import "AssignmentCall/AssignmentCallDiscovery.h"
#import "AssignmentReturn/AssignmentReturnDiscovery.h"
#import "../../../LogHelper.h"

#include <string.h>


static const char *pxqAssignmentCallKindName(
    PXQPixivOAuthUserAssignmentCallKind kind
)
{
    switch (kind) {

        case PXQ_PIXIV_OAUTH_USER_ASSIGNMENT_CALL_TWO_ARGUMENT:
            return "TWO_ARGUMENT";

        case PXQ_PIXIV_OAUTH_USER_ASSIGNMENT_CALL_WITH_TYPE_REFERENCE:
            return "WITH_TYPE_REFERENCE";

        default:
            return "NONE";
    }
}


bool pxqDiscoverPixivOAuthUserInterceptionContract(
    uint8_t *text,
    unsigned long textSize,
    PXQPixivOAuthUserInterceptionContract *result
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


    PXQPixivOAuthUserInterceptionContract contract;

    memset(
        &contract,
        0,
        sizeof(contract)
    );


    const size_t count =
        textSize /
        sizeof(uint32_t);


    pxQoLLog(
        @"[PixivOAuthUser/Discovery] text=%p textSize=0x%lx instructionCount=%zu",
        text,
        textSize,
        count
    );


    if (!pxqDiscoverPixivOAuthUserAssignmentCallInterception(
            text,
            textSize,
            &contract.assignmentCall)) {

        return false;
    }


    if (!pxqDiscoverPixivOAuthUserAssignmentReturnInterceptions(
            text,
            textSize,
            &contract.assignmentReturn)) {

        return false;
    }


    *result =
        contract;


    pxQoLLog(
        @"[PixivOAuthUser/Discovery] SUCCESS assignmentCallKind=%s assignmentCallSites=%zu wrapper=text+0x%llx metadata=text+0x%llx assignmentReturnSites=%zu",
        pxqAssignmentCallKindName(
            contract.assignmentCall.kind
        ),
        contract.assignmentCall.callSiteCount,
        (unsigned long long)(
            contract.assignmentCall.originalAssignmentWrapper -
            (uintptr_t)text
        ),
        (unsigned long long)(
            contract.assignmentCall.pixivOAuthUserMetadataAccessor -
            (uintptr_t)text
        ),
        contract.assignmentReturn.siteCount
    );


    return true;
}
