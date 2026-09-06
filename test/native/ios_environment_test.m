#import "KelivoISHEnvironment.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void check(BOOL condition, const char *message) {
    if (!condition) {
        fprintf(stderr, "%s\n", message);
        exit(1);
    }
}

static NSDictionary *decode(NSData *data) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    const char *entry = data.bytes;
    while (*entry) {
        NSString *text = [NSString stringWithUTF8String:entry];
        NSRange separator = [text rangeOfString:@"="];
        check(separator.location != NSNotFound, "missing key/value separator");
        result[[text substringToIndex:separator.location]] = [text substringFromIndex:separator.location + 1];
        entry += strlen(entry) + 1;
    }
    check((NSUInteger)(entry - (const char *)data.bytes) == data.length - 1, "bad final terminator");
    return result;
}

int main(void) {
    @autoreleasepool {
        KelivoISHEnvironmentError error;
        NSMutableDictionary *env = [@{
            @"PATH": @"/workspace/.venv/bin:/usr/bin:/bin",
            @"TOKEN": [@"x" stringByPaddingToLength:16000 withString:@"x" startingAtIndex:0],
            @"UNICODE": @"密钥=\"value\"\nwith newline 🐱",
            @"EMPTY": @"",
        } mutableCopy];
        for (int i = 0; i < 100; i++) {
            env[[NSString stringWithFormat:@"VARIABLE_%d", i]] = @"another=value";
        }
        NSData *data = KelivoISHEncodeEnvironment(env, &error);
        check(data.length > 8192 && error == KelivoISHEnvironmentErrorNone, "large valid environment rejected");
        check([decode(data) isEqualToDictionary:env], "environment was changed or truncated");
        data = KelivoISHEncodeEnvironment(@{}, &error);
        check(data.length == 1 && ((const char *)data.bytes)[0] == '\0', "empty environment encoding failed");

        // K=, value, entry NUL, final NUL: exactly 128 KiB is representable.
        NSString *atLimit = [@"x" stringByPaddingToLength:KelivoISHEnvironmentMaxBytes - 4 withString:@"x" startingAtIndex:0];
        data = KelivoISHEncodeEnvironment(@{@"K": atLimit}, &error);
        check(data.length == KelivoISHEnvironmentMaxBytes, "exact limit rejected");
        check([decode(data)[@"K"] isEqualToString:atLimit], "boundary value corrupted");
        data = KelivoISHEncodeEnvironment(@{@"K": [atLimit stringByAppendingString:@"x"]}, &error);
        check(data == nil && error == KelivoISHEnvironmentErrorTooLarge, "oversized value accepted");
        data = KelivoISHEncodeEnvironment(@{@"K": atLimit, @"A": @""}, &error);
        check(data == nil && error == KelivoISHEnvironmentErrorTooLarge, "oversized aggregate accepted");
        NSString *unicode = [@"中" stringByPaddingToLength:50000 withString:@"中" startingAtIndex:0];
        data = KelivoISHEncodeEnvironment(@{@"K": unicode}, &error);
        check(data == nil && error == KelivoISHEnvironmentErrorTooLarge, "limit counted characters instead of UTF-8 bytes");

        unichar invalid[] = {'a', 0, 'b'};
        NSString *nul = [NSString stringWithCharacters:invalid length:3];
        for (NSDictionary *bad in @[@{@"K": nul}, @{nul: @"v"}, @{@"": @"v"}, @{@"A=B": @"v"}]) {
            data = KelivoISHEncodeEnvironment(bad, &error);
            check(data == nil && error == KelivoISHEnvironmentErrorInvalidEntry, "invalid entry accepted");
        }
        check([KelivoISHEnvironmentErrorMessage(KelivoISHEnvironmentErrorTooLarge) containsString:@"128 KiB"], "size error is not actionable");
        puts("iOS environment encoding checks passed");
    }
    return 0;
}
