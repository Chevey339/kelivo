#include "KelivoISHStdin.h"
#include <assert.h>
#include <signal.h>
#include <string.h>
#include <sys/stat.h>

int main(void) {
    int ends[2];
    assert(KelivoISHCreateStdinPipe(ends) == 0);
    struct stat info;
    assert(fstat(ends[0], &info) == 0 && S_ISFIFO(info.st_mode));
    assert((fcntl(ends[0], F_GETFL) & O_ACCMODE) == O_RDONLY);
    assert((fcntl(ends[1], F_GETFL) & O_ACCMODE) == O_WRONLY);

    // Buffer initialize before the child starts reading. A launcher can
    // duplicate stdin while preparing its child without consuming the data.
    const char message[] = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\"}\n";
    assert(write(ends[1], message, sizeof(message)) == sizeof(message));
    int inherited = dup(ends[0]);
    assert(inherited >= 0);
    close(ends[0]);
    char buffer[sizeof(message)];
    assert(read(inherited, buffer, sizeof(buffer)) == sizeof(message));
    assert(memcmp(buffer, message, sizeof(message)) == 0);

    // Backpressure must return EAGAIN, so cancellation can interrupt writers.
    char chunk[4096] = {0};
    ssize_t written;
    do {
        written = write(ends[1], chunk, sizeof(chunk));
    } while (written >= 0);
    assert(errno == EAGAIN || errno == EWOULDBLOCK);

    // A child exiting during a write must not kill the host with SIGPIPE.
    signal(SIGPIPE, SIG_DFL);
    close(inherited);
    assert(write(ends[1], message, sizeof(message)) == -1 && errno == EPIPE);
    close(ends[1]);
    return 0;
}
