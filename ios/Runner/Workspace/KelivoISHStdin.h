#pragma once

#include <errno.h>
#include <fcntl.h>
#include <unistd.h>

// Match the guest's FIFO/read-only stdin with a real unidirectional pipe.
// In particular, do not substitute an O_RDWR socketpair: launchers such as uv
// can behave differently when input is already buffered on that descriptor.
static inline int KelivoISHCreateStdinPipe(int ends[2]) {
    if (pipe(ends) < 0) return -1;
    // Scope broken-pipe protection to this fd, not the app's signal handlers.
    if (fcntl(ends[1], F_SETNOSIGPIPE, 1) < 0 ||
        fcntl(ends[1], F_SETFL, O_NONBLOCK) < 0) {
        int saved = errno;
        close(ends[0]);
        close(ends[1]);
        ends[0] = ends[1] = -1;
        errno = saved;
        return -1;
    }
    return 0;
}
