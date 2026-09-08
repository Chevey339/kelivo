#import "KelivoISHFilesystem.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/syslimits.h>

// Only the four per-command roots live here. External grants continue to use
// fakefs's global bind table and its read-only checks.
typedef struct {
    char guest[16];
    char host[PATH_MAX];
} KelivoISHPathMapping;

NSData *KelivoISHCreateFilesystem(NSArray<NSDictionary<NSString *, id> *> *binds) {
    NSArray<NSString *> *roots = @[@"/workspace", @"/chat", @"/skills", @"/tmp"];
    KelivoISHPathMapping mappings[4] = {0};
    for (NSDictionary *bind in binds) {
        NSString *guest = bind[@"guest"];
        NSString *host = bind[@"host"];
        NSUInteger index = [roots indexOfObject:guest];
        if (index == NSNotFound || ![host isKindOfClass:NSString.class] ||
            ![host hasPrefix:@"/"] || [host rangeOfString:@"\0"].location != NSNotFound) return nil;
        if (realpath(host.fileSystemRepresentation, mappings[index].host) == NULL) return nil;
        strlcpy(mappings[index].guest, guest.UTF8String, sizeof(mappings[index].guest));
    }
    return [NSData dataWithBytes:mappings length:sizeof(mappings)];
}

static bool inside(const char *path, const char *root) {
    size_t n = strlen(root);
    return n > 0 && strncmp(path, root, n) == 0 && (path[n] == 0 || path[n] == '/');
}

static bool translate(const char *path, uint64_t context, char *out, size_t size, bool reverse) {
    if (!context || !size) return false;
    const KelivoISHPathMapping *mappings = (const void *)(uintptr_t)context;
    const KelivoISHPathMapping *best = NULL;
    size_t bestLength = 0;
    for (int i = 0; i < 4; i++) {
        const char *root = reverse ? mappings[i].host : mappings[i].guest;
        if (inside(path, root) && strlen(root) > bestLength) {
            best = &mappings[i];
            bestLength = strlen(root);
        }
    }
    if (!best) return false;
    const char *target = reverse ? best->guest : best->host;
    // An overlong translated path must fail, never fall back to a different FS.
    if ((size_t)snprintf(out, size, "%s%s", target, path + bestLength) >= size) out[0] = 0;
    return true;
}

bool KelivoISHTranslatePath(const char *guest, uint64_t context, char *out, size_t size) {
    return translate(guest, context, out, size, false);
}

bool KelivoISHReversePath(const char *host, uint64_t context, char *out, size_t size) {
    return translate(host, context, out, size, true);
}
