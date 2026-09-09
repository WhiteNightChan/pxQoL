#import "LogHelper.h"

@implementation LogHelper

+ (NSString *)logFilePath {
    static NSString *path = nil;

    @synchronized(self) {
        if (!path) {
            NSString *version =
                [[NSBundle mainBundle]
                    objectForInfoDictionaryKey:
                        @"CFBundleShortVersionString"];

            if (![version isKindOfClass:[NSString class]] ||
                version.length == 0) {

                version = @"unknown";
            }

            NSDateFormatter *formatter =
                [[NSDateFormatter alloc] init];

            formatter.locale =
                [[NSLocale alloc]
                    initWithLocaleIdentifier:@"en_US_POSIX"];

            formatter.calendar =
                [[NSCalendar alloc]
                    initWithCalendarIdentifier:
                        NSCalendarIdentifierGregorian];

            formatter.timeZone =
                [NSTimeZone localTimeZone];

            formatter.dateFormat =
                @"yyyyMMdd-HHmmss";

            NSString *timestamp =
                [formatter stringFromDate:[NSDate date]];

            NSString *fileName =
                [NSString stringWithFormat:
                    @"pxQoL-patch-log_v%@_%@.txt",
                    version,
                    timestamp];

            path =
                [NSTemporaryDirectory()
                    stringByAppendingPathComponent:fileName];
        }
    }

    return path;
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