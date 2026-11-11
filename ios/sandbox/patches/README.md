# iSH patches (Kelivo)

Applied by `build_ish.sh` after the checkout is pinned to `ISH_SHA`
(`0fd17a135e78b7a0cf08a4f5831217bbb76ed22f`, Chevey339/ish-arm64).

The pin follows [`OpenMinis/OpenMinis` main's `deps/ish` submodule](https://github.com/OpenMinis/OpenMinis/tree/main/deps).
Future upgrades should use the revision adopted there and keep an explicit SHA
in `build_ish.sh` so local and CI builds use the same source.

This revision matches OpenMinis/OpenMinis main at
[`1a71df0f381c`](https://github.com/OpenMinis/OpenMinis/tree/1a71df0f381cefde80bf912b723de6f9831bc177/deps).
It includes the scalar FMOV immediate fix and `tests/regress/regress_fmov_imm.{c,S}`.
Native JIT remains explicitly disabled in Kelivo's builds.

`KelivoISHKernel` feeds the new memory governor at boot, before commands, and
every 250 ms using the app's physical footprint and available memory. This
keeps V8's committed address space from exhausting the fixed page ledger
before JavaScript starts. The simulator uses the macOS CLI's host RAM budget;
devices use their live app memory allowance and OS memory-pressure events.
Pressure transitions are retained until the OS reports a new state. An
allocation encountering an expired sample synchronously requests a fresh one,
so existing guests can resume after suspension before the timer runs. Failed
samples and critical pressure still refuse allocations.

The former `0001` interruptible-nanosleep patch is now covered upstream.
Upstream also removed the futex idle-exit heuristic, so `0003` only needs to
exempt host-managed services from the remaining poll heuristic.

- `0002-fs-fake-bind-stat-device.patch` — static bind mounts return the same
  device number from `stat` and `fstat`, so GNU `cp` can copy files in
  `/workspace` without reporting that the source was replaced while copying.
  The upstream pin fixes hook-routed mounts but leaves static mounts affected.
- `0003-kernel-host-managed-lifetime.patch` — persistent STDIO services and
  their children are exempt from the poll (60s) idle-exit heuristic.
  The host still cancels them explicitly with signals.
- `0004-kernel-node-random-seed.patch` — randomize Node's seed per exec in
  explicit `jitless` mode, so `--predictable` does not make concurrent npm
  processes reuse cache temporary filenames. Explicit seeds remain respected;
  the default mode uses Node's normal entropy. Always preload the guarded
  WebAssembly shim so `NODE_OPTIONS=--jitless` also works; the shim does nothing
  when native WebAssembly is available.
- `0005-kernel-init-exit-status.patch` — the host iSH CLI returns the guest
  command's exit status after shutdown, so failed apk transactions and build
  validation cannot silently succeed.
- `0006-kernel-uname-hostname-bounds.patch` — bound the host name copied into
  Linux's 65-byte uname field and preserve its NUL terminator. Long macOS runner
  names otherwise abort the host iSH CLI while preparing the Alpine rootfs.
- `0008-kernel-memory-refresh-hook.patch` — let the host synchronously refresh
  expired memory data at the allocation boundary after process suspension.
  Allocation still fails when the refreshed sample is stale or under pressure.
  State publication and lazy-commit refusals do not enter the guest log,
  since callers can already hold its lock while copying into guest memory.

## Rootfs compatibility overlay

`RootfsPatch.bundle` is copied unchanged from the same pinned iSH source by
`build_ish.sh` and bundled as an iOS resource. It is separate from these kernel
patches. On every cold boot, `KelivoISHKernel` applies its manifest through the
guest VFS before launching processes, including in existing environments.
Kelivo's own `overlay/` is applied afterward. No environment reset is required.

The bundle provides `/lib/wasm-polyfill.js` and `/lib/fetch-polyfill.js`.
Both scripts are preloaded. Node's default mode keeps native guest WebAssembly;
the guarded shim activates only when WebAssembly is unavailable, including
with `ISH_NODE_MODE=jitless`, `node --jitless`, or `NODE_OPTIONS=--jitless`.
It implements undici's llhttp HTTP parser in JavaScript and is not a general
WebAssembly engine or a browser.
Run the opt-in `MCP_STDIO_NODE_SMOKE` checks in
`integration_test/workspace/mcp_stdio_ios_test.dart` on a prepared, disposable
simulator (or use `--no-uninstall` to preserve an existing app's data).

## Rootfs packages

Rootfs generation runs apk through the host iSH CLI on an Apple Silicon Mac.
apk preserves the official minirootfs world and owns package installation,
including dependency resolution, file ownership records and install scripts.
The shared `overlay/usr/local/bin/kelivo-repair-rootfs` transaction also repairs
installed environments in place when the user selects Update or Repair.
The app publishes the new rootfs version only after that transaction succeeds.

After generating artifacts, run
`flutter test test/core/services/sandbox/ios_rootfs_artifact_test.dart`.
The disposable-simulator regression is
`integration_test/workspace/ios_rootfs_packages_test.dart`.
