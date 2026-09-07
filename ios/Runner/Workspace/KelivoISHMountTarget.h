#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// App-layer refusal, outside the guest errno range.
extern const int KelivoISHMountTargetOccupied;

/// Reject external binds that would erase guest files. Existing fakefs bind
/// symlinks and empty placeholder directories may be replaced. Read-only check;
/// changes to the fakefs data tree must still go through the guest VFS.
int KelivoISHValidateMountTarget(NSString *dataPath, NSString *guestPath);

NS_ASSUME_NONNULL_END
