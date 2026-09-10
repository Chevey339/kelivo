//
//  KelivoISHExecutor.m
//  Runner
//
//  Adapted from Cuplivo/OpenMinis ISHShellExecutor.m (GPL-3.0, see
//  ios/sandbox/NOTICE). Streams stdout/stderr as chunks instead of
//  capturing a 64 KiB preview.
//

#import "KelivoISHExecutor.h"
#import "KelivoISHKernel.h"
#import "KelivoISHEnvironment.h"
#import "KelivoISHCompat.h"
#import "KelivoISHStdin.h"

#include "ish/kernel/init.h"
#include "ish/kernel/calls.h"
#include "ish/kernel/task.h"
#include "ish/kernel/signal.h"
#include "ish/kernel/fs.h"
#include "ish/fs/devices.h"
#include "ish/fs/real.h"
#include "ish/fs/path.h"
#include "ish/fs/stat.h"

#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <poll.h>
#include <stdlib.h>
#include <string.h>

static const NSTimeInterval kDrainGraceSeconds = 1.0;
static const NSTimeInterval kKillGraceSeconds = 2.0;
static const NSTimeInterval kReaderJoinSeconds = 1.5;

#pragma mark - Context

@interface KelivoISHRunContext : NSObject {
    int _stdoutReadEnd;
    int _stderrReadEnd;
    int _stdinPipe[2];
    int _stdoutPipe[2];
    int _stderrPipe[2];
}
@property (nonatomic, copy) NSString *runId;
@property (nonatomic) int guestPid;
@property (nonatomic) int guestPgid;
@property (nonatomic, copy) KelivoISHChunkHandler chunk;
@property (nonatomic, copy) KelivoISHDoneHandler done;
@property (nonatomic, readonly) dispatch_group_t readersGroup;
@property (nonatomic) NSDate *startedAt;
@property (atomic) int exitCode;
@property (atomic) BOOL exited;
@property (atomic) BOOL cancelled;
@property (atomic) BOOL interrupted;
@property (atomic) BOOL timedOut;
@property (atomic) BOOL didFinalize;
@property (atomic) BOOL stdoutReaderDone;
@property (atomic) BOOL stderrReaderDone;
@property (atomic) BOOL stdoutAbort;
@property (atomic) BOOL stderrAbort;
- (int *)stdinPipe;
- (int *)stdoutPipe;
- (int *)stderrPipe;
- (void)adoptReadEnd:(int)fd isStdErr:(BOOL)isStdErr;
- (void)closeOwnedReadEnd:(BOOL)isStdErr;
- (void)closeStdin;
- (void)closePipeEnds;
@end

@implementation KelivoISHRunContext

- (int *)stdinPipe { return _stdinPipe; }
- (int *)stdoutPipe { return _stdoutPipe; }
- (int *)stderrPipe { return _stderrPipe; }

- (instancetype)init {
    if (self = [super init]) {
        _readersGroup = dispatch_group_create();
        _stdinPipe[0] = _stdinPipe[1] = -1;
        _stdoutPipe[0] = _stdoutPipe[1] = -1;
        _stderrPipe[0] = _stderrPipe[1] = -1;
        _stdoutReadEnd = _stderrReadEnd = -1;
        _exitCode = -1;
        _startedAt = [NSDate date];
    }
    return self;
}

- (void)adoptReadEnd:(int)fd isStdErr:(BOOL)isStdErr {
    @synchronized (self) {
        if (isStdErr) {
            _stderrReadEnd = fd;
            _stderrPipe[0] = -1;
        } else {
            _stdoutReadEnd = fd;
            _stdoutPipe[0] = -1;
        }
    }
}

- (void)closeOwnedReadEnd:(BOOL)isStdErr {
    int fd;
    @synchronized (self) {
        fd = isStdErr ? _stderrReadEnd : _stdoutReadEnd;
        if (isStdErr) _stderrReadEnd = -1;
        else _stdoutReadEnd = -1;
    }
    if (fd >= 0) close(fd);
}

- (void)closeStdin {
    @synchronized (self) {
        if (_stdinPipe[1] >= 0) {
            // Wake a guest blocked in host read(), even when a writer owns a
            // duplicate descriptor. Guest signals cannot interrupt realfs_read.
            shutdown(_stdinPipe[1], SHUT_RDWR);
            close(_stdinPipe[1]);
            _stdinPipe[1] = -1;
        }
    }
}

- (void)closePipeEnds {
    [self closeStdin];
    @synchronized (self) {
        if (_stdinPipe[0] >= 0) close(_stdinPipe[0]);
        if (_stdinPipe[1] >= 0) close(_stdinPipe[1]);
        if (_stdoutPipe[0] >= 0) close(_stdoutPipe[0]);
        if (_stdoutPipe[1] >= 0) close(_stdoutPipe[1]);
        if (_stderrPipe[0] >= 0) close(_stderrPipe[0]);
        if (_stderrPipe[1] >= 0) close(_stderrPipe[1]);
        _stdinPipe[0] = _stdinPipe[1] = -1;
        _stdoutPipe[0] = _stdoutPipe[1] = -1;
        _stderrPipe[0] = _stderrPipe[1] = -1;
    }
}

- (void)dealloc {
    [self closePipeEnds];
}

@end

#pragma mark - Executor

@implementation KelivoISHExecutor

static NSMutableDictionary<NSNumber *, KelivoISHRunContext *> *_byPid;
static NSMutableDictionary<NSString *, KelivoISHRunContext *> *_byRunId;
static NSMutableSet<NSString *> *_cancelled;
static NSMutableSet<NSString *> *_queued;
static dispatch_queue_t _readerQueue;

+ (void)initialize {
    if (self == [KelivoISHExecutor class]) {
        _byPid = [NSMutableDictionary dictionary];
        _byRunId = [NSMutableDictionary dictionary];
        _cancelled = [NSMutableSet set];
        _queued = [NSMutableSet set];
        _readerQueue = dispatch_queue_create("psyche.kelivo.workspace.ish.reader", DISPATCH_QUEUE_CONCURRENT);
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(processDidExit:)
                                                     name:KelivoISHProcessExitedNotification
                                                   object:nil];
    }
}

+ (NSDictionary *)defaultEnv {
    return @{
        @"NO_COLOR": @"1",
        @"CI": @"true",
        @"PAGER": @"cat",
        @"TERM": @"dumb",
        @"LANG": @"C.UTF-8",
        @"HOME": @"/root",
        @"PATH": @"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
    };
}

+ (BOOL)startCommand:(NSString *)command
               runId:(NSString *)runId
               binds:(NSArray<NSDictionary<NSString *, id> *> *)binds
                 cwd:(NSString *)cwd
                 env:(NSDictionary<NSString *, NSString *> *)env
           timeoutMs:(NSInteger)timeoutMs
       keepStdinOpen:(BOOL)keepStdinOpen
             started:(void (^)(void))started
               chunk:(KelivoISHChunkHandler)chunk
                done:(KelivoISHDoneHandler)done {
    if (runId.length == 0 || command.length == 0) return NO;
    @synchronized (_byPid) {
        if (_byRunId[runId] || [_queued containsObject:runId]) return NO;
        [_queued addObject:runId];
    }

    NSTimeInterval timeout = keepStdinOpen && timeoutMs == 0 ? 0 : MAX(0.001, MIN((double)timeoutMs / 1000.0, 3600.0));
    [[KelivoISHKernel shared] performOnSpawnQueue:^{
        BOOL early = NO;
        @synchronized (_byPid) {
            if ([_cancelled containsObject:runId]) {
                [_cancelled removeObject:runId];
                [_queued removeObject:runId];
                early = YES;
            }
        }
        if (early) {
            done(@{
                @"exitCode": @(-1),
                @"timedOut": @NO,
                @"cancelled": @YES,
                @"interrupted": @NO,
                @"durationMs": @0,
            });
            return;
        }
        [self spawnCommand:command
                     runId:runId
                     binds:binds
                       cwd:cwd
                       env:env
                   timeout:timeout
             keepStdinOpen:keepStdinOpen
                   started:started
                     chunk:chunk
                      done:done];
    }];
    return YES;
}

+ (BOOL)writeStdin:(NSData *)data runId:(NSString *)runId {
    KelivoISHRunContext *ctx;
    @synchronized (_byPid) { ctx = _byRunId[runId]; }
    if (!ctx) return NO;
    int fd;
    @synchronized (ctx) {
        fd = [ctx stdinPipe][1] >= 0 ? dup([ctx stdinPipe][1]) : -1;
    }
    if (fd < 0) return NO;
    const char *bytes = data.bytes;
    NSUInteger offset = 0;
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:30];
    while (offset < data.length && !ctx.cancelled && !ctx.exited && !ctx.didFinalize) {
        ssize_t n = write(fd, bytes + offset, data.length - offset);
        if (n > 0) { offset += (NSUInteger)n; continue; }
        if (n < 0 && errno == EINTR) continue;
        if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK) && deadline.timeIntervalSinceNow > 0) {
            struct pollfd pfd = {.fd = fd, .events = POLLOUT};
            poll(&pfd, 1, 100);
            continue;
        }
        break;
    }
    close(fd);
    return offset == data.length;
}

+ (BOOL)cancelRunId:(NSString *)runId {
    if (runId.length == 0) return NO;
    KelivoISHRunContext *ctx = nil;
    @synchronized (_byPid) {
        ctx = _byRunId[runId];
        if (ctx) {
            ctx.cancelled = YES;
        } else if ([_queued containsObject:runId]) {
            [_cancelled addObject:runId];
            return YES;
        } else {
            return NO;
        }
    }
    [ctx closeStdin];
    if (ctx.guestPid > 1) {
        [self killGuestPid:ctx.guestPid groupId:ctx.guestPgid];
    }
    return YES;
}

+ (void)cancelAllInterrupted:(BOOL)interrupted {
    NSArray<KelivoISHRunContext *> *active;
    @synchronized (_byPid) {
        active = _byRunId.allValues;
        [_cancelled addObjectsFromArray:_queued.allObjects];
        for (KelivoISHRunContext *ctx in active) {
            ctx.cancelled = YES;
            if (interrupted) ctx.interrupted = YES;
        }
    }
    for (KelivoISHRunContext *ctx in active) {
        [ctx closeStdin];
        if (ctx.guestPid > 1) {
            [self killGuestPid:ctx.guestPid groupId:ctx.guestPgid];
        }
    }
}

+ (void)spawnCommand:(NSString *)command
               runId:(NSString *)runId
               binds:(NSArray<NSDictionary<NSString *, id> *> *)binds
                 cwd:(NSString *)cwd
                 env:(NSDictionary<NSString *, NSString *> *)env
             timeout:(NSTimeInterval)timeout
       keepStdinOpen:(BOOL)keepStdinOpen
             started:(void (^)(void))started
               chunk:(KelivoISHChunkHandler)chunk
                done:(KelivoISHDoneHandler)done {
    void (^fail)(NSString *) = ^(NSString *reason) {
        @synchronized (_byPid) {
            [_queued removeObject:runId];
        }
        NSLog(@"KelivoISHExecutor: %@", reason);
        done(@{
            @"exitCode": @(-1),
            @"timedOut": @NO,
            @"cancelled": @NO,
            @"interrupted": @NO,
            @"durationMs": @0,
            @"error": reason,
        });
    };

    if (![KelivoISHKernel shared].isBooted) {
        fail(@"kernel not booted");
        return;
    }

    NSMutableDictionary<NSString *, NSString *> *merged = [[self defaultEnv] mutableCopy];
    NSTimeZone *tz = [NSTimeZone systemTimeZone];
    NSInteger secs = tz.secondsFromGMT;
    NSInteger hrs = secs / 3600;
    NSInteger mins = labs(secs % 3600) / 60;
    if (mins != 0) {
        merged[@"TZ"] = [NSString stringWithFormat:@"LCL%+ld:%02ld", (long)-hrs, (long)mins];
    } else {
        merged[@"TZ"] = [NSString stringWithFormat:@"LCL%+ld", (long)-hrs];
    }
    if (env) [merged addEntriesFromDictionary:env];
    KelivoISHEnvironmentError environmentError;
    __attribute__((objc_precise_lifetime)) NSData *environmentData =
        KelivoISHEncodeEnvironment(merged, &environmentError);
    if (environmentData == nil) {
        NSString *reason = KelivoISHEnvironmentErrorMessage(environmentError);
        chunk(runId, YES, [[reason stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]);
        fail(reason);
        return;
    }

    KelivoISHRunContext *ctx = [[KelivoISHRunContext alloc] init];
    ctx.runId = runId;
    ctx.chunk = chunk;
    ctx.done = done;

    if (pipe([ctx stdoutPipe]) < 0 || pipe([ctx stderrPipe]) < 0) {
        [ctx closePipeEnds];
        fail(@"pipe() failed");
        return;
    }

    if (keepStdinOpen) {
        if (KelivoISHCreateStdinPipe([ctx stdinPipe]) < 0) {
            [ctx closePipeEnds];
            fail(@"stdin pipe failed");
            return;
        }
    }

    uint64_t filesystem = [[KelivoISHKernel shared] filesystemContextForBinds:binds];
    if (!filesystem) {
        [ctx closePipeEnds];
        fail(@"invalid filesystem bindings");
        return;
    }
    struct task *saved = current;
    int err = become_new_init_child();
    if (err < 0) {
        current = saved;
        [ctx closePipeEnds];
        fail([NSString stringWithFormat:@"become_new_init_child failed: %d", err]);
        return;
    }
    struct task *task = current;
    task->group->fs_context = filesystem;
    task->group->host_managed_lifetime = keepStdinOpen && timeout == 0;

    struct fd *stdin_fd = adhoc_fd_create(&realfs_fdops);
    if (stdin_fd) {
        int real_fd = keepStdinOpen ? dup([ctx stdinPipe][0]) : open("/dev/null", O_RDONLY);
        if (real_fd < 0) {
            current = saved;
            [ctx closePipeEnds];
            fail(@"open /dev/null failed");
            return;
        }
        stdin_fd->real_fd = real_fd;
        if (keepStdinOpen) {
            // libuv selects its stdin reader using guest fstat(), which an
            // ad-hoc descriptor otherwise reports as an unknown file type.
            stdin_fd->stat.mode = S_IFIFO | 0600;
        }
        task->files->files[0] = stdin_fd;
    }

    struct fd *stdout_fd = adhoc_fd_create(&realfs_fdops);
    if (stdout_fd) {
        int real_fd = dup([ctx stdoutPipe][1]);
        if (real_fd < 0) {
            current = saved;
            [ctx closePipeEnds];
            fail(@"dup(stdout) failed");
            return;
        }
        stdout_fd->real_fd = real_fd;
        stdout_fd->stat.mode = S_IFIFO | 0600;
        task->files->files[1] = stdout_fd;
    }
    struct fd *stderr_fd = adhoc_fd_create(&realfs_fdops);
    if (stderr_fd) {
        int real_fd = dup([ctx stderrPipe][1]);
        if (real_fd < 0) {
            current = saved;
            [ctx closePipeEnds];
            fail(@"dup(stderr) failed");
            return;
        }
        stderr_fd->real_fd = real_fd;
        stderr_fd->stat.mode = S_IFIFO | 0600;
        task->files->files[2] = stderr_fd;
    }
    if ([ctx stdinPipe][0] >= 0) {
        close([ctx stdinPipe][0]);
        [ctx stdinPipe][0] = -1;
    }
    close([ctx stdoutPipe][1]);
    close([ctx stderrPipe][1]);
    [ctx stdoutPipe][1] = -1;
    [ctx stderrPipe][1] = -1;

    if (cwd.length > 0) {
        struct statbuf st;
        int statErr = generic_statat(AT_PWD, cwd.UTF8String, &st, true);
        if (statErr < 0 || !(st.mode & S_IFDIR)) {
            current = saved;
            [ctx closePipeEnds];
            fail([NSString stringWithFormat:@"cwd not found: %@", cwd]);
            return;
        }
        struct fd *dir = generic_open(cwd.UTF8String, O_RDONLY_, 0);
        if (IS_ERR(dir)) {
            current = saved;
            [ctx closePipeEnds];
            fail(@"cwd open failed");
            return;
        }
        fs_chdir(task->fs, dir);
    }

    NSString *normalized = [command hasSuffix:@"\n"] ? command : [command stringByAppendingString:@"\n"];
    NSArray<NSString *> *argvArray = @[ @"/bin/sh", @"-c", normalized ];
    char argv_buf[16384];
    size_t pos = 0;
    int exec_argc = 0;
    for (NSString *arg in argvArray) {
        const char *str = arg.UTF8String;
        size_t len = strlen(str) + 1;
        if (pos + len >= sizeof(argv_buf) - 1) {
            current = saved;
            [ctx closePipeEnds];
            fail(@"argv too long");
            return;
        }
        memcpy(argv_buf + pos, str, len);
        pos += len;
        exec_argc++;
    }
    argv_buf[pos] = '\0';

    err = do_execve("/bin/sh", exec_argc, argv_buf, environmentData.bytes);
    if (err < 0) {
        current = saved;
        [ctx closePipeEnds];
        fail([NSString stringWithFormat:@"do_execve failed: %d", err]);
        return;
    }

    ctx.guestPid = task->pid;
    ctx.guestPgid = (int)task->group->pgid;
    @synchronized (_byPid) {
        _byPid[@(ctx.guestPid)] = ctx;
        _byRunId[runId] = ctx;
        [_queued removeObject:runId];
        if ([_cancelled containsObject:runId]) {
            [_cancelled removeObject:runId];
            ctx.cancelled = YES;
        }
    }

    task_start(task);
    current = saved;
    if (keepStdinOpen) started();

    int stdoutReadFd = [ctx stdoutPipe][0];
    int stderrReadFd = [ctx stderrPipe][0];
    [ctx adoptReadEnd:stdoutReadFd isStdErr:NO];
    [self startReaderForPipe:stdoutReadFd context:ctx isStdErr:NO];
    [ctx adoptReadEnd:stderrReadFd isStdErr:YES];
    [self startReaderForPipe:stderrReadFd context:ctx isStdErr:YES];

    if (ctx.cancelled) {
        [ctx closeStdin];
        [self killGuestPid:ctx.guestPid groupId:ctx.guestPgid];
    }

    if (timeout == 0) return;
    int capturedPid = ctx.guestPid;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)),
                   dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        KelivoISHRunContext *still;
        @synchronized (_byPid) {
            still = _byPid[@(capturedPid)];
            // Always stamp timedOut if the run is still live. processDidExit
            // can flip `exited` in the same window the timeout fires (the
            // guest often dies from the kill we are about to send, or a
            // previous finalize is mid-drain). Skipping the flag here was
            // reporting exit=-1 with timedOut=false.
            if (!still || still.didFinalize) return;
            still.timedOut = YES;
        }
        if (!still.exited) {
            [self killGuestPid:still.guestPid groupId:still.guestPgid];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kKillGraceSeconds * NSEC_PER_SEC)),
                       dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            [self finalizeContext:still];
        });
    });
}

+ (void)processDidExit:(NSNotification *)notification {
    int pid = [notification.userInfo[@"pid"] intValue];
    int exitCode = [notification.userInfo[@"code"] intValue];
    KelivoISHRunContext *ctx;
    @synchronized (_byPid) {
        ctx = _byPid[@(pid)];
    }
    if (!ctx) return;
    ctx.exitCode = exitCode;
    ctx.exited = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDrainGraceSeconds * NSEC_PER_SEC)),
                   dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [self finalizeContext:ctx];
    });
}

+ (void)finalizeContext:(KelivoISHRunContext *)ctx {
    @synchronized (ctx) {
        if (ctx.didFinalize) return;
        ctx.didFinalize = YES;
    }
    ctx.stdoutAbort = YES;
    ctx.stderrAbort = YES;
    (void)dispatch_group_wait(
        ctx.readersGroup,
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kReaderJoinSeconds * NSEC_PER_SEC)));

    @synchronized (_byPid) {
        [_byPid removeObjectForKey:@(ctx.guestPid)];
        [_byRunId removeObjectForKey:ctx.runId];
    }

    [ctx closePipeEnds];

    NSInteger durationMs = (NSInteger)lround(-[ctx.startedAt timeIntervalSinceNow] * 1000.0);
    int code = (ctx.timedOut || ctx.cancelled || ctx.interrupted) ? -1 : ctx.exitCode;
    if (ctx.done) {
        ctx.done(@{
            @"exitCode": @(code),
            @"timedOut": @(ctx.timedOut && !ctx.cancelled && !ctx.interrupted),
            @"cancelled": @(ctx.cancelled && !ctx.interrupted),
            @"interrupted": @(ctx.interrupted),
            @"durationMs": @(MAX(0, durationMs)),
        });
    }
}

+ (void)startReaderForPipe:(int)fd context:(KelivoISHRunContext *)ctx isStdErr:(BOOL)isStdErr {
    dispatch_group_enter(ctx.readersGroup);
    dispatch_async(_readerQueue, ^{
        [self readPipe:fd context:ctx isStdErr:isStdErr];
        dispatch_group_leave(ctx.readersGroup);
    });
}

+ (void)readPipe:(int)fd context:(KelivoISHRunContext *)ctx isStdErr:(BOOL)isStdErr {
    char buffer[4096];
    struct pollfd pfd = {.fd = fd, .events = POLLIN};
    for (;;) {
        if (isStdErr ? ctx.stderrAbort : ctx.stdoutAbort) break;
        int pr = poll(&pfd, 1, 500);
        if (pr < 0) {
            if (errno == EINTR) continue;
            break;
        }
        if (pr == 0) {
            if (ctx.exited || ctx.didFinalize) break;
            continue;
        }
        if ((pfd.revents & (POLLHUP | POLLERR)) && !(pfd.revents & POLLIN)) break;
        ssize_t n = read(fd, buffer, sizeof(buffer));
        if (n > 0) {
            if (ctx.chunk) {
                NSData *data = [NSData dataWithBytes:buffer length:(NSUInteger)n];
                ctx.chunk(ctx.runId, isStdErr, data);
            }
        } else if (n == 0) {
            break;
        } else {
            if (errno == EAGAIN || errno == EWOULDBLOCK) continue;
            break;
        }
    }
    [ctx closeOwnedReadEnd:isStdErr];
    if (isStdErr) ctx.stderrReaderDone = YES;
    else ctx.stdoutReaderDone = YES;
}

+ (void)killGuestPid:(int)pid groupId:(int)knownPgid {
    [self killProcessGroup:pid groupId:(pid_t_)knownPgid];
}

/// True when `t` is `rootPid` or a descendant. Walks `parent` under `pids_lock`.
static BOOL KelivoTaskIsDescendantOf(struct task *t, pid_t_ rootPid) {
    int hops = 0;
    while (t != NULL && hops < MAX_PID) {
        if (t->pid == rootPid) return YES;
        t = t->parent;
        hops++;
    }
    return NO;
}

static void KelivoAddKillTarget(struct task *t, int *pids, struct task **ptrs, int *n, int max) {
    if (!t || *n >= max) return;
    for (int i = 0; i < *n; i++) {
        if (ptrs[i] == t) return;
    }
    pids[*n] = t->pid;
    ptrs[*n] = t;
    (*n)++;
}

static void KelivoCollectChildren(struct task *task, int *pids, struct task **ptrs, int *n, int max) {
    if (!task || *n >= max) return;
    KelivoAddKillTarget(task, pids, ptrs, n, max);
    struct task *child;
    list_for_each_entry(&task->children, child, siblings) {
        KelivoCollectChildren(child, pids, ptrs, n, max);
    }
}

+ (void)killProcessGroup:(int)pid groupId:(pid_t_)knownPgid {
    // Signal every task of this exec — by pgid OR by being a descendant of
    // the root pid. Busybox ash often setpgid(0,0)s background jobs
    // (`sleep 40.5 & wait`), which a pgid-only sweep misses.
    //
    // Refuse pid <= 1: an ancestry sweep rooted at init would tear down
    // the whole kernel.
    //
    // Snapshot (pid, task*) pairs and SIGKILL those same pointers later.
    // If we only re-walk from the root, a fast-exiting `sh` aborts the
    // follow-up and leaves `sleep` blocked in host nanosleep.
    if (pid <= 1) return;
    struct siginfo_ info = SIGINFO_NIL;
    enum { kMaxKillTargets = 64 };
    int *targetPids = calloc(kMaxKillTargets, sizeof(int));
    struct task **targetPtrs = calloc(kMaxKillTargets, sizeof(struct task *));
    if (!targetPids || !targetPtrs) {
        free(targetPids);
        free(targetPtrs);
        return;
    }
    int ntargets = 0;

    lock(&pids_lock);
    struct task *rootTask = pid_get_task((dword_t)pid);
    pid_t_ pgid = rootTask ? rootTask->group->pgid : knownPgid;
    if (rootTask) {
        KelivoCollectChildren(rootTask, targetPids, targetPtrs, &ntargets, kMaxKillTargets);
    }
    for (int i = 2; i < MAX_PID && ntargets < kMaxKillTargets; i++) {
        struct task *t = pid_get_task(i);
        if (!t) continue;
        BOOL byPgid = (pgid > 1 && t->group->pgid == pgid);
        BOOL byAncestry = KelivoTaskIsDescendantOf(t, (pid_t_)pid);
        if (!byPgid && !byAncestry) continue;
        KelivoAddKillTarget(t, targetPids, targetPtrs, &ntargets, kMaxKillTargets);
    }
    for (int i = 0; i < ntargets; i++) {
        send_signal(targetPtrs[i], SIGKILL_, info);
    }
    unlock(&pids_lock);
    NSLog(@"KelivoISHExecutor: kill root=%d pgid=%d targets=%d", pid, (int)pgid, ntargets);
    if (ntargets == 0) {
        free(targetPids);
        free(targetPtrs);
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(200 * NSEC_PER_MSEC)),
                   dispatch_get_global_queue(0, 0), ^{
        lock(&pids_lock);
        for (int i = 0; i < ntargets; i++) {
            struct task *still = pid_get_task((dword_t)targetPids[i]);
            if (still != targetPtrs[i]) continue;
            send_signal(still, SIGKILL_, info);
        }
        unlock(&pids_lock);
        free(targetPids);
        free(targetPtrs);
    });
}

@end
