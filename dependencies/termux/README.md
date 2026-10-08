# Pinned Android sandbox runtime

`proot-5.1.107.92.tar.xz` contains the 12 runtime libraries for ARMv7,
ARM64, and x86_64, extracted from these Termux packages:

- PRoot 5.1.107.92
- libtalloc 2.4.3
- libandroid-shmem 0.7

The archive is kept in the repository because Termux's rolling package pool
removes old versions. Android builds restore it with `tool/fetch_proot.sh`,
which verifies every file against `tool/proot_checksums.txt` before installing
any library. The archive preserves the previously pinned binaries byte for byte.

Source references and license notices are in
[`android/app/src/main/jniLibs/NOTICE`](../../android/app/src/main/jniLibs/NOTICE).

When updating the runtime, extract the new upstream packages for all three
architectures, replace this archive, and update the checksums and NOTICE
together. The archive contains regular files named `<abi>/<library>.so`.
