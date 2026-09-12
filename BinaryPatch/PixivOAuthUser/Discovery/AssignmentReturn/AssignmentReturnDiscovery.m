#import "AssignmentReturnDiscovery.h"
#import "../../../../LogHelper.h"

#include <string.h>


bool pxqDiscoverPixivOAuthUserAssignmentReturnInterceptions(
    uint8_t *text,
    unsigned long textSize,
    PXQPixivOAuthUserAssignmentReturnContract *result
)
{
    const uint32_t *insns =
        (const uint32_t *)text;

    const size_t count =
        textSize /
        sizeof(uint32_t);


    PXQPixivOAuthUserAssignmentReturnContract match =
        *result;

    /*
     * ---------------------------------------------------------
     * AssignmentReturn interception fingerprints
     * ---------------------------------------------------------
     *
     * Field order is intentionally NOT used to identify isPremium.
     * The PixivOAuthUser semantic layer resolves the field named exactly
     * "isPremium" from runtime metadata before writing.
     *
     * Confirmed register-allocation / frame-shape fingerprints:
     *
     * destination=x19, metadata=x21, standard-frame
     * (newer layouts such as 8.8.1):
     *
     *   x21 = metadata
     *   x20 = source
     *   x19 = destination
     *   ...
     *   mov x0,x19              <- patch target
     *
     * destination=x21, metadata=x19, standard-frame
     * (watchpoint + Ghidra confirmed on 8.4.10,
     * and VWT-derived on 8.4.6):
     *
     *   x19 = metadata
     *   x20 = source
     *   x21 = destination
     *   ...
     *   mov x0,x21              <- patch target
     *
     * destination=x21, metadata=x19, wide-frame
     * uses the same register contract and body marker but a wider
     * stack frame that additionally saves/restores x24/x23.
     *
     * A structurally strong candidate may still belong to another
     * Swift value type. Therefore Discovery does not attach semantic
     * PixivOAuthUser identity to the candidate. The runtime semantic
     * guard validates metadata on every trampoline entry.
     *
     * Keep a small bounded set of qualified sites instead of requiring
     * exactly one globally. Multiple structural fingerprints may coexist
     * in one binary while only one is observed at runtime.
     */

    typedef struct {
        const char *name;

        PXQAssignmentReturnCapture capture;

        const uint32_t *prologue;
        size_t prologueCount;

        const uint32_t *bodyMarker;
        size_t bodyMarkerCount;

        const uint32_t *epilogue;
        size_t epilogueCount;

    } PXQAssignmentReturnFingerprint;


    static const uint32_t assignmentReturnDestX19MetadataX21Prologue[] = {
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
    static const uint32_t assignmentReturnDestX19MetadataX21BodyMarker[] = {
        0x6944A6A8u,
        0x38686A8Au,
        0x38286A6Au,
        0x38696A88u,
        0x38296A68u,
        0x6945A6A8u
    };


    static const uint32_t assignmentReturnDestX19MetadataX21Epilogue[] = {
        0xAA1303E0u, /* mov x0,x19 */
        0xA9427BFDu,
        0xA9414FF4u,
        0xA8C357F6u,
        0xD65F03C0u
    };


    static const uint32_t assignmentReturnDestX21MetadataX19Prologue[] = {
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


    static const uint32_t assignmentReturnDestX21MetadataX19WideFramePrologue[] = {
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
    static const uint32_t assignmentReturnDestX21MetadataX19BodyMarker[] = {
        0x3940A288u,
        0x3900A2A8u,
        0x3DC00E80u,
        0x3D800EA0u
    };


    static const uint32_t assignmentReturnDestX21MetadataX19Epilogue[] = {
        0xAA1503E0u, /* mov x0,x21 */
        0xA9427BFDu,
        0xA9414FF4u,
        0xA8C357F6u,
        0xD65F03C0u
    };


    static const uint32_t assignmentReturnDestX21MetadataX19WideFrameEpilogue[] = {
        0xAA1503E0u, /* mov x0,x21 */
        0xA9437BFDu,
        0xA9424FF4u,
        0xA94157F6u,
        0xA8C45FF8u,
        0xD65F03C0u
    };


    static const PXQAssignmentReturnFingerprint assignmentReturnFingerprints[] = {
        {
            .name = "destination=x19 metadata=x21 standard-frame",
            .capture = {
                .destinationRegister = 19,
                .metadataRegister = 21
            },
            .prologue =
                assignmentReturnDestX19MetadataX21Prologue,
            .prologueCount =
                sizeof(assignmentReturnDestX19MetadataX21Prologue) /
                sizeof(assignmentReturnDestX19MetadataX21Prologue[0]),
            .bodyMarker =
                assignmentReturnDestX19MetadataX21BodyMarker,
            .bodyMarkerCount =
                sizeof(assignmentReturnDestX19MetadataX21BodyMarker) /
                sizeof(assignmentReturnDestX19MetadataX21BodyMarker[0]),
            .epilogue =
                assignmentReturnDestX19MetadataX21Epilogue,
            .epilogueCount =
                sizeof(assignmentReturnDestX19MetadataX21Epilogue) /
                sizeof(assignmentReturnDestX19MetadataX21Epilogue[0])
        },
        {
            .name = "destination=x21 metadata=x19 standard-frame",
            .capture = {
                .destinationRegister = 21,
                .metadataRegister = 19
            },
            .prologue =
                assignmentReturnDestX21MetadataX19Prologue,
            .prologueCount =
                sizeof(assignmentReturnDestX21MetadataX19Prologue) /
                sizeof(assignmentReturnDestX21MetadataX19Prologue[0]),
            .bodyMarker =
                assignmentReturnDestX21MetadataX19BodyMarker,
            .bodyMarkerCount =
                sizeof(assignmentReturnDestX21MetadataX19BodyMarker) /
                sizeof(assignmentReturnDestX21MetadataX19BodyMarker[0]),
            .epilogue =
                assignmentReturnDestX21MetadataX19Epilogue,
            .epilogueCount =
                sizeof(assignmentReturnDestX21MetadataX19Epilogue) /
                sizeof(assignmentReturnDestX21MetadataX19Epilogue[0])
        },
        {
            .name = "destination=x21 metadata=x19 wide-frame",
            .capture = {
                .destinationRegister = 21,
                .metadataRegister = 19
            },
            .prologue =
                assignmentReturnDestX21MetadataX19WideFramePrologue,
            .prologueCount =
                sizeof(assignmentReturnDestX21MetadataX19WideFramePrologue) /
                sizeof(assignmentReturnDestX21MetadataX19WideFramePrologue[0]),
            .bodyMarker =
                assignmentReturnDestX21MetadataX19BodyMarker,
            .bodyMarkerCount =
                sizeof(assignmentReturnDestX21MetadataX19BodyMarker) /
                sizeof(assignmentReturnDestX21MetadataX19BodyMarker[0]),
            .epilogue =
                assignmentReturnDestX21MetadataX19WideFrameEpilogue,
            .epilogueCount =
                sizeof(assignmentReturnDestX21MetadataX19WideFrameEpilogue) /
                sizeof(assignmentReturnDestX21MetadataX19WideFrameEpilogue[0])
        }
    };


    const size_t assignmentReturnFunctionScanCount =
        0x180 /
        sizeof(uint32_t);

    size_t totalAssignmentReturnPrologueHits =
        0;

    size_t totalQualifiedAssignmentReturnSites =
        0;


    for (size_t f = 0;
         f <
            sizeof(assignmentReturnFingerprints) /
            sizeof(assignmentReturnFingerprints[0]);
         f++) {

        const PXQAssignmentReturnFingerprint *fingerprint =
            &assignmentReturnFingerprints[f];

        size_t fingerprintPrologueHits =
            0;

        size_t fingerprintQualifiedSites =
            0;


        for (size_t i = 0;
             i + fingerprint->prologueCount <= count;
             i++) {

            if (memcmp(
                    &insns[i],
                    fingerprint->prologue,
                    fingerprint->prologueCount *
                        sizeof(uint32_t)) != 0) {

                continue;
            }


            fingerprintPrologueHits++;
            totalAssignmentReturnPrologueHits++;


            uintptr_t functionStart =
                (uintptr_t)&insns[i];


            pxQoLLog(
                @"[PixivOAuthUser/Discovery/AssignmentReturn] fingerprint=%s prologue hit #%zu: function=text+0x%llx",
                fingerprint->name,
                fingerprintPrologueHits,
                (unsigned long long)(
                    functionStart -
                    (uintptr_t)text
                )
            );


            size_t scanEnd =
                i +
                assignmentReturnFunctionScanCount;

            if (scanEnd > count)
                scanEnd = count;


            size_t localBodyMarkerCount =
                0;

            size_t localEpilogueCount =
                0;

            uintptr_t localPatchSite =
                0;


            for (size_t j =
                     i +
                     fingerprint->prologueCount;
                 j < scanEnd;
                 j++) {

                if (j +
                        fingerprint->bodyMarkerCount <=
                            scanEnd &&
                    memcmp(
                        &insns[j],
                        fingerprint->bodyMarker,
                        fingerprint->bodyMarkerCount *
                            sizeof(uint32_t)) == 0) {

                    localBodyMarkerCount++;

                    pxQoLLog(
                        @"[PixivOAuthUser/Discovery/AssignmentReturn] fingerprint=%s structural body marker: function=text+0x%llx marker=text+0x%llx",
                        fingerprint->name,
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
                        fingerprint->epilogueCount <=
                            scanEnd &&
                    memcmp(
                        &insns[j],
                        fingerprint->epilogue,
                        fingerprint->epilogueCount *
                            sizeof(uint32_t)) == 0) {

                    localEpilogueCount++;
                    localPatchSite =
                        (uintptr_t)&insns[j];

                    pxQoLLog(
                        @"[PixivOAuthUser/Discovery/AssignmentReturn] fingerprint=%s patch-site epilogue: function=text+0x%llx patchSite=text+0x%llx",
                        fingerprint->name,
                        (unsigned long long)(
                            functionStart -
                            (uintptr_t)text
                        ),
                        (unsigned long long)(
                            localPatchSite -
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
                @"[PixivOAuthUser/Discovery/AssignmentReturn] fingerprint=%s function summary: function=text+0x%llx bodyMarkers=%zu epilogues=%zu",
                fingerprint->name,
                (unsigned long long)(
                    functionStart -
                    (uintptr_t)text
                ),
                localBodyMarkerCount,
                localEpilogueCount
            );


            if (localBodyMarkerCount != 1 ||
                localEpilogueCount != 1 ||
                localPatchSite == 0) {

                continue;
            }


            bool duplicate =
                false;

            for (size_t k = 0;
                 k < match.siteCount;
                 k++) {

                if (match.sites[k].
                        patchSite ==
                    localPatchSite) {

                    duplicate =
                        true;

                    break;
                }
            }

            if (duplicate)
                continue;


            if (match.siteCount >=
                PXQ_PIXIV_OAUTH_USER_MAX_ASSIGNMENT_RETURN_SITES) {

                pxQoLLog(
                    @"[PixivOAuthUser/Discovery/AssignmentReturn] FAIL [1]: qualified sites exceed limit=%d",
                    PXQ_PIXIV_OAUTH_USER_MAX_ASSIGNMENT_RETURN_SITES
                );

                return false;
            }


            match.sites[
                match.siteCount
            ] =
                (PXQPixivOAuthUserAssignmentReturnSite) {
                    .patchSite =
                        localPatchSite,
                    .capture =
                        fingerprint->capture
                };

            match.siteCount++;

            fingerprintQualifiedSites++;
            totalQualifiedAssignmentReturnSites++;


            pxQoLLog(
                @"[PixivOAuthUser/Discovery/AssignmentReturn] fingerprint=%s qualified: patchSite=text+0x%llx",
                fingerprint->name,
                (unsigned long long)(
                    localPatchSite -
                    (uintptr_t)text
                )
            );
        }


        pxQoLLog(
            @"[PixivOAuthUser/Discovery/AssignmentReturn] fingerprint=%s summary: prologueHits=%zu qualifiedSites=%zu",
            fingerprint->name,
            fingerprintPrologueHits,
            fingerprintQualifiedSites
        );
    }


    pxQoLLog(
        @"[PixivOAuthUser/Discovery/AssignmentReturn] summary: prologueHits=%zu qualifiedSites=%zu",
        totalAssignmentReturnPrologueHits,
        match.siteCount
    );


    if (match.siteCount == 0) {
        pxQoLLog(
            @"[PixivOAuthUser/Discovery/AssignmentReturn] FAIL [2]: no qualified AssignmentReturn site"
        );

        return false;
    }


    if (totalQualifiedAssignmentReturnSites !=
        match.siteCount) {

        pxQoLLog(
            @"[PixivOAuthUser/Discovery/AssignmentReturn] FAIL [3]: internal AssignmentReturn-site accounting mismatch"
        );

        return false;
    }


    for (size_t i = 0;
         i < match.siteCount;
         i++) {

        pxQoLLog(
            @"[PixivOAuthUser/Discovery/AssignmentReturn] resolved[%zu]: destination=x%u metadata=x%u patchSite=text+0x%llx",
            i,
            (unsigned int)
                match.sites[i].capture.destinationRegister,
            (unsigned int)
                match.sites[i].capture.metadataRegister,
            (unsigned long long)(
                match.sites[i].patchSite -
                (uintptr_t)text
            )
        );
    }

    *result =
        match;


    return true;
}
