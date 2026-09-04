//
//  KelivoISHCrashGuards.c
//  Runner
//
//  Adapted from Cuplivo/OpenMinis embedded-iSH crash containment (GPL-3.0;
//  see ios/sandbox/NOTICE). A guest crash must take down at most the guest
//  task thread, never the whole Flutter app.
//

#define _XOPEN_SOURCE 700

#include "KelivoISHCrashGuards.h"

#include <stdarg.h>
#include <stdint.h>

#include "ish/debug.h"
#include "ish/cpu-offsets.h"

#include <execinfo.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <sys/select.h>
#include <ucontext.h>
#include <unistd.h>

extern __thread volatile sig_atomic_t in_jit;
#ifdef GUEST_ARM64
extern __thread volatile uint64_t jit_saved_pc;
#else
extern __thread volatile uint32_t jit_saved_pc;
#endif
extern __thread int ish_thread_marker;

#ifdef GUEST_ARM64
extern void jit_crash_trampoline(void);
#endif

static void park_thread_forever(void) {
    sigset_t all;
    sigfillset(&all);
    pthread_sigmask(SIG_BLOCK, &all, NULL);
    for (;;) {
        select(0, NULL, NULL, NULL, NULL);
    }
}

static void kelivo_jit_crash_handler(int sig, siginfo_t *info, void *ctx) {
#if defined(__aarch64__) && defined(GUEST_ARM64)
    if ((sig == SIGSEGV || sig == SIGBUS) && in_jit) {
        ucontext_t *uc = (ucontext_t *)ctx;
        uint64_t cpu_ptr = uc->uc_mcontext->__ss.__x[1];
        uint64_t x7 = uc->uc_mcontext->__ss.__x[7];
        uint64_t x10 = uc->uc_mcontext->__ss.__x[10];
        uint64_t guest_addr = (x7 - x10) & 0xffffffffffffULL;
        uint64_t esr = uc->uc_mcontext->__es.__esr;
        int was_write = (esr & 0x40) != 0;

        *(uint64_t *)(cpu_ptr + CPU_segfault_addr) = guest_addr;
        *(int *)(cpu_ptr + CPU_segfault_was_write) = was_write;
        *(uint64_t *)(cpu_ptr + CPU_pc) = (uint64_t)jit_saved_pc;

        uint64_t exit_sp = *(uint64_t *)(cpu_ptr + LOCAL_jit_exit_sp);
        uc->uc_mcontext->__ss.__sp = exit_sp;
        uc->uc_mcontext->__ss.__pc = (uint64_t)jit_crash_trampoline;

        sigset_t unblock;
        sigemptyset(&unblock);
        sigaddset(&unblock, sig);
        sigprocmask(SIG_UNBLOCK, &unblock, NULL);
        return;
    }
#endif

    if (!ish_thread_marker) {
        struct sigaction sa_default = {0};
        sa_default.sa_handler = SIG_DFL;
        sigaction(sig, &sa_default, NULL);
        raise(sig);
        return;
    }

    char buf[512];
    int len = snprintf(buf, sizeof(buf),
                       "\n=== iSH guest crash: signal %d ===\nfault addr: %p\n",
                       sig, info->si_addr);
    if (len > 0) write(STDERR_FILENO, buf, (size_t)len);
    void *bt[20];
    int n = backtrace(bt, 20);
    backtrace_symbols_fd(bt, n, STDERR_FILENO);
    park_thread_forever();
}

void KelivoISHInstallCrashGuards(void) {
    static char altstack[SIGSTKSZ];
    stack_t ss = {.ss_sp = altstack, .ss_size = SIGSTKSZ};
    sigaltstack(&ss, NULL);

    struct sigaction sa = {0};
    sa.sa_sigaction = kelivo_jit_crash_handler;
    sa.sa_flags = SA_SIGINFO | SA_ONSTACK;
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGILL, &sa, NULL);
    sigaction(SIGTRAP, &sa, NULL);
}

static void kelivo_die_handler(const char *msg) {
    char buf[4096];
    int len = snprintf(buf, sizeof(buf), "\n=== iSH fatal: %s ===\n", msg);
    if (len > 0) write(STDERR_FILENO, buf, (size_t)len);
    park_thread_forever();
}

void KelivoISHInstallDieGuard(void) {
    die_handler = kelivo_die_handler;
}
