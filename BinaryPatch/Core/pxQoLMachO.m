#import "pxQoLMachO.h"

#import <mach-o/dyld.h>
#import <mach-o/getsect.h>

#include <string.h>

#import "../../LogHelper.h"

#define pxQoLLog(fmt, ...) \
    [LogHelper appendLine:[NSString stringWithFormat:(fmt), ##__VA_ARGS__]]


const struct mach_header_64 *pxQoLFindPixivImage(void)
{
    uint32_t imageCount =
        _dyld_image_count();

    pxQoLLog(
        @"imageCount = %u",
        imageCount
    );

    for (uint32_t i = 0;
         i < imageCount;
         i++) {

        const char *name =
            _dyld_get_image_name(i);

        if (name &&
            strstr(name, "/pixiv.app/pixiv")) {

            const struct mach_header_64 *header =
                (const struct mach_header_64 *)
                _dyld_get_image_header(i);

            pxQoLLog(
                @"pixiv found: index=%u",
                i
            );

            pxQoLLog(
                @"imageName=%s",
                name
            );

            return header;
        }
    }

    return NULL;
}


uint8_t *pxQoLGetTextSection(
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