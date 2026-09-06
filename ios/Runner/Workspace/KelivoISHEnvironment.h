#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// iSH kernel/exec.c limits each argv/envp string block to 32 guest 4 KiB pages.
extern const NSUInteger KelivoISHEnvironmentMaxBytes;

typedef NS_ENUM(NSInteger, KelivoISHEnvironmentError) {
    KelivoISHEnvironmentErrorNone,
    KelivoISHEnvironmentErrorInvalidEntry,
    KelivoISHEnvironmentErrorTooLarge,
};

/// Encodes all UTF-8 NAME=value entries, including their NUL terminators and
/// the final empty entry required by do_execve. Never returns a partial block.
NSData * _Nullable KelivoISHEncodeEnvironment(
    NSDictionary<NSString *, NSString *> *environment,
    KelivoISHEnvironmentError *error);

NSString *KelivoISHEnvironmentErrorMessage(KelivoISHEnvironmentError error);

NS_ASSUME_NONNULL_END
