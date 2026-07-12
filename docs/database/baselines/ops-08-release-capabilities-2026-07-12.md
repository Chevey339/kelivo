# OPS-08 database v2 release capability evidence

Date: 2026-07-12

Runner: `integration_test/database_v2_release_capabilities_test.dart`

The runner performs a real platform secure-store write/read/overwrite/delete
round trip and verifies that the build declares the current database schema as
v2-readable while forbidding down migration and a Hive writer. It prints one
machine-readable `OPS08_RELEASE_CAPABILITY_RESULT` line.

## Recorded result

| Platform | Result | Evidence |
| --- | --- | --- |
| Android | pending | Run on a physical device or emulator; do not infer from macOS |
| iOS | PASS | iOS 26.5 simulator; secure-store round trip `true`; schema `8`; rollback-compatible `true`; storage contract `2` |
| macOS | PASS | macOS 26.5.2; secure-store round trip `true`; schema `8`; rollback-compatible `true`; storage contract `2` |
| Windows | pending | Run on the native Windows runner; do not infer from macOS |
| Linux | pending | Run with the desktop secret service available; do not infer from macOS |

Recorded macOS line:

```text
OPS08_RELEASE_CAPABILITY_RESULT:{"platform":"macOS","operatingSystem":"macos","operatingSystemVersion":"Version 26.5.2 (Build 25F84)","secureStorageWriteReadOverwriteDelete":true,"databaseSchemaVersion":8,"rollbackCompatible":true,"storageContractVersion":2}
```

Recorded iOS simulator line:

```text
OPS08_RELEASE_CAPABILITY_RESULT:{"platform":"iOS","operatingSystem":"ios","operatingSystemVersion":"Version 26.5 (Build 23F77)","secureStorageWriteReadOverwriteDelete":true,"databaseSchemaVersion":8,"rollbackCompatible":true,"storageContractVersion":2}
```

The first macOS run correctly failed with Keychain error `-34018` because an
unsigned development app cannot use the data-protection Keychain without a
provisioned entitlement. The production credential adapter now falls back on
macOS only to the user's platform login Keychain via `/usr/bin/security`; the
secret is base64-wrapped and supplied on stdin, never in process arguments,
preferences, diagnostics, or logs. The same runner then passed. This fallback
does not apply to other platforms.

## Commands for the remaining platforms

List the device identifier first:

```sh
flutter devices
```

Then run:

```sh
flutter test integration_test/database_v2_release_capabilities_test.dart -d <device-id>
```

Archive the complete machine-readable result line. A successful build alone is
not evidence: the test must reach `All tests passed` after the secure-store
round trip.

## Rollback build contract

- storage contract version: `2`
- readable schema range: `8..8`
- down migration: forbidden
- Hive writer: forbidden
- rollback is a code rollback that retains the database v2 kernel and data
  operations, not a data rollback to the retained Hive files

Any release that raises the schema above `8` must first publish a new
v2-compatible rollback build and update this runner's compatibility window.
