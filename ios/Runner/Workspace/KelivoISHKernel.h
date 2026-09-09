//
//  KelivoISHKernel.h
//  Runner
//
//  Objective-C wrapper around the embedded iSH-ARM64 kernel for the Kelivo
//  Workspace sandbox. Boots exactly once per app process (become_first_process
//  is irreversible). Command roots use per-process fakefs path contexts.
//

#import <Foundation/Foundation.h>
#import "KelivoISHMountTarget.h"

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const KelivoISHProcessExitedNotification;

typedef void (^KelivoISHPtyDataHandler)(NSString *sessionId, NSData *data);
typedef void (^KelivoISHPtyExitHandler)(NSString *sessionId, int exitCode);

/// Why -[KelivoISHKernel ptyOpenSession:...] refused before reaching the
/// guest. Kept clear of the guest errno range (errno.h negates down to -133)
/// so a wrapper refusal is never mistaken for a kernel error such as _EPERM.
typedef NS_ENUM(int, KelivoISHPtyOpenError) {
  KelivoISHPtyOpenErrorNotBooted = -1001,
  KelivoISHPtyOpenErrorBadSessionId = -1002,
  KelivoISHPtyOpenErrorSessionExists = -1003,
  KelivoISHPtyOpenErrorEnvironmentTooLarge = -1004,
  KelivoISHPtyOpenErrorInvalidEnvironment = -1005,
};

@interface KelivoISHKernel : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) BOOL isBooted;
@property (nonatomic, readonly, nullable) NSString *bootRootPath;

/// Serializes become_new_init_child / do_execve. The block runs on a
/// dedicated queue; the calling thread waits.
- (void)performOnSpawnQueue:(void (^)(void))block;

/// Boot the kernel and mount the fakefs rootfs at [rootPath]/data.
/// Idempotent. Must be called from a background thread (becomes guest PID 1).
- (int)bootWithRootPath:(NSString *)rootPath;

/// On the spawn queue, obtain retained immutable mappings for a new task.
- (uint64_t)filesystemContextForBinds:(NSArray<NSDictionary<NSString *, id> *> *)binds;
- (int)reconcileExternalBinds:(NSArray<NSDictionary<NSString *, id> *> *)binds;

- (int)bindMountPath:(NSString *)linuxPath toHostPath:(NSString *)hostPath readOnly:(BOOL)readOnly;
- (int)bindUnmountPath:(NSString *)linuxPath;

@property (nonatomic, copy, nullable) KelivoISHPtyDataHandler ptyDataHandler;
@property (nonatomic, copy, nullable) KelivoISHPtyExitHandler ptyExitHandler;

/// Open a login PTY session (`/bin/bash -l` if present, else `/bin/sh -l`).
/// Returns the guest pid, a negative errno-style code from the guest, or a
/// [KelivoISHPtyOpenError] when this wrapper refused the request.
///
/// [sessionId] must be unique for the life of the process: a session is
/// unregistered only once its guest process reports exit, so a reused id is
/// refused rather than silently replacing the live session.
- (int)ptyOpenSession:(NSString *)sessionId
                binds:(NSArray<NSDictionary<NSString *, id> *> *)binds
                  cwd:(nullable NSString *)cwd
                  env:(nullable NSDictionary<NSString *, NSString *> *)env
                 cols:(int)cols
                 rows:(int)rows;

- (void)ptyWriteSession:(NSString *)sessionId data:(NSData *)data;
- (void)ptyResizeSession:(NSString *)sessionId cols:(int)cols rows:(int)rows;
- (void)ptyCloseSession:(NSString *)sessionId;
- (void)ptyCloseAll;

@end

NS_ASSUME_NONNULL_END
