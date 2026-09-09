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
