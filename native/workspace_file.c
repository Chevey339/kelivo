// Access checks and permission copying use the host SDK's types and flags.
// All calls run on the editor's file I/O isolate.
#include <stdint.h>

#ifdef _WIN32
#include <windows.h>
#include <aclapi.h>
#include <sddl.h>
#define EXPORT __declspec(dllexport)

// The caller owns the backup and restores it on partial failure.
EXPORT int workspace_replace_document(const wchar_t* target, const wchar_t* staged,
                                      const wchar_t* backup) {
  return ReplaceFileW(target, staged, backup, 0, NULL, NULL) ? 0 : GetLastError();
}

static DWORD volume_permissions(HANDLE handle, int* has_acls) {
  DWORD flags;
  if (!GetVolumeInformationByHandleW(handle, NULL, 0, NULL, NULL, &flags, NULL, 0)) {
    return GetLastError();
  }
  *has_acls = (flags & FILE_PERSISTENT_ACLS) != 0;
  return ERROR_SUCCESS;
}

// An atomic replacement is a new file. Only advertise editing if its token
// can retain the document owner on the replacement.
static int can_keep_owner(HANDLE file) {
  PSECURITY_DESCRIPTOR descriptor = NULL;
  PSID owner = NULL;
  if (GetSecurityInfo(file, SE_FILE_OBJECT, OWNER_SECURITY_INFORMATION, &owner, NULL, NULL,
                      NULL, &descriptor) != ERROR_SUCCESS)
    return 0;
  HANDLE token;
  int matches = 0;
  if (OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) {
    DWORD size = 0;
    GetTokenInformation(token, TokenOwner, NULL, 0, &size);
    TOKEN_OWNER* current = LocalAlloc(LMEM_FIXED, size);
    if (current && GetTokenInformation(token, TokenOwner, current, size, &size)) {
      matches = EqualSid(owner, current->Owner);
    }
    LocalFree(current);
    CloseHandle(token);
  }
  LocalFree(descriptor);
  return matches;
}

EXPORT int workspace_can_edit(const wchar_t* path, const wchar_t* parent) {
  const DWORD share = FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE;
  HANDLE file = CreateFileW(path, GENERIC_READ | FILE_WRITE_DATA | DELETE | SYNCHRONIZE, share,
                            NULL, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL);
  if (file == INVALID_HANDLE_VALUE) return 0;
  int has_acls = 0;
  int allowed = volume_permissions(file, &has_acls) == 0 && (!has_acls || can_keep_owner(file));
  CloseHandle(file);
  if (!allowed) return 0;
  HANDLE dir = CreateFileW(parent, FILE_ADD_SUBDIRECTORY | FILE_ADD_FILE, share, NULL,
                           OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
  if (dir == INVALID_HANDLE_VALUE) return 0;
  CloseHandle(dir);
  return 1;
}

EXPORT int workspace_set_permissions(const wchar_t* path, const wchar_t* source,
                                     uint32_t mode) {
  (void)mode;
  HANDLE staged = CreateFileW(path, FILE_READ_ATTRIBUTES,
                              FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
                              OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
  if (staged == INVALID_HANDLE_VALUE) return GetLastError();
  int has_acls = 0;
  DWORD volume_error = volume_permissions(staged, &has_acls);
  CloseHandle(staged);
  if (volume_error || !has_acls) return volume_error;
  PSECURITY_DESCRIPTOR security = NULL;
  SECURITY_INFORMATION info = DACL_SECURITY_INFORMATION;
  if (source == NULL) {
    // The staging directory and any children are accessible to their owner.
    if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(
            L"D:P(A;OICI;FA;;;OW)", SDDL_REVISION_1, &security, NULL)) {
      return GetLastError();
    }
    info |= PROTECTED_DACL_SECURITY_INFORMATION;
  } else {
    info |= OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION;
    DWORD size = 0;
    GetFileSecurityW(source, info, NULL, 0, &size);
    if (size == 0) return GetLastError();
    security = LocalAlloc(LMEM_FIXED, size);
    if (!security) return ERROR_OUTOFMEMORY;
    if (!GetFileSecurityW(source, info, security, size, &size)) {
      DWORD error = GetLastError();
      LocalFree(security);
      return error;
    }
    SECURITY_DESCRIPTOR_CONTROL control;
    DWORD revision;
    if (!GetSecurityDescriptorControl(security, &control, &revision)) {
      DWORD error = GetLastError();
      LocalFree(security);
      return error;
    }
    // The staging directory is private. Apply exactly the source DACL there;
    // ReplaceFileW preserves the destination's inheritance when publishing.
    if (control & SE_DACL_PROTECTED) info |= PROTECTED_DACL_SECURITY_INFORMATION;
  }
  DWORD error = SetFileSecurityW(path, info, security) ? 0 : GetLastError();
  LocalFree(security);
  return error;
}
#else
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#define EXPORT __attribute__((visibility("default"), used))

#ifdef __APPLE__
#include <copyfile.h>
#include <sys/acl.h>
#else
#include <sys/xattr.h>
#endif
#ifdef __ANDROID__
#include <string.h>
#include <sys/vfs.h>
static int android_shared_volume(const char* path) {
  struct statfs fs;
  if (strncmp(path, "/storage/", 9) != 0 || statfs(path, &fs) < 0) return 0;
  return fs.f_type == 0x65735546 /* FUSE */ || fs.f_type == 0x5dca2df5 /* sdcardfs */;
}
#endif

static int can_keep_ownership(const struct stat* original) {
  if (geteuid() == 0) return 1;
  if (original->st_uid != geteuid()) return 0;
  if (original->st_gid == getegid()) return 1;
  int count = getgroups(0, NULL);
  if (count <= 0) return 0;
  gid_t* groups = malloc(sizeof(gid_t) * (size_t)count);
  if (!groups) return 0;
  count = getgroups(count, groups);
  int found = 0;
  for (int i = 0; i < count; ++i) {
    if (groups[i] == original->st_gid) found = 1;
  }
  free(groups);
  return found;
}

EXPORT int workspace_can_edit(const char* path, const char* parent) {
  int fd = open(path, O_WRONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
  if (fd < 0) return 0;
  struct stat original;
  int allowed = fstat(fd, &original) == 0 && S_ISREG(original.st_mode);
#ifdef __ANDROID__
  if (allowed && !android_shared_volume(path))
#else
  if (allowed)
#endif
    allowed = can_keep_ownership(&original);
  close(fd);
  return allowed && access(parent, W_OK | X_OK) == 0;
}

// Shared Android volumes can reject renameat2(RENAME_NOREPLACE). Keep the
// exclusive destination handle for the entire write, including the flush.
EXPORT int workspace_copy_exclusive(const char* source, const char* target) {
  int input = open(source, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
  if (input < 0) return errno;
  struct stat original;
  if (fstat(input, &original) < 0) {
    int error = errno;
    close(input);
    return error;
  }
  int output = open(target, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, original.st_mode & 0777);
  if (output < 0) {
    int error = errno;
    close(input);
    return error;
  }
  int error = 0;
  char buffer[16384];
  while (!error) {
    ssize_t count = read(input, buffer, sizeof(buffer));
    if (count == 0) break;
    if (count < 0) {
      if (errno == EINTR) continue;
      error = errno;
      break;
    }
    for (ssize_t offset = 0; offset < count;) {
      ssize_t n = write(output, buffer + offset, (size_t)(count - offset));
      if (n < 0 && errno == EINTR) continue;
      if (n <= 0) {
        error = n < 0 ? errno : EIO;
        break;
      }
      offset += n;
    }
  }
  if (!error && fsync(output) < 0) error = errno;
  struct stat created;
  int have_identity = fstat(output, &created) == 0;
  if (close(output) < 0 && !error) error = errno;
  close(input);
  if (error && have_identity) {
    struct stat named;
    if (lstat(target, &named) == 0 && created.st_dev == named.st_dev &&
        created.st_ino == named.st_ino)
      unlink(target);
  }
  return error;
}

static int set_acl(const char* path, const char* source) {
#ifdef __APPLE__
  if (source) {
    // Keep Finder tags, resource forks and quarantine along with the ACL.
    return copyfile(source, path, NULL, COPYFILE_ACL | COPYFILE_XATTR | COPYFILE_NOFOLLOW) == 0
               ? 0
               : errno;
  }
  acl_t empty = acl_init(0);
  if (!empty) return errno;
  int error = acl_set_file(path, ACL_TYPE_EXTENDED, empty) == 0 ? 0 : errno;
  acl_free(empty);
  return error == ENOTSUP ? 0 : error;
#else
  const char* name = "system.posix_acl_access";
  ssize_t length = source ? getxattr(source, name, NULL, 0) : 0;
  if (length < 0 && errno != ENODATA && errno != ENOTSUP) return errno;
  if (length <= 0) {
    if (getxattr(path, name, NULL, 0) < 0) {
      return errno == ENODATA || errno == ENOTSUP ? 0 : errno;
    }
    if (removexattr(path, name) == 0 || errno == ENODATA || errno == ENOTSUP) {
      return 0;
    }
    return errno;
  }
  void* acl = malloc((size_t)length);
  if (!acl) return ENOMEM;
  ssize_t bytes = getxattr(source, name, acl, (size_t)length);
  int error = 0;
  if (bytes < 0 || setxattr(path, name, acl, (size_t)bytes, 0) < 0) error = errno;
  free(acl);
  return error;
#endif
}

EXPORT int workspace_set_permissions(const char* path, const char* source, uint32_t mode) {
#ifdef __ANDROID__
  // MediaProvider assigns ownership and access on its shared-storage mounts.
  // Apps cannot set per-file POSIX permissions or ACLs on those volumes.
  if (android_shared_volume(path)) return 0;
#endif
  struct stat staged;
  if (lstat(path, &staged) < 0) return errno;
  if (source) {
    struct stat original;
    if (lstat(source, &original) < 0) return errno;
    if (!S_ISREG(original.st_mode) || !S_ISREG(staged.st_mode)) return EINVAL;
    if (staged.st_uid != original.st_uid || staged.st_gid != original.st_gid) {
      if (chown(path, original.st_uid, original.st_gid) < 0) return errno;
    }
    mode = original.st_mode & 0777;
  }
  int error = set_acl(path, source);
  if (error != 0) return error;
  if ((staged.st_mode & 07777) != mode && chmod(path, mode) < 0) return errno;
  return 0;
}
#endif
