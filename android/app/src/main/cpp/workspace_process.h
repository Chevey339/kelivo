#pragma once

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <signal.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <unistd.h>

static bool reset_workspace_signal_mask() {
    sigset_t empty;
    return sigemptyset(&empty) == 0 && sigprocmask(SIG_SETMASK, &empty, nullptr) == 0;
}

// Use raw syscalls and a stack buffer after fork: libc directory allocation and
// Android FD ownership hooks can still refer to locks/state in the parent.
static bool close_inherited_workspace_fds() {
    const int directory = open("/proc/self/fd", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (directory < 0) return false;
    struct LinuxDirent64 {
        uint64_t inode;
        int64_t offset;
        unsigned short length;
        unsigned char type;
        char name[];
    };
    alignas(LinuxDirent64) char buffer[4096];
    for (;;) {
        const long count = syscall(SYS_getdents64, directory, buffer, sizeof(buffer));
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) {
            syscall(SYS_close, directory);
            return count == 0;
        }
        for (long offset = 0; offset < count;) {
            const auto *entry = reinterpret_cast<const LinuxDirent64 *>(buffer + offset);
            const int fd = atoi(entry->name);
            if (fd > STDERR_FILENO && fd != directory) syscall(SYS_close, fd);
            offset += entry->length;
        }
    }
}
