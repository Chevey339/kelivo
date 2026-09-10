//
//  KelivoISHKernel.m
//  Runner
//
//  Boot sequence adapted from Cuplivo/OpenMinis ISHKernel.m (GPL-3.0, see
//  ios/sandbox/NOTICE). Overlay files are written through the guest VFS so
//  meta.db stays in sync — never write host-side into the fakefs data/ tree.
//

#import "KelivoISHKernel.h"
#import "KelivoISHCrashGuards.h"
#import "KelivoISHExecutor.h"
#import "KelivoISHEnvironment.h"
#import "KelivoISHFilesystem.h"
#import "KelivoISHCompat.h"

@import SystemConfiguration;

#include "ish/kernel/init.h"
#include "ish/kernel/task.h"
#include "ish/kernel/calls.h"
#include "ish/kernel/fs.h"
#include "ish/fs/fake.h"
#include "ish/fs/tty.h"
#include "ish/fs/dev.h"
#include "ish/fs/devices.h"
#include "ish/fs/path.h"
#include "ish/fs/fd.h"
#include "ish/fs/stat.h"

#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syslimits.h>
#include <TargetConditionals.h>

#if !TARGET_OS_SIMULATOR
#include <sys/un.h>
#endif

NSNotificationName const KelivoISHProcessExitedNotification = @"KelivoISHProcessExited";

static NSString *const kDnsSubdir = @"KelivoWorkspace/dns";
static const char *kPublicDns[] = {"1.1.1.1", "8.8.8.8", "223.5.5.5"};

extern void (*exit_hook)(struct task *task, int code);

#if !TARGET_OS_SIMULATOR
extern const char *sock_tmp_prefix;
#endif

#pragma mark - Console TTY (init stdio; output discarded)

static int kelivo_console_write(struct tty *tty, const void *buf, size_t len, bool blocking) {
    (void)tty;
    (void)buf;
    (void)blocking;
    return (int)len;
}

static int kelivo_console_init(struct tty *tty) {
    (void)tty;
    return 0;
}

static void kelivo_console_cleanup(struct tty *tty) {
    (void)tty;
}

static struct tty_driver_ops kelivo_console_ops = {
    .init = kelivo_console_init,
    .write = kelivo_console_write,
    .cleanup = kelivo_console_cleanup,
};

DEFINE_TTY_DRIVER(kelivo_console_driver, &kelivo_console_ops, TTY_CONSOLE_MAJOR, 8);

#pragma mark - PTY driver

static int kelivo_pty_write(struct tty *tty, const void *buf, size_t len, bool blocking);
static int kelivo_pty_init(struct tty *tty) {
    (void)tty;
    return 0;
}
static void kelivo_pty_cleanup(struct tty *tty) {
    (void)tty;
}

static struct tty_driver_ops kelivo_pty_ops = {
    .init = kelivo_pty_init,
    .write = kelivo_pty_write,
    .cleanup = kelivo_pty_cleanup,
};

static struct tty_driver kelivo_pty_driver = {.ops = &kelivo_pty_ops};

static bool kelivo_reverse_context_path(const char *host, char *out, size_t size) {
    uint64_t context = current && current->group ? current->group->fs_context : 0;
    return KelivoISHReversePath(host, context, out, size);
}

#pragma mark - Session / bind state

@interface KelivoISHPtySession : NSObject
@property (nonatomic, copy) NSString *sessionId;
@property (nonatomic) int pid;
@property (nonatomic) pid_t_ pgid;
@property (nonatomic) struct tty *tty;
@end

@implementation KelivoISHPtySession
@end

@interface KelivoISHKernel ()
- (void)noteGuestExitWithPid:(int)pid code:(int)code;
- (void)deliverPtyData:(NSData *)data ttyNum:(int)ttyNum;
@end

/// iSH `do_exit` passes the Linux wait(2) status (exit << 8, or signal in the
/// low 7 bits). Flutter / the workspace channel expect a process exit code.
static int kelivo_decode_wait_status(int status) {
    if (status < 0) return status;
    if ((status & 0x7f) == 0) {
        return (status >> 8) & 0xff;
    }
    return 128 + (status & 0x7f);
}

static void kelivo_handle_process_exit(struct task *task, int code) {
    if (task->parent != NULL && task->parent->parent != NULL)
        return;
    pid_t pid = task->pid;
    int decoded = kelivo_decode_wait_status(code);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:KelivoISHProcessExitedNotification
                          object:nil
                        userInfo:@{@"pid": @(pid), @"code": @(decoded)}];
        [[KelivoISHKernel shared] noteGuestExitWithPid:pid code:decoded];
    });
}

static int kelivo_pty_write(struct tty *tty, const void *buf, size_t len, bool blocking) {
    (void)blocking;
    if (len == 0) return 0;
    NSData *data = [NSData dataWithBytes:buf length:len];
    int num = tty->num;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[KelivoISHKernel shared] deliverPtyData:data ttyNum:num];
    });
    return (int)len;
}

@implementation KelivoISHKernel {
    BOOL _isBooted;
    NSString *_rootPath;
    NSString *_dataPath;
    NSString *_dnsHostPath;
    SCNetworkReachabilityRef _dnsReachability;
    dispatch_queue_t _spawnQueue;
    NSMutableDictionary<NSString *, NSString *> *_activeBinds;
    NSMutableDictionary<NSString *, NSNumber *> *_readOnlyBinds;
    NSMutableDictionary<NSString *, KelivoISHPtySession *> *_ptyBySession;
    NSMutableDictionary<NSNumber *, KelivoISHPtySession *> *_ptyByPid;
    NSMutableDictionary<NSNumber *, KelivoISHPtySession *> *_ptyByTtyNum;
    NSLock *_ptyLock;
    NSMutableSet<NSData *> *_filesystems;
}

- (void)dealloc {
    if (_dnsReachability != NULL) {
        SCNetworkReachabilitySetDispatchQueue(_dnsReachability, NULL);
        CFRelease(_dnsReachability);
    }
}

+ (instancetype)shared {
    static KelivoISHKernel *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[KelivoISHKernel alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isBooted = NO;
        _filesystems = [NSMutableSet set];
        _spawnQueue = dispatch_queue_create("psyche.kelivo.workspace.ish.spawn", DISPATCH_QUEUE_SERIAL);
        _activeBinds = [NSMutableDictionary dictionary];
        _readOnlyBinds = [NSMutableDictionary dictionary];
        _ptyBySession = [NSMutableDictionary dictionary];
        _ptyByPid = [NSMutableDictionary dictionary];
        _ptyByTtyNum = [NSMutableDictionary dictionary];
        _ptyLock = [[NSLock alloc] init];
    }
    return self;
}

- (BOOL)isBooted {
    return _isBooted;
}

- (NSString *)bootRootPath {
    return _rootPath;
}

- (void)performOnSpawnQueue:(void (^)(void))block {
    dispatch_sync(_spawnQueue, block);
}

#pragma mark - Boot

- (int)bootWithRootPath:(NSString *)rootPath {
    if (_isBooted) {
        NSLog(@"KelivoISHKernel: already booted");
        return 0;
    }

    int err;
    KelivoISHInstallCrashGuards();
    KelivoISHInstallDieGuard();

    _rootPath = rootPath;
    _dataPath = [rootPath stringByAppendingPathComponent:@"data"];
    err = mount_root(&fakefs, _dataPath.fileSystemRepresentation);
    if (err < 0) {
        NSLog(@"KelivoISHKernel: mount_root failed: %d", err);
        _rootPath = nil;
        _dataPath = nil;
        return err;
    }

    char canonical_data_path[PATH_MAX];
    if (realpath(_dataPath.fileSystemRepresentation, canonical_data_path) != NULL) {
        fakefs_set_rootfs_data_path(canonical_data_path);
    } else {
        NSLog(@"KelivoISHKernel: realpath(data) failed (errno=%d)", errno);
    }

    err = become_first_process();
    if (err < 0) {
        NSLog(@"KelivoISHKernel: become_first_process failed: %d", err);
        return err;
    }
    current->thread = pthread_self();

    [self createDeviceNodes];
    [self applyRootfsPatchBundle];
    [self applyBundleOverlay];
    [self ensureGuestDirs:@[@"/workspace", @"/chat", @"/skills", @"/mounts"]];

    do_mount(&procfs, "proc", "/proc", "", 0);
    do_mount(&devptsfs, "devpts", "/dev/pts", "", 0);

    [self mountDnsConfig];
    [self setUpUnixSocketPrefix];

    fakefs_set_path_translate_hook(KelivoISHTranslatePath);
    fakefs_set_path_reverse_hook(kelivo_reverse_context_path);
    exit_hook = kelivo_handle_process_exit;

    tty_drivers[TTY_CONSOLE_MAJOR] = &kelivo_console_driver;
    set_console_device(TTY_CONSOLE_MAJOR, 1);
    err = create_stdio("/dev/console", TTY_CONSOLE_MAJOR, 1);
    if (err < 0) {
        NSLog(@"KelivoISHKernel: create_stdio failed: %d (non-fatal)", err);
    }

    _isBooted = YES;
    NSLog(@"KelivoISHKernel: kernel initialized");
    return 0;
}

- (void)createDeviceNodes {
    generic_mkdirat(AT_PWD, "/dev", 0755);
    generic_mkdirat(AT_PWD, "/dev/pts", 0755);

    generic_mknodat(AT_PWD, "/dev/tty1", S_IFCHR | 0666, dev_make(TTY_CONSOLE_MAJOR, 1));
    generic_mknodat(AT_PWD, "/dev/tty", S_IFCHR | 0666, dev_make(TTY_ALTERNATE_MAJOR, DEV_TTY_MINOR));
    generic_mknodat(AT_PWD, "/dev/console", S_IFCHR | 0666, dev_make(TTY_ALTERNATE_MAJOR, DEV_CONSOLE_MINOR));
    generic_mknodat(AT_PWD, "/dev/ptmx", S_IFCHR | 0666, dev_make(TTY_ALTERNATE_MAJOR, DEV_PTMX_MINOR));

    generic_mknodat(AT_PWD, "/dev/null", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_NULL_MINOR));
    generic_mknodat(AT_PWD, "/dev/zero", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_ZERO_MINOR));
    generic_mknodat(AT_PWD, "/dev/full", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_FULL_MINOR));
    generic_mknodat(AT_PWD, "/dev/random", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_RANDOM_MINOR));
    generic_mknodat(AT_PWD, "/dev/urandom", S_IFCHR | 0666, dev_make(MEM_MAJOR, DEV_URANDOM_MINOR));
}

- (void)ensureGuestDirs:(NSArray<NSString *> *)dirs {
    for (NSString *dir in dirs) {
        generic_mkdirat(AT_PWD, dir.fileSystemRepresentation, 0755);
    }
}

/// Apply iSH's Node compatibility scripts on every cold boot, including to
/// existing environments. Use the guest VFS so fakefs metadata stays in sync.
/// No installed-version marker: a failed write is retried on the next boot.
- (void)applyRootfsPatchBundle {
    NSURL *bundleURL = [[NSBundle mainBundle] URLForResource:@"RootfsPatch" withExtension:@"bundle"];
    NSDictionary *manifest = bundleURL == nil ? nil :
        [NSDictionary dictionaryWithContentsOfURL:[bundleURL URLByAppendingPathComponent:@"manifest.plist"]];
    if (manifest == nil) {
        NSLog(@"KelivoISHKernel: RootfsPatch manifest missing from bundle");
        return;
    }
    for (NSDictionary *entry in manifest[@"files"]) {
        [self writeGuestFile:entry[@"dst"]
                fromHostURL:[bundleURL URLByAppendingPathComponent:entry[@"src"]]];
    }
}

/// Write each file from the bundled `overlay/` folder through the guest VFS.
- (void)applyBundleOverlay {
    NSURL *overlayURL = [[NSBundle mainBundle] URLForResource:@"overlay" withExtension:nil];
    if (overlayURL == nil) {
        NSLog(@"KelivoISHKernel: overlay folder missing from bundle");
        return;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *en = [fm enumeratorAtURL:overlayURL
                         includingPropertiesForKeys:@[NSURLIsRegularFileKey]
                                            options:0
                                       errorHandler:nil];
    NSString *base = overlayURL.URLByStandardizingPath.path;
    for (NSURL *fileURL in en) {
        NSNumber *isFile = nil;
        [fileURL getResourceValue:&isFile forKey:NSURLIsRegularFileKey error:nil];
        if (!isFile.boolValue) continue;

        NSString *rel = [fileURL.URLByStandardizingPath.path substringFromIndex:base.length];
        if (![rel hasPrefix:@"/"]) rel = [@"/" stringByAppendingString:rel];
        [self writeGuestFile:rel fromHostURL:fileURL];
    }
}

- (void)ensureGuestParentDirs:(NSString *)guestPath {
    NSArray<NSString *> *parts = [guestPath componentsSeparatedByString:@"/"];
    NSMutableString *acc = [NSMutableString string];
    for (NSUInteger i = 0; i < parts.count - 1; i++) {
        NSString *part = parts[i];
        if (part.length == 0) continue;
        [acc appendFormat:@"/%@", part];
        generic_mkdirat(AT_PWD, acc.fileSystemRepresentation, 0755);
    }
}

- (void)writeGuestFile:(NSString *)guestPath fromHostURL:(NSURL *)hostURL {
    NSData *contents = [NSData dataWithContentsOfURL:hostURL];
    if (contents == nil) {
        NSLog(@"KelivoISHKernel: overlay read failed: %@", hostURL.path);
        return;
    }
    [self ensureGuestParentDirs:guestPath];

    BOOL isBin = [guestPath containsString:@"/bin/"] || [guestPath containsString:@"/sbin/"];
    int mode = isBin ? 0755 : 0644;
    struct fd *fd = generic_open(guestPath.fileSystemRepresentation,
                                 O_WRONLY_ | O_CREAT_ | O_TRUNC_, mode);
    if (IS_ERR(fd)) {
        NSLog(@"KelivoISHKernel: overlay open %@ failed: %ld", guestPath, PTR_ERR(fd));
        return;
    }
    const char *bytes = contents.bytes;
    size_t offset = 0;
    while (offset < contents.length) {
        ssize_t written = fd->ops->write(fd, bytes + offset, contents.length - offset);
        if (written <= 0) {
            NSLog(@"KelivoISHKernel: overlay write %@ failed: %zd", guestPath, written);
            break;
        }
        offset += (size_t)written;
    }
    fd_close(fd);
}

#pragma mark - DNS

- (void)mountDnsConfig {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *library = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dnsDir = [library stringByAppendingPathComponent:kDnsSubdir];
    _dnsHostPath = [dnsDir stringByAppendingPathComponent:@"resolv.conf"];

    if (![fm fileExistsAtPath:dnsDir]) {
        [fm createDirectoryAtPath:dnsDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    [self refreshDnsConfig];

    int err = fakefs_bind_mount("/etc/resolv.conf", _dnsHostPath.fileSystemRepresentation, false);
    if (err < 0) {
        NSLog(@"KelivoISHKernel: DNS bind mount failed (%d) — writing through VFS", err);
        struct task *prev = current;
        current = pid_get_task(1);
        if (current) {
            NSString *seed = [self dnsContentString];
            struct fd *fd = generic_open("/etc/resolv.conf", O_WRONLY_ | O_CREAT_ | O_TRUNC_, 0666);
            if (!IS_ERR(fd)) {
                fd->ops->write(fd, seed.UTF8String, [seed lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
                fd_close(fd);
            }
        }
        current = prev;
        return;
    }
    [self startDnsWatcher];
}

- (NSString *)dnsContentString {
    NSMutableArray<NSString *> *servers = [NSMutableArray array];
    void (^addServer)(NSString *) = ^(NSString *raw) {
        NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (s.length == 0 || [servers containsObject:s]) return;
        [servers addObject:s];
    };

    FILE *resolv = fopen("/etc/resolv.conf", "r");
    if (resolv != NULL) {
        char line[512];
        while (fgets(line, sizeof(line), resolv) != NULL) {
            char ns[256];
            if (sscanf(line, "nameserver %255s", ns) == 1) {
                NSString *server = [NSString stringWithUTF8String:ns];
                if ([self isUsableDnsServer:server]) addServer(server);
            }
        }
        fclose(resolv);
    }

    for (size_t i = 0; i < sizeof(kPublicDns) / sizeof(kPublicDns[0]); i++) {
        addServer([NSString stringWithUTF8String:kPublicDns[i]]);
    }

    NSMutableString *content = [NSMutableString string];
    for (NSString *server in servers) {
        [content appendFormat:@"nameserver %@\n", server];
    }
    return content;
}

- (BOOL)isUsableDnsServer:(NSString *)server {
    struct in_addr addr4;
    if (inet_pton(AF_INET, server.UTF8String, &addr4) == 1) {
        const uint8_t *bytes = (const uint8_t *)&addr4;
        return bytes[0] != 127;
    }
    struct in6_addr addr6;
    if (inet_pton(AF_INET6, server.UTF8String, &addr6) == 1) {
        return memcmp(&addr6, &in6addr_loopback, sizeof(addr6)) != 0;
    }
    return NO;
}

- (void)refreshDnsConfig {
    if (_dnsHostPath == nil) return;
    NSString *content = [self dnsContentString];
    NSError *error = nil;
    if (![content writeToFile:_dnsHostPath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        NSLog(@"KelivoISHKernel: DNS refresh write failed: %@", error);
    }
}

static void KelivoDnsReachabilityChanged(SCNetworkReachabilityRef target,
                                         SCNetworkReachabilityFlags flags,
                                         void *info) {
    (void)target;
    (void)flags;
    @autoreleasepool {
        KelivoISHKernel *kernel = (__bridge KelivoISHKernel *)info;
        dispatch_async(dispatch_get_main_queue(), ^{
            [kernel refreshDnsConfig];
        });
    }
}

- (void)startDnsWatcher {
    if (_dnsReachability != NULL) return;
    SCNetworkReachabilityRef reachability =
        SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, "1.1.1.1");
    if (reachability == NULL) return;
    SCNetworkReachabilityContext context = {
        .version = 0, .info = (__bridge void *)self,
        .retain = NULL, .release = NULL, .copyDescription = NULL};
    if (!SCNetworkReachabilitySetCallback(reachability, KelivoDnsReachabilityChanged, &context) ||
        !SCNetworkReachabilitySetDispatchQueue(reachability, dispatch_get_main_queue())) {
        CFRelease(reachability);
        return;
    }
    _dnsReachability = reachability;
}

- (void)setUpUnixSocketPrefix {
#if TARGET_OS_SIMULATOR
    (void)0;
#else
    NSString *tempDir = NSTemporaryDirectory();
    if ([tempDir hasPrefix:@"/private/"]) {
        tempDir = [tempDir substringFromIndex:strlen("/private")];
    }
    NSString *prefix = [tempDir stringByAppendingString:@"ishsock"];
    if (prefix.UTF8String == NULL) return;
    const size_t kSunPathMax = sizeof(((struct sockaddr_un *)0)->sun_path);
    const size_t kSuffixWorstCase = 12;
    size_t prefixLen = strlen(prefix.UTF8String);
    if (prefixLen + kSuffixWorstCase >= kSunPathMax) {
        NSLog(@"KelivoISHKernel: unix socket prefix too long — keeping default");
        return;
    }
    sock_tmp_prefix = strdup(prefix.UTF8String);
#endif
}

#pragma mark - Bind mounts

- (int)bindMountPath:(NSString *)linuxPath toHostPath:(NSString *)hostPath readOnly:(BOOL)readOnly {
    if (!_isBooted) return -1;
    // fakefs_bind_mount recursively removes its destination before binding.
    // Only replace an empty placeholder or an existing mount symlink.
    int targetError = KelivoISHValidateMountTarget(_dataPath, linuxPath);
    if (targetError < 0) return targetError;
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:hostPath isDirectory:&isDir]) {
        if ([linuxPath hasPrefix:@"/mounts/"]) return -ENOENT;
        NSError *error = nil;
        if (![fm createDirectoryAtPath:hostPath withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"KelivoISHKernel: host mkdir %@ failed: %@", hostPath, error);
            return -1;
        }
    }
    struct task *prev = current;
    current = pid_get_task(1);
    [self ensureGuestParentDirs:linuxPath];
    generic_mkdirat(AT_PWD, linuxPath.fileSystemRepresentation, 0755);
    current = prev;

    int err = fakefs_bind_mount(linuxPath.fileSystemRepresentation,
                                hostPath.fileSystemRepresentation, readOnly);
    if (err < 0) {
        NSLog(@"KelivoISHKernel: bindMount %@ -> %@ failed: %d", linuxPath, hostPath, err);
        return err;
    }
    _activeBinds[linuxPath] = hostPath;
    _readOnlyBinds[linuxPath] = @(readOnly);
    return 0;
}

- (int)bindUnmountPath:(NSString *)linuxPath {
    if (!_isBooted) return -1;
    int err = fakefs_bind_unmount(linuxPath.fileSystemRepresentation);
    [_activeBinds removeObjectForKey:linuxPath];
    [_readOnlyBinds removeObjectForKey:linuxPath];
    if (err == 0 && [linuxPath hasPrefix:@"/mounts/"]) {
        struct task *prev = current;
        current = pid_get_task(1);
        generic_rmdirat(AT_PWD, linuxPath.fileSystemRepresentation);
        current = prev;
    }
    return err;
}

- (uint64_t)filesystemContextForBinds:(NSArray<NSDictionary<NSString *, id> *> *)binds {
    NSData *data = KelivoISHCreateFilesystem(binds);
    if (!data) return 0;
    // Fork copies fs_context. Reclaim only contexts absent from the entire task
    // table, rather than freeing a shell's mapping while its children still run.
    NSMutableSet<NSNumber *> *live = [NSMutableSet set];
    lock(&pids_lock);
    for (int pid = 1; pid < MAX_PID; pid++) {
        struct task *task = pid_get_task(pid);
        if (task && !task->exiting && task->group) [live addObject:@(task->group->fs_context)];
    }
    unlock(&pids_lock);
    for (NSData *old in [_filesystems copy]) {
        if (![live containsObject:@((uint64_t)(uintptr_t)old.bytes)]) [_filesystems removeObject:old];
    }
    NSData *existing = [_filesystems member:data];
    if (existing) data = existing;
    else [_filesystems addObject:data];
    return (uint64_t)(uintptr_t)data.bytes;
}

- (int)reconcileBinds:(NSArray<NSDictionary<NSString *, id> *> *)binds {
    if (!_isBooted) return -1;
    for (NSDictionary<NSString *, id> *bind in binds) {
        NSString *host = bind[@"host"];
        NSString *guest = bind[@"guest"];
        if (host.length == 0 || guest.length == 0) continue;
        NSString *currentHost = _activeBinds[guest];
        BOOL readOnly = [bind[@"readOnly"] boolValue];
        if ([currentHost isEqualToString:host] && [_readOnlyBinds[guest] boolValue] == readOnly) continue;
        if (currentHost != nil) {
            [self bindUnmountPath:guest];
        }
        int err = [self bindMountPath:guest toHostPath:host readOnly:readOnly];
        if (err < 0) return err;
    }
    return 0;
}

- (int)reconcileExternalBinds:(NSArray<NSDictionary<NSString *, id> *> *)binds {
    if (!_isBooted) return 0;
    // Check the whole snapshot before removing any existing bindings.
    for (NSDictionary<NSString *, id> *bind in binds) {
        int err = KelivoISHValidateMountTarget(_dataPath, bind[@"guest"]);
        if (err < 0) return err;
    }
    NSSet *desired = [NSSet setWithArray:[binds valueForKey:@"guest"]];
    for (NSString *guest in [_activeBinds.allKeys copy]) {
        if ([guest hasPrefix:@"/mounts/"] && ![desired containsObject:guest]) {
            int err = [self bindUnmountPath:guest];
            if (err < 0) return err;
        }
    }
    return [self reconcileBinds:binds];
}

- (void)ptyCloseAll {
    [_ptyLock lock];
    NSArray *sessions = [_ptyBySession.allKeys copy];
    [_ptyLock unlock];
    for (NSString *session in sessions) [self ptyCloseSession:session];
}

#pragma mark - PTY

- (BOOL)guestFileExists:(const char *)path {
    struct fd *fd = generic_open(path, O_RDONLY_, 0);
    if (IS_ERR(fd)) return NO;
    fd_close(fd);
    return YES;
}

- (int)ptyOpenSession:(NSString *)sessionId
                binds:(NSArray<NSDictionary<NSString *, id> *> *)binds
                  cwd:(NSString *)cwd
                  env:(NSDictionary<NSString *, NSString *> *)env
                 cols:(int)cols
                 rows:(int)rows {
    if (!_isBooted) return KelivoISHPtyOpenErrorNotBooted;
    if (sessionId.length == 0) return KelivoISHPtyOpenErrorBadSessionId;

    [_ptyLock lock];
    BOOL exists = _ptyBySession[sessionId] != nil;
    [_ptyLock unlock];
    if (exists) {
        NSLog(@"KelivoISHKernel: pty session %@ is already open", sessionId);
        return KelivoISHPtyOpenErrorSessionExists;
    }

    NSMutableDictionary<NSString *, NSString *> *merged = [@{
        @"TERM": @"xterm-256color",
        @"HOME": @"/root",
        @"PATH": @"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        @"LANG": @"C.UTF-8",
        @"PS1": @"\\u@kelivo:\\w\\$ ",
    } mutableCopy];
    if (env) [merged addEntriesFromDictionary:env];
    KelivoISHEnvironmentError environmentError;
    NSData *environmentData = KelivoISHEncodeEnvironment(merged, &environmentError);
    if (environmentData == nil) {
        return environmentError == KelivoISHEnvironmentErrorTooLarge
            ? KelivoISHPtyOpenErrorEnvironmentTooLarge
            : KelivoISHPtyOpenErrorInvalidEnvironment;
    }

    __block int resultPid = -1;
    [self performOnSpawnQueue:^{
        struct task *saved = current;
        @try {
            uint64_t filesystem = [self filesystemContextForBinds:binds];
            if (!filesystem) { resultPid = -EINVAL; return; }
            int err = become_new_init_child();
            if (err < 0) {
                resultPid = err;
                return;
            }

            current->group->fs_context = filesystem;
            struct tty *tty = pty_open_fake(&kelivo_pty_driver);
            if (IS_ERR(tty)) {
                resultPid = (int)PTR_ERR(tty);
                return;
            }
            struct winsize_ winsize = {
                .row = rows > 0 ? rows : 24,
                .col = cols > 0 ? cols : 80,
                .xpixel = 0,
                .ypixel = 0,
            };
            tty_set_winsize(tty, winsize);

            NSString *stdioFile = [NSString stringWithFormat:@"/dev/pts/%d", tty->num];
            err = create_stdio(stdioFile.fileSystemRepresentation, TTY_PSEUDO_SLAVE_MAJOR, tty->num);
            if (err < 0) {
                resultPid = err;
                return;
            }

            if (cwd.length > 0) {
                struct statbuf st;
                int statErr = generic_statat(AT_PWD, cwd.UTF8String, &st, true);
                if (statErr >= 0 && (st.mode & S_IFDIR)) {
                    struct fd *dir = generic_open(cwd.UTF8String, O_RDONLY_, 0);
                    if (!IS_ERR(dir)) {
                        fs_chdir(current->fs, dir);
                    }
                }
            }

            BOOL useBash = [self guestFileExists:"/bin/bash"];
            const char *execPath = useBash ? "/bin/bash" : "/bin/sh";
            NSArray<NSString *> *argvArray = useBash ? @[ @"/bin/bash", @"-l" ] : @[ @"/bin/sh", @"-l" ];
            char argv_buf[4096];
            size_t pos = 0;
            int argc = 0;
            for (NSString *arg in argvArray) {
                const char *s = arg.UTF8String;
                size_t len = strlen(s) + 1;
                if (pos + len >= sizeof(argv_buf) - 1) break;
                memcpy(argv_buf + pos, s, len);
                pos += len;
                argc++;
            }
            argv_buf[pos] = '\0';

            err = do_execve(execPath, argc, argv_buf, environmentData.bytes);
            if (err < 0) {
                resultPid = err;
                return;
            }

            KelivoISHPtySession *session = [[KelivoISHPtySession alloc] init];
            session.sessionId = sessionId;
            session.pid = current->pid;
            session.pgid = current->group->pgid;
            session.tty = tty;
            [_ptyLock lock];
            self->_ptyBySession[sessionId] = session;
            self->_ptyByPid[@(session.pid)] = session;
            self->_ptyByTtyNum[@(tty->num)] = session;
            [_ptyLock unlock];

            resultPid = current->pid;
            task_start(current);
        } @finally {
            current = saved;
        }
    }];
    return resultPid;
}

- (void)ptyWriteSession:(NSString *)sessionId data:(NSData *)data {
    [_ptyLock lock];
    KelivoISHPtySession *session = _ptyBySession[sessionId];
    struct tty *tty = session.tty;
    [_ptyLock unlock];
    if (tty && data.length > 0) {
        tty_input(tty, data.bytes, data.length, false);
    }
}

- (void)ptyResizeSession:(NSString *)sessionId cols:(int)cols rows:(int)rows {
    [_ptyLock lock];
    KelivoISHPtySession *session = _ptyBySession[sessionId];
    struct tty *tty = session.tty;
    [_ptyLock unlock];
    if (!tty) return;
    struct winsize_ winsize = {.row = rows, .col = cols, .xpixel = 0, .ypixel = 0};
    tty_set_winsize(tty, winsize);
}

- (void)ptyCloseSession:(NSString *)sessionId {
    [_ptyLock lock];
    KelivoISHPtySession *session = _ptyBySession[sessionId];
    [_ptyLock unlock];
    if (!session) return;
    [KelivoISHExecutor killGuestPid:session.pid groupId:session.pgid];
}

- (void)deliverPtyData:(NSData *)data ttyNum:(int)ttyNum {
    [_ptyLock lock];
    KelivoISHPtySession *session = _ptyByTtyNum[@(ttyNum)];
    NSString *sessionId = session.sessionId;
    KelivoISHPtyDataHandler handler = self.ptyDataHandler;
    [_ptyLock unlock];
    if (sessionId && handler) {
        handler(sessionId, data);
    }
}

- (void)noteGuestExitWithPid:(int)pid code:(int)code {
    [_ptyLock lock];
    KelivoISHPtySession *session = _ptyByPid[@(pid)];
    if (session) {
        [_ptyBySession removeObjectForKey:session.sessionId];
        [_ptyByPid removeObjectForKey:@(pid)];
        if (session.tty) {
            [_ptyByTtyNum removeObjectForKey:@(session.tty->num)];
        }
    }
    NSString *sessionId = session.sessionId;
    KelivoISHPtyExitHandler handler = self.ptyExitHandler;
    [_ptyLock unlock];
    if (sessionId && handler) {
        handler(sessionId, code);
    }
}

@end
