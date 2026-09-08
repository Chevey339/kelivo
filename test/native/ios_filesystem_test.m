#import "KelivoISHFilesystem.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syslimits.h>

static void check(BOOL ok, const char *message) {
    if (!ok) { fprintf(stderr, "%s\n", message); exit(1); }
}

int main(void) {
    @autoreleasepool {
        NSFileManager *fm = NSFileManager.defaultManager;
        NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        NSMutableArray *contexts = [NSMutableArray array];
        for (NSString *name in @[@"a", @"b"]) {
            NSMutableArray *binds = [NSMutableArray array];
            for (NSString *guest in @[@"/workspace", @"/chat", @"/skills", @"/tmp"]) {
                NSString *host = [[root stringByAppendingPathComponent:name] stringByAppendingPathComponent:[guest substringFromIndex:1]];
                check([fm createDirectoryAtPath:host withIntermediateDirectories:YES attributes:nil error:nil], "mkdir");
                [binds addObject:@{@"guest":guest, @"host":host}];
            }
            NSData *context = KelivoISHCreateFilesystem(binds);
            check(context != nil, "context creation");
            [contexts addObject:context];
        }
        for (int pass = 0; pass < 3; pass++) {
            for (int index = 0; index < 2; index++) {
                NSData *data = contexts[index];
                uint64_t inheritedContext = (uint64_t)(uintptr_t)data.bytes;
                for (NSString *guest in @[@"/workspace", @"/chat", @"/skills", @"/tmp"]) {
                    NSString *path = [guest stringByAppendingPathComponent:@"output.txt"];
                    char host[PATH_MAX], reverse[PATH_MAX];
                    check(KelivoISHTranslatePath(path.UTF8String, inheritedContext, host, sizeof(host)), "forward translation");
                    NSString *expected = [NSString stringWithFormat:@"/%@%@/output.txt", index == 0 ? @"a" : @"b", guest];
                    check([@(host) hasSuffix:expected], "other conversation changed mapping");
                    check(KelivoISHReversePath(host, inheritedContext, reverse, sizeof(reverse)), "reverse translation");
                    check(strcmp(reverse, path.UTF8String) == 0, "cwd round trip");
                    check(!KelivoISHTranslatePath("/workspace-other/file", inheritedContext, host, sizeof(host)), "prefix boundary");
                }
            }
        }
        char out[PATH_MAX];
        check(!KelivoISHTranslatePath("/workspace/file", 0, out, sizeof(out)), "unbound context");
        check(KelivoISHCreateFilesystem(@[@{@"guest":@"/workspace", @"host":@"/missing-kelivo-test-root"}]) == nil, "missing root accepted");
        check([fm removeItemAtPath:root error:nil], "cleanup");
        puts("Concurrent filesystem context checks passed");
    }
    return 0;
}
