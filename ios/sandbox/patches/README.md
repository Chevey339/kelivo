# iSH patches (Kelivo)

Applied by `build_ish.sh` after the checkout is pinned to `ISH_SHA`
(`de124dd66124a15239cea1465164f74980ada245`, OpenMinis/ish-arm64).

- `0001-kernel-time-interruptible-nanosleep.patch` — guest `nanosleep` /
  `clock_nanosleep` wait on iSH’s interruptible `wait_for` so a killed
  `sleep` returns. Required for shell timeout and cancel.
