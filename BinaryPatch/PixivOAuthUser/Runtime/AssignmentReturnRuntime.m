#import "RuntimeOverride.h"
#import "../Contract/InterceptionContract.h"
#import "../../../LogHelper.h"

#include <stdbool.h>
#include <stdint.h>


static bool
    gLoggedAssignmentReturnSuccess = false;


__attribute__((noinline, used))
void *pxqAssignmentReturnOverrideHelper(
    void *destination,
    void *metadata
)
{
    bool overridden =
        pxqApplyPixivOAuthUserPremiumOverride(
            destination,
            metadata
        );

    if (!overridden) {
        pxQoLLog(
            @"[PixivOAuthUser/Runtime] AssignmentReturn resolver rejected metadata=%p destination=%p",
            metadata,
            destination
        );
    }
    else if (!gLoggedAssignmentReturnSuccess) {
        pxQoLLog(
            @"[PixivOAuthUser/Runtime] AssignmentReturn applied destination=%p metadata=%p",
            destination,
            metadata
        );

        gLoggedAssignmentReturnSuccess =
            true;
    }


    /*
     * Preserve the semantic effect of the MOV x0,destination that the
     * patched instruction replaced.
     */
    return destination;
}


#if defined(__aarch64__)

__attribute__((naked, noinline, used))
static void *pxqAssignmentReturnCaptureX19X21Trampoline(void)
{
    __asm__(
        "mov x0, x19\n"
        "mov x1, x21\n"
        "b _pxqAssignmentReturnOverrideHelper\n"
    );
}


__attribute__((naked, noinline, used))
static void *pxqAssignmentReturnCaptureX21X19Trampoline(void)
{
    __asm__(
        "mov x0, x21\n"
        "mov x1, x19\n"
        "b _pxqAssignmentReturnOverrideHelper\n"
    );
}

#else

/*
 * pxQoL targets arm64 iOS. These stubs keep non-arm64 source checks
 * from inventing a different register-capture ABI.
 */
__attribute__((noinline, used))
static void *pxqAssignmentReturnCaptureX19X21Trampoline(void)
{
    return NULL;
}


__attribute__((noinline, used))
static void *pxqAssignmentReturnCaptureX21X19Trampoline(void)
{
    return NULL;
}

#endif


bool pxqResolveAssignmentReturnRuntimeEntry(
    const PXQAssignmentReturnCapture *capture,
    uintptr_t *runtimeEntryAddress
)
{
    if (!capture ||
        !runtimeEntryAddress) {

        return false;
    }


    uintptr_t resolvedEntryAddress =
        0;


    if (capture->destinationRegister == 19 &&
        capture->metadataRegister == 21) {

        resolvedEntryAddress =
            (uintptr_t)
            &pxqAssignmentReturnCaptureX19X21Trampoline;
    }
    else if (capture->destinationRegister == 21 &&
             capture->metadataRegister == 19) {

        resolvedEntryAddress =
            (uintptr_t)
            &pxqAssignmentReturnCaptureX21X19Trampoline;
    }
    else {
        return false;
    }


    *runtimeEntryAddress =
        resolvedEntryAddress;

    return true;
}
