#import "KelivoISHMountTarget.h"
#include <stdio.h>
#include <stdlib.h>

static void check(BOOL condition, const char *message) {
    if (!condition) {
        fprintf(stderr, "%s\n", message);
        exit(1);
    }
}

int main(void) {
    @autoreleasepool {
        NSFileManager *fm = NSFileManager.defaultManager;
        NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        NSString *data = [root stringByAppendingPathComponent:@"data"];
        NSString *target = [data stringByAppendingPathComponent:@"mounts/Notes"];
        NSString *localFile = [target stringByAppendingPathComponent:@"local-output.txt"];
        check(KelivoISHValidateMountTarget(data, @"/mounts/Notes") == 0, "missing target rejected");
        check([fm createDirectoryAtPath:target withIntermediateDirectories:YES attributes:nil error:nil], "mkdir failed");
        check(KelivoISHValidateMountTarget(data, @"/mounts/Notes") == 0, "empty placeholder rejected");

        NSData *contents = [@"keep my local work" dataUsingEncoding:NSUTF8StringEncoding];
        check([contents writeToFile:localFile atomically:YES], "write failed");
        check(KelivoISHValidateMountTarget(data, @"/mounts/Notes") == KelivoISHMountTargetOccupied, "nonempty guest directory accepted");
        check([[NSData dataWithContentsOfFile:localFile] isEqual:contents], "guest file lost or changed");

        check([fm removeItemAtPath:localFile error:nil], "remove fixture failed");
        NSString *hidden = [target stringByAppendingPathComponent:@".hidden"];
        check([contents writeToFile:hidden atomically:YES], "hidden fixture failed");
        check(KelivoISHValidateMountTarget(data, @"/mounts/Notes") == KelivoISHMountTargetOccupied, "hidden file ignored");
        check([fm removeItemAtPath:hidden error:nil], "remove hidden fixture failed");
        check([fm createDirectoryAtPath:[target stringByAppendingPathComponent:@"subdir"] withIntermediateDirectories:NO attributes:nil error:nil], "nested fixture failed");
        check(KelivoISHValidateMountTarget(data, @"/mounts/Notes") == KelivoISHMountTargetOccupied, "nested directory ignored");

        check([fm removeItemAtPath:target error:nil], "remove directory fixture failed");
        check([contents writeToFile:target atomically:YES], "plain file fixture failed");
        check(KelivoISHValidateMountTarget(data, @"/mounts/Notes") == KelivoISHMountTargetOccupied, "plain guest file accepted");
        check([[NSData dataWithContentsOfFile:target] isEqual:contents], "plain guest file changed");

        check([fm removeItemAtPath:target error:nil], "remove plain file fixture failed");
        NSString *source = [root stringByAppendingPathComponent:@"source"];
        check([fm createDirectoryAtPath:source withIntermediateDirectories:NO attributes:nil error:nil], "source mkdir failed");
        NSString *sourceFile = [source stringByAppendingPathComponent:@"note.txt"];
        check([contents writeToFile:sourceFile atomically:YES], "source write failed");
        check([fm createSymbolicLinkAtPath:target withDestinationPath:source error:nil], "bind symlink fixture failed");
        check(KelivoISHValidateMountTarget(data, @"/mounts/Notes") == 0, "existing bind followed into nonempty source");
        check([[NSData dataWithContentsOfFile:sourceFile] isEqual:contents], "mounted source changed");
        check([fm removeItemAtPath:source error:nil], "remove source fixture failed");
        check(KelivoISHValidateMountTarget(data, @"/mounts/Notes") == 0, "stale bind symlink rejected");
        check([fm destinationOfSymbolicLinkAtPath:target error:nil] != nil, "bind symlink removed by validation");

        NSString *blocked = [data stringByAppendingPathComponent:@"mounts/file"];
        check([contents writeToFile:blocked atomically:YES], "invalid parent fixture failed");
        check(KelivoISHValidateMountTarget(data, @"/mounts/file/child") < 0, "inspection failure accepted");
        check([fm removeItemAtPath:root error:nil], "cleanup failed");
        puts("iOS mount target preservation checks passed");
    }
    return 0;
}
