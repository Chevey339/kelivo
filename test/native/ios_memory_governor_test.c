#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "kernel/mm.h"
// Use the real logging implementation so the regression can hold its private
// lock, just as sys_syslog does while copying into guest memory.
#include "kernel/log.c"

static int refresh_count;
static bool refresh_succeeds;
static bool critical;

static void refresh_memory(void) {
    refresh_count++;
    if (refresh_succeeds)
        ish_set_memory_status(10000, 8000, critical);
}

int main(void) {
    ish_set_memory_refresh_hook(refresh_memory);
    ish_set_memory_status(1000, 800, false);
    assert(ish_mem_commit_ok(500));
    assert(refresh_count == 0);

    // Model an existing guest resuming before its host's periodic timer.
    // A failed synchronous refresh must still reject the expired sample.
    usleep(2100000);
    assert(!ish_mem_commit_ok(500));
    assert(refresh_count == 1);

    // Re-read the allowance after refresh, not the old smaller limit.
    refresh_succeeds = true;
    assert(ish_mem_commit_ok(2000));
    assert(refresh_count == 2);
    assert(!ish_mem_commit_ok(10001));
    assert(refresh_count == 2);

    // A successful refresh must not turn OS critical pressure into a grant.
    critical = true;
    usleep(2100000);
    alarm(10);
    lock(&log_lock);
    assert(!ish_mem_commit_ok(500));
    unlock(&log_lock);
    alarm(0);
    assert(refresh_count == 3);
    assert(!ish_mem_commit_ok(500));
    assert(refresh_count == 3);

    // Host recovery releases the brake; missing samplers still fail closed.
    ish_set_memory_status(10000, 8000, false);
    assert(ish_mem_commit_ok(500));
    ish_set_memory_refresh_hook(NULL);
    usleep(2100000);
    assert(!ish_mem_commit_ok(500));
    assert(refresh_count == 3);

    // Exercise the full syscall copy path, not just admission: sys_syslog
    // holds log_lock while user_write faults into an uncommitted reservation.
    current = calloc(1, sizeof(*current));
    assert(current != NULL);
    current->pid = 17;
    current->mm = mm_new();
    assert(current->mm != NULL);
    current->mem = &current->mm->mem;
    const addr_t destination = 0x100000000ULL;
    write_wrlock(&current->mem->lock);
    assert(pt_map_lazy(current->mem, PAGE(destination), 4, P_READ | P_WRITE) == 0);
    write_wrunlock(&current->mem->lock);
    ish_printk("memory governor syscall regression\n");
    ish_set_memory_status(10000, 8000, false);
    ish_set_memory_refresh_hook(refresh_memory);
    usleep(2100000);
    alarm(10);
    assert(sys_syslog(SYSLOG_ACTION_READ_ALL_, destination, 64) == _EFAULT);
    alarm(0);
    assert(refresh_count == 4);

    critical = false;
    ish_set_memory_status(1ULL << 30, 1ULL << 29, false);
    alarm(10);
    int copied = sys_syslog(SYSLOG_ACTION_READ_ALL_, destination, 64);
    alarm(0);
    assert(copied > 0 && copied < 64);
    char output[64] = {0};
    assert(user_read(destination, output, copied) == 0);
    assert(strstr(output, "memory governor syscall regression") != NULL);
    struct mm *mm = current->mm;
    current->mm = NULL;
    current->mem = NULL;
    mm_release(mm);
    free(current);
    current = NULL;
    puts("memory governor: stale refresh, limits and critical pressure passed");
    return 0;
}
