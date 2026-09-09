#import "KelivoISHMountTarget.h"
#include <dirent.h>
#include <errno.h>
#include <string.h>
#include <sys/stat.h>

const int KelivoISHMountTargetOccupied = -1101;

int KelivoISHValidateMountTarget(NSString *dataPath, NSString *guestPath) {
    if (![guestPath hasPrefix:@"/mounts/"]) return 0;
    NSString *target = [dataPath stringByAppendingPathComponent:guestPath];
    struct stat st;
    if (lstat(target.fileSystemRepresentation, &st) < 0) {
        return errno == ENOENT ? 0 : -errno;
    }
    // fakefs persists binds as symlinks. Do not inspect their source contents.
    if (S_ISLNK(st.st_mode)) return 0;
    if (!S_ISDIR(st.st_mode)) return KelivoISHMountTargetOccupied;

    DIR *directory = opendir(target.fileSystemRepresentation);
    if (directory == NULL) return -errno;
    int result = 0;
    errno = 0;
    struct dirent *entry;
    while ((entry = readdir(directory)) != NULL) {
        if (strcmp(entry->d_name, ".") != 0 && strcmp(entry->d_name, "..") != 0) {
            result = KelivoISHMountTargetOccupied;
            break;
        }
    }
    if (result == 0 && errno != 0) result = -errno;
    closedir(directory);
    return result;
}
