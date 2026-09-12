#import "MachO.h"

#import <mach-o/dyld.h>
#import <mach-o/getsect.h>

#include <string.h>

#import "../../LogHelper.h"

#define pxQoLLog(fmt, ...) \
    [LogHelper appendLine:[NSString stringWithFormat:(fmt), ##__VA_ARGS__]]


const struct mach_header_64 *pxqMachOFindLoadedImage(
    const char *pathSubstring
)
{
    if (!pathSubstring ||
        pathSubstring[0] == '\0') {

        return NULL;
    }

    uint32_t imageCount =
        _dyld_image_count();

    pxQoLLog(
        @"[BinaryPatch/MachO] imageCount = %u",
        imageCount
    );

    for (uint32_t i = 0;
         i < imageCount;
         i++) {

        const char *name =
            _dyld_get_image_name(i);

        if (name &&
            strstr(name, pathSubstring)) {

            const struct mach_header_64 *header =
                (const struct mach_header_64 *)
                _dyld_get_image_header(i);

            pxQoLLog(
                @"[BinaryPatch/MachO] image found: index=%u",
                i
            );

            pxQoLLog(
                @"[BinaryPatch/MachO] imageName=%s",
                name
            );

            return header;
        }
    }

    return NULL;
}


uint8_t *pxqMachOGetTextSection(
    const struct mach_header_64 *header,
    unsigned long *textSize
)
{
    if (!header)
        return NULL;

    return (uint8_t *)getsectiondata(
        header,
        "__TEXT",
        "__text",
        textSize
    );
}
