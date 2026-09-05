#import <mach-o/loader.h>
#include <stdint.h>

const struct mach_header_64 *pxQoLFindPixivImage(void);

uint8_t *pxQoLGetTextSection(
    const struct mach_header_64 *header,
    unsigned long *textSize
);