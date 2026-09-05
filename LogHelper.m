#import "LogHelper.h"

@implementation LogHelper

+ (NSString *)logFilePath {
    return [NSTemporaryDirectory()
        stringByAppendingPathComponent:@"pxQoL-patch-log.txt"];
}

+ (void)appendLine:(NSString *)line {
    @try {
        NSString *path = [self logFilePath];

        NSString *text =
            [[line ?: @"(nil)" stringByAppendingString:@"\n"] copy];

        NSData *data =
            [text dataUsingEncoding:NSUTF8StringEncoding];

        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            [[NSFileManager defaultManager]
                createFileAtPath:path
                contents:data
                attributes:nil];
            return;
        }

        NSFileHandle *handle =
            [NSFileHandle fileHandleForWritingAtPath:path];

        if (!handle) {
            [[NSFileManager defaultManager]
                createFileAtPath:path
                contents:data
                attributes:nil];
            return;
        }

        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];

    } @catch (__unused NSException *exception) {
    }
}

+ (void)clearLogFile {
    NSString *path = [self logFilePath];

    if ([[NSFileManager defaultManager]
            fileExistsAtPath:path]) {

        [[NSFileManager defaultManager]
            removeItemAtPath:path
            error:nil];
    }
}

@end