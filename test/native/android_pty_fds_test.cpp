// Build with the Android NDK and run through adb on an emulator/device.
#include "../../android/app/src/main/cpp/workspace_process.h"
#include <assert.h>
#include <poll.h>
#include <sys/wait.h>

int main() {
    sigset_t blocked, original;
    sigemptyset(&blocked);
    sigaddset(&blocked, SIGQUIT);
    assert(sigprocmask(SIG_BLOCK, &blocked, &original) == 0);
    int mcp_pipe[2], gate[2];
    assert(pipe(mcp_pipe) == 0);
    assert(pipe(gate) == 0);
    const pid_t child = fork();
    assert(child >= 0);
    if (child == 0) {
        assert(reset_workspace_signal_mask());
        sigset_t current;
        assert(sigprocmask(SIG_SETMASK, nullptr, &current) == 0);
        assert(sigismember(&current, SIGQUIT) == 0);
        // Simulate a terminal forked while the app holds an MCP stdin writer.
        assert(dup2(gate[0], STDIN_FILENO) == STDIN_FILENO);
        assert(close_inherited_workspace_fds());
        assert(fcntl(mcp_pipe[1], F_GETFD) == -1 && errno == EBADF);
        for (int fd = 0; fd <= STDERR_FILENO; ++fd) assert(fcntl(fd, F_GETFD) >= 0);
        char value;
        assert(read(STDIN_FILENO, &value, 1) == 1);
        _exit(0);
    }
    assert(sigprocmask(SIG_SETMASK, &original, nullptr) == 0);
    close(mcp_pipe[1]);
    close(gate[0]);
    pollfd watch = {mcp_pipe[0], POLLIN | POLLHUP, 0};
    // EOF must arrive while the terminal is still alive, not only at its exit.
    assert(poll(&watch, 1, 2000) == 1);
    char value;
    assert(read(mcp_pipe[0], &value, 1) == 0);
    int status;
    assert(waitpid(child, &status, WNOHANG) == 0);
    assert(write(gate[1], "x", 1) == 1);
    assert(waitpid(child, &status, 0) == child);
    assert(WIFEXITED(status) && WEXITSTATUS(status) == 0);
    close(mcp_pipe[0]);
    close(gate[1]);
}
