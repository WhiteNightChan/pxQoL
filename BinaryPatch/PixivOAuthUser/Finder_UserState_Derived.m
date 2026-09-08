#import "Finder_UserState_Derived.h"
#import "../../LogHelper.h"

#include <string.h>


bool pxQoLFindPixivOAuthUserDerivedUserState(
    uint8_t *text,
    unsigned long textSize,
    pxQoLPixivOAuthUserDerivedUserStateMatch *result
)
{
    const uint32_t *insns =
        (const uint32_t *)text;

    const size_t count =
        textSize /
        sizeof(uint32_t);


    pxQoLPixivOAuthUserDerivedUserStateMatch match =
        *result;

    /*
     * ---------------------------------------------------------
     * DerivedUserState
     * DerivedUserState PixivOAuthUser assignment finalization
     * ---------------------------------------------------------
     *
     * Field order is intentionally NOT used to identify isPremium.
     * Patch.m resolves the field named exactly "isPremium" from
     * PixivOAuthUser's runtime descriptor before writing.
     *
     * Confirmed register-allocation variants:
     *
     * Variant A (newer layouts such as 8.8.1):
     *
     *   x21 = metadata
     *   x20 = source
     *   x19 = destination
     *   ...
     *   mov x0,x19              <- patch target
     *
     * Variant B (watchpoint + Ghidra confirmed on 8.4.10,
     * and VWT-derived on 8.4.6):
     *
     *   x19 = metadata
     *   x20 = source
     *   x21 = destination
     *   ...
     *   mov x0,x21              <- patch target
     *
     * 8.4.6 uses the same register contract and body marker but a
     * wider stack frame that additionally saves/restores x24/x23.
     *
     * A structurally strong candidate may still belong to another
     * Swift value type. Therefore Finder does not attach semantic
     * PixivOAuthUser identity to the candidate. Patch.m validates
     * the runtime metadata descriptor on every trampoline entry.
     *
     * Keep a small bounded set of qualified finalizers instead of
     * requiring exactly one globally. 8.4.10 contains both a
     * Variant-A-shaped assignment function and the actually observed
     * Variant-B writer.
     */

    typedef struct {
        const char *name;

        pxQoLPixivOAuthUserDerivedUserStateVariant variant;

        const uint32_t *prologue;
        size_t prologueCount;

        const uint32_t *bodyMarker;
        size_t bodyMarkerCount;

        const uint32_t *epilogue;
        size_t epilogueCount;

    } pxqDerivedUserStateVariantSpec;


    static const uint32_t derivedUserStateVariantAPrologue[] = {
        0xA9BD57F6u,
        0xA9014FF4u,
        0xA9027BFDu,
        0x910083FDu,
        0xAA0203F5u, /* mov x21,x2 */
        0xAA0103F4u, /* mov x20,x1 */
        0xAA0003F3u, /* mov x19,x0 */
        0x3DC00020u,
        0x3D800000u
    };


    /*
     * Structural fingerprint only.
     * No field in this sequence is interpreted as isPremium.
     */
    static const uint32_t derivedUserStateVariantABodyMarker[] = {
        0x6944A6A8u,
        0x38686A8Au,
        0x38286A6Au,
        0x38696A88u,
        0x38296A68u,
        0x6945A6A8u
    };


    static const uint32_t derivedUserStateVariantAEpilogue[] = {
        0xAA1303E0u, /* mov x0,x19 */
        0xA9427BFDu,
        0xA9414FF4u,
        0xA8C357F6u,
        0xD65F03C0u
    };


    static const uint32_t derivedUserStateVariantBPrologue[] = {
        0xA9BD57F6u,
        0xA9014FF4u,
        0xA9027BFDu,
        0x910083FDu,
        0xAA0203F3u, /* mov x19,x2 */
        0xAA0103F4u, /* mov x20,x1 */
        0xAA0003F5u, /* mov x21,x0 */
        0x3DC00020u,
        0x3D800000u
    };


    static const uint32_t derivedUserStateVariantBWidePrologue[] = {
        0xA9BC5FF8u,
        0xA90157F6u,
        0xA9024FF4u,
        0xA9037BFDu,
        0x9100C3FDu,
        0xAA0203F3u, /* mov x19,x2 */
        0xAA0103F4u, /* mov x20,x1 */
        0xAA0003F5u, /* mov x21,x0 */
        0x3DC00020u,
        0x3D800000u
    };


    /*
     * 8.4.10 structural fingerprint:
     *
     * ldrb w8,[x20,#0x28]
     * strb w8,[x21,#0x28]
     * ldr  q0,[x20,#0x30]
     * str  q0,[x21,#0x30]
     *
     * This is used only to identify the assignment shape.
     * Runtime field identity still comes exclusively from the
     * descriptor-based "isPremium" resolver.
     */
    static const uint32_t derivedUserStateVariantBBodyMarker[] = {
        0x3940A288u,
        0x3900A2A8u,
        0x3DC00E80u,
        0x3D800EA0u
    };


    static const uint32_t derivedUserStateVariantBEpilogue[] = {
        0xAA1503E0u, /* mov x0,x21 */
        0xA9427BFDu,
        0xA9414FF4u,
        0xA8C357F6u,
        0xD65F03C0u
    };


    static const uint32_t derivedUserStateVariantBWideEpilogue[] = {
        0xAA1503E0u, /* mov x0,x21 */
        0xA9437BFDu,
        0xA9424FF4u,
        0xA94157F6u,
        0xA8C45FF8u,
        0xD65F03C0u
    };


    static const pxqDerivedUserStateVariantSpec derivedUserStateVariants[] = {
        {
            .name = "A",
            .variant =
                PXQ_PIXIV_OAUTH_USER_DERIVED_USER_STATE_VARIANT_DEST_X19_METADATA_X21,
            .prologue =
                derivedUserStateVariantAPrologue,
            .prologueCount =
                sizeof(derivedUserStateVariantAPrologue) /
                sizeof(derivedUserStateVariantAPrologue[0]),
            .bodyMarker =
                derivedUserStateVariantABodyMarker,
            .bodyMarkerCount =
                sizeof(derivedUserStateVariantABodyMarker) /
                sizeof(derivedUserStateVariantABodyMarker[0]),
            .epilogue =
                derivedUserStateVariantAEpilogue,
            .epilogueCount =
                sizeof(derivedUserStateVariantAEpilogue) /
                sizeof(derivedUserStateVariantAEpilogue[0])
        },
        {
            .name = "B",
            .variant =
                PXQ_PIXIV_OAUTH_USER_DERIVED_USER_STATE_VARIANT_DEST_X21_METADATA_X19,
            .prologue =
                derivedUserStateVariantBPrologue,
            .prologueCount =
                sizeof(derivedUserStateVariantBPrologue) /
                sizeof(derivedUserStateVariantBPrologue[0]),
            .bodyMarker =
                derivedUserStateVariantBBodyMarker,
            .bodyMarkerCount =
                sizeof(derivedUserStateVariantBBodyMarker) /
                sizeof(derivedUserStateVariantBBodyMarker[0]),
            .epilogue =
                derivedUserStateVariantBEpilogue,
            .epilogueCount =
                sizeof(derivedUserStateVariantBEpilogue) /
                sizeof(derivedUserStateVariantBEpilogue[0])
        },
        {
            .name = "B-WIDE",
            .variant =
                PXQ_PIXIV_OAUTH_USER_DERIVED_USER_STATE_VARIANT_DEST_X21_METADATA_X19,
            .prologue =
                derivedUserStateVariantBWidePrologue,
            .prologueCount =
                sizeof(derivedUserStateVariantBWidePrologue) /
                sizeof(derivedUserStateVariantBWidePrologue[0]),
            .bodyMarker =
                derivedUserStateVariantBBodyMarker,
            .bodyMarkerCount =
                sizeof(derivedUserStateVariantBBodyMarker) /
                sizeof(derivedUserStateVariantBBodyMarker[0]),
            .epilogue =
                derivedUserStateVariantBWideEpilogue,
            .epilogueCount =
                sizeof(derivedUserStateVariantBWideEpilogue) /
                sizeof(derivedUserStateVariantBWideEpilogue[0])
        }
    };


    const size_t derivedUserStateFunctionScanCount =
        0x180 /
        sizeof(uint32_t);

    size_t totalDerivedUserStatePrologueHits =
        0;

    size_t totalQualifiedDerivedUserStateAssignments =
        0;


    for (size_t v = 0;
         v <
            sizeof(derivedUserStateVariants) /
            sizeof(derivedUserStateVariants[0]);
         v++) {

        const pxqDerivedUserStateVariantSpec *spec =
            &derivedUserStateVariants[v];

        size_t variantPrologueHits =
            0;

        size_t variantQualifiedAssignments =
            0;


        for (size_t i = 0;
             i + spec->prologueCount <= count;
             i++) {

            if (memcmp(
                    &insns[i],
                    spec->prologue,
                    spec->prologueCount *
                        sizeof(uint32_t)) != 0) {

                continue;
            }


            variantPrologueHits++;
            totalDerivedUserStatePrologueHits++;


            uintptr_t functionStart =
                (uintptr_t)&insns[i];


            pxQoLLog(
                @"[PixivOAuthUser/Finder] DerivedUserState Variant %s prologue hit #%zu: function=text+0x%llx",
                spec->name,
                variantPrologueHits,
                (unsigned long long)(
                    functionStart -
                    (uintptr_t)text
                )
            );


            size_t scanEnd =
                i +
                derivedUserStateFunctionScanCount;

            if (scanEnd > count)
                scanEnd = count;


            size_t localBodyMarkerCount =
                0;

            size_t localEpilogueCount =
                0;

            uintptr_t localFinalizeCallsite =
                0;


            for (size_t j =
                     i +
                     spec->prologueCount;
                 j < scanEnd;
                 j++) {

                if (j +
                        spec->bodyMarkerCount <=
                            scanEnd &&
                    memcmp(
                        &insns[j],
                        spec->bodyMarker,
                        spec->bodyMarkerCount *
                            sizeof(uint32_t)) == 0) {

                    localBodyMarkerCount++;

                    pxQoLLog(
                        @"[PixivOAuthUser/Finder] DerivedUserState Variant %s structural body marker: function=text+0x%llx marker=text+0x%llx",
                        spec->name,
                        (unsigned long long)(
                            functionStart -
                            (uintptr_t)text
                        ),
                        (unsigned long long)(
                            (uintptr_t)&insns[j] -
                            (uintptr_t)text
                        )
                    );
                }


                if (j +
                        spec->epilogueCount <=
                            scanEnd &&
                    memcmp(
                        &insns[j],
                        spec->epilogue,
                        spec->epilogueCount *
                            sizeof(uint32_t)) == 0) {

                    localEpilogueCount++;
                    localFinalizeCallsite =
                        (uintptr_t)&insns[j];

                    pxQoLLog(
                        @"[PixivOAuthUser/Finder] DerivedUserState Variant %s finalize epilogue: function=text+0x%llx finalize=text+0x%llx",
                        spec->name,
                        (unsigned long long)(
                            functionStart -
                            (uintptr_t)text
                        ),
                        (unsigned long long)(
                            localFinalizeCallsite -
                            (uintptr_t)text
                        )
                    );
                }


                if (insns[j] ==
                    0xD65F03C0u) {

                    break;
                }
            }


            pxQoLLog(
                @"[PixivOAuthUser/Finder] DerivedUserState Variant %s function summary: function=text+0x%llx bodyMarkers=%zu epilogues=%zu",
                spec->name,
                (unsigned long long)(
                    functionStart -
                    (uintptr_t)text
                ),
                localBodyMarkerCount,
                localEpilogueCount
            );


            if (localBodyMarkerCount != 1 ||
                localEpilogueCount != 1 ||
                localFinalizeCallsite == 0) {

                continue;
            }


            bool duplicate =
                false;

            for (size_t k = 0;
                 k < match.finalizeCount;
                 k++) {

                if (match.finalizers[k].
                        finalizeCallsite ==
                    localFinalizeCallsite) {

                    duplicate =
                        true;

                    break;
                }
            }

            if (duplicate)
                continue;


            if (match.finalizeCount >=
                PXQ_PIXIV_OAUTH_USER_MAX_DERIVED_USER_STATE_FINALIZERS) {

                pxQoLLog(
                    @"[PixivOAuthUser/Finder] FAIL DerivedUserState [1]: qualified DerivedUserState finalizers exceed limit=%d",
                    PXQ_PIXIV_OAUTH_USER_MAX_DERIVED_USER_STATE_FINALIZERS
                );

                return false;
            }


            match.finalizers[
                match.finalizeCount
            ] =
                (pxQoLPixivOAuthUserDerivedUserStateFinalize) {
                    .finalizeCallsite =
                        localFinalizeCallsite,
                    .variant =
                        spec->variant
                };

            match.finalizeCount++;

            variantQualifiedAssignments++;
            totalQualifiedDerivedUserStateAssignments++;


            pxQoLLog(
                @"[PixivOAuthUser/Finder] DerivedUserState Variant %s qualified: finalize=text+0x%llx",
                spec->name,
                (unsigned long long)(
                    localFinalizeCallsite -
                    (uintptr_t)text
                )
            );
        }


        pxQoLLog(
            @"[PixivOAuthUser/Finder] DerivedUserState Variant %s summary: prologueHits=%zu qualifiedAssignments=%zu",
            spec->name,
            variantPrologueHits,
            variantQualifiedAssignments
        );
    }


    pxQoLLog(
        @"[PixivOAuthUser/Finder] DerivedUserState summary: prologueHits=%zu qualifiedFinalizers=%zu",
        totalDerivedUserStatePrologueHits,
        match.finalizeCount
    );


    if (match.finalizeCount == 0) {
        pxQoLLog(
            @"[PixivOAuthUser/Finder] FAIL DerivedUserState [2]: no qualified DerivedUserState assignment finalizer"
        );

        return false;
    }


    if (totalQualifiedDerivedUserStateAssignments !=
        match.finalizeCount) {

        pxQoLLog(
            @"[PixivOAuthUser/Finder] FAIL DerivedUserState [3]: internal DerivedUserState-finalizer accounting mismatch"
        );

        return false;
    }


    for (size_t i = 0;
         i < match.finalizeCount;
         i++) {

        pxQoLLog(
            @"[PixivOAuthUser/Finder] DerivedUserState resolved[%zu]: variant=%u finalize=text+0x%llx",
            i,
            (unsigned int)
                match.finalizers[i].variant,
            (unsigned long long)(
                match.finalizers[i].
                    finalizeCallsite -
                (uintptr_t)text
            )
        );
    }

    *result =
        match;


    return true;
}
