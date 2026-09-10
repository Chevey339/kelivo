# iSH patches (Kelivo)

Applied by `build_ish.sh` after the checkout is pinned to `ISH_SHA`
(`3f6384c70eefd1a370f121d3492a5f21f7767df9`, Chevey339/ish-arm64).

The pin follows [`OpenMinis/OpenMinis` main's `deps/ish` submodule](https://github.com/OpenMinis/OpenMinis/tree/main/deps).
Future upgrades should use the revision adopted there and keep an explicit SHA
in `build_ish.sh` so local and CI builds use the same source.

- `0001-kernel-time-interruptible-nanosleep.patch` — guest `nanosleep` /
  `clock_nanosleep` wait on iSH’s interruptible `wait_for` so a killed
  `sleep` returns. Required for shell timeout and cancel.
- `0002-fs-fake-bind-stat-device.patch` — static bind mounts return the same
  device number from `stat` and `fstat`, so GNU `cp` can copy files in
  `/workspace` without reporting that the source was replaced while copying.
  The upstream pin fixes hook-routed mounts but leaves static mounts affected.
- `0003-kernel-host-managed-lifetime.patch` — persistent STDIO services and
  their children are exempt from the poll (60s) and futex (180s) idle-exit
  heuristics. The host still cancels them explicitly with signals.
- `0004-kernel-node-random-seed.patch` — keep Node's emulation flags but
  randomize its seed per exec, so `--predictable` does not make concurrent npm
  processes reuse cache temporary filenames. Explicit seeds remain respected.

## Rootfs compatibility overlay

`RootfsPatch.bundle` is copied unchanged from the same pinned iSH source by
`build_ish.sh` and bundled as an iOS resource. It is separate from these kernel
patches. On every cold boot, `KelivoISHKernel` applies its manifest through the
guest VFS before launching processes, including in existing environments.
Kelivo's own `overlay/` is applied afterward. No environment reset is required.

The bundle provides `/lib/wasm-polyfill.js` and `/lib/fetch-polyfill.js`, which
iSH's Node exec path preloads. The WebAssembly shim implements undici's llhttp
HTTP parser in JavaScript; it is not a general WebAssembly engine or a browser.
Run the opt-in `MCP_STDIO_NODE_SMOKE` checks in
`integration_test/workspace/mcp_stdio_ios_test.dart` on a prepared, disposable
simulator (or use `--no-uninstall` to preserve an existing app's data).
