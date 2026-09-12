#ifndef PXQ_BINARY_PATCH_MACH_O_H
#define PXQ_BINARY_PATCH_MACH_O_H

#import <mach-o/loader.h>

#include <stdint.h>

const struct mach_header_64 *pxqMachOFindLoadedImage(
    const char *pathSubstring
);

uint8_t *pxqMachOGetTextSection(
    const struct mach_header_64 *header,
    unsigned long *textSize
);

#endif
