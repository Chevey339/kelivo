//
//  KelivoISHExecutor.h
//  Runner
//
//  Per-call `/bin/sh -c` inside the embedded iSH guest with streamed
//  stdout/stderr and cancel/timeout.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^KelivoISHChunkHandler)(NSString *runId, BOOL isStderr, NSData *chunk);
typedef void (^KelivoISHDoneHandler)(NSDictionary<NSString *, id> *result);

@interface KelivoISHExecutor : NSObject

/// Fork `/bin/sh -c <command>` with separate pipes. `done` is invoked once
/// with exitCode, timedOut, durationMs, cancelled, interrupted.
+ (BOOL)startCommand:(NSString *)command
               runId:(NSString *)runId
               binds:(NSArray<NSDictionary<NSString *, id> *> *)binds
                 cwd:(nullable NSString *)cwd
                 env:(nullable NSDictionary<NSString *, NSString *> *)env
           timeoutMs:(NSInteger)timeoutMs
               chunk:(KelivoISHChunkHandler)chunk
                done:(KelivoISHDoneHandler)done;

+ (BOOL)cancelRunId:(NSString *)runId;
+ (void)cancelAllInterrupted:(BOOL)interrupted;

/// Signal a guest process group (used by PTY close).
+ (void)killGuestPid:(int)pid groupId:(int)pgid;

@end

NS_ASSUME_NONNULL_END
