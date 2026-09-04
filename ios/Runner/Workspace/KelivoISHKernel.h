//
//  KelivoISHKernel.h
//  Runner
//
//  Objective-C wrapper around the embedded iSH-ARM64 kernel for the Kelivo
//  Workspace sandbox. Boots exactly once per app process (become_first_process
//  is irreversible). Host directories are exposed via fakefs bind mounts.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const KelivoISHProcessExitedNotification;

typedef void (^KelivoISHPtyDataHandler)(NSString *sessionId, NSData *data);
typedef void (^KelivoISHPtyExitHandler)(NSString *sessionId, int exitCode);

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

/// For each {host, guest}, mount if absent and remount if the host changed.
- (int)reconcileBinds:(NSArray<NSDictionary<NSString *, NSString *> *> *)binds;

- (int)bindMountPath:(NSString *)linuxPath toHostPath:(NSString *)hostPath;
- (int)bindUnmountPath:(NSString *)linuxPath;

@property (nonatomic, copy, nullable) KelivoISHPtyDataHandler ptyDataHandler;
@property (nonatomic, copy, nullable) KelivoISHPtyExitHandler ptyExitHandler;

/// Open a login PTY session (`/bin/bash -l` if present, else `/bin/sh -l`).
/// Returns the guest pid, or a negative errno-style code.
- (int)ptyOpenSession:(NSString *)sessionId
                  cwd:(nullable NSString *)cwd
                  env:(nullable NSDictionary<NSString *, NSString *> *)env
                 cols:(int)cols
                 rows:(int)rows;

- (void)ptyWriteSession:(NSString *)sessionId data:(NSData *)data;
- (void)ptyResizeSession:(NSString *)sessionId cols:(int)cols rows:(int)rows;
- (void)ptyCloseSession:(NSString *)sessionId;

@end

NS_ASSUME_NONNULL_END
