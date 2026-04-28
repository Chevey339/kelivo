# Kelivo iOS Local Terminal Technical Design

## 1. Objective

Implement an iOS local terminal for Kelivo by embedding a Linux guest runtime and exposing it to Flutter through a narrow native bridge. The Flutter layer owns product state, UI, installation flow, file management, and backup flow. The iOS native layer owns runtime process execution, terminal byte streams, and runtime-specific filesystem operations.

The first iOS implementation uses the OpenMinis iSH ARM64 direction as the runtime basis. The runtime is a Kelivo-managed local Linux environment inside the app sandbox, not an iOS host shell.

## 2. Design Principles

- Mobile first: optimize for iPhone and iPad terminal use.
- One runtime source of truth: installed runtime metadata decides the active runtime.
- Atomic activation: never replace a working runtime with an unverified one.
- Explicit failure: install, verification, unpack, and session errors must surface to the UI.
- Small Flutter-native bridge: pass structured commands and byte streams, not UI policy.
- Runtime isolation: terminal file operations stay inside terminal-owned directories.
- Downloadable resources: rootfs and large packages are downloaded after install.

## 3. Current Repository Fit

Relevant existing repository facts:

- App data directories are centralized in `lib/utils/app_directories.dart`.
- Mobile settings entry is `lib/features/settings/pages/settings_page.dart`.
- iOS native entry is `ios/Runner/AppDelegate.swift`.
- Existing native iOS method channels are already registered in `AppDelegate.swift`.
- Generated localization files must not be edited by hand.
- All user-visible strings must be added to all four ARB files during implementation.

The terminal feature should be added as a new feature module, not inside the chat feature.

## 4. Proposed File Layout

Flutter-side files:

```text
lib/features/terminal/
  pages/
    terminal_management_page.dart
    terminal_page.dart
    terminal_file_browser_page.dart
    terminal_backup_page.dart
  widgets/
    terminal_status_card.dart
    terminal_install_progress.dart
    terminal_shortcut_bar.dart
    terminal_file_row.dart
    terminal_danger_zone.dart
  models/
    terminal_runtime_state.dart
    terminal_runtime_manifest.dart
    terminal_runtime_metadata.dart
    terminal_session_state.dart
    terminal_file_entry.dart
  services/
    terminal_runtime_service.dart
    terminal_installer_service.dart
    terminal_file_service.dart
    terminal_backup_service.dart
    terminal_native_bridge.dart
  providers/
    terminal_provider.dart
```

Native iOS files:

```text
ios/Runner/Terminal/
  KelivoTerminalPlugin.swift
  KelivoTerminalRuntime.swift
  KelivoTerminalSession.swift
  KelivoTerminalInstaller.swift
  KelivoTerminalFileService.swift
  KelivoTerminalTypes.swift
```

Runtime resources:

```text
Application Support/
  terminal/
    manifests/
    runtimes/
      ios-alpine-arm64/
        current -> versions/<version>
        versions/
          <version>/
        staging/
    homes/
      default/
    cache/
      downloads/
      unpack/
    backups/
    logs/
```

Symlink support on iOS should be verified. If symlink behavior is unreliable in the app container, replace `current` with a metadata pointer file.

## 5. Runtime Architecture

### 5.1 Logical Components

```text
TerminalManagementPage
  -> TerminalProvider
    -> TerminalInstallerService
      -> TerminalNativeBridge
        -> KelivoTerminalPlugin
          -> KelivoTerminalInstaller
          -> KelivoTerminalRuntime

TerminalPage
  -> TerminalProvider
    -> TerminalNativeBridge
      -> EventChannel output stream
      -> MethodChannel input and resize commands

TerminalFileBrowserPage
  -> TerminalFileService
    -> TerminalNativeBridge
      -> KelivoTerminalFileService
```

### 5.2 Responsibility Split

Flutter responsibilities:

- Render UI.
- Hold user-visible state.
- Start installer actions.
- Persist non-secret terminal preferences.
- Show localized errors.
- Route terminal pages.
- Build backup archives.
- Validate user intent before destructive actions.

iOS native responsibilities:

- Initialize runtime engine.
- Start shell sessions.
- Stream terminal output.
- Accept terminal input.
- Resize terminal sessions.
- Stop sessions.
- Perform native file operations inside allowed roots.
- Return structured runtime errors.

## 6. Runtime Manifest

The runtime manifest controls downloadable runtime packages.

Manifest shape:

```json
{
  "schemaVersion": 1,
  "runtimeId": "ios-alpine-arm64",
  "version": "2026.04.0",
  "platform": "ios",
  "arch": "arm64",
  "displayName": "Kelivo Alpine Runtime",
  "package": {
    "url": "https://download.kelivo.app/terminal/ios-alpine-arm64-2026.04.0.tar.zst",
    "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "compressedBytes": 120000000,
    "unpackedBytes": 420000000,
    "format": "tar.zst"
  },
  "capabilities": {
    "shell": true,
    "python3": true,
    "node": false,
    "packageManager": false
  },
  "entry": {
    "shell": "/bin/sh",
    "home": "/home/kelivo",
    "workingDirectory": "/home/kelivo"
  }
}
```

Rules:

- `runtimeId`, `version`, `platform`, `arch`, `package.url`, and `package.sha256` are required.
- The installer rejects manifests with unsupported `schemaVersion`.
- The installer rejects manifests not matching platform `ios`.
- The installer rejects unsupported archive formats.
- Package hash is checked before unpacking.
- Required runtime entry files are checked after unpacking.

## 7. Runtime Metadata

Installed metadata is persisted after activation.

Metadata shape:

```json
{
  "runtimeId": "ios-alpine-arm64",
  "version": "2026.04.0",
  "installedAt": "2026-04-28T12:00:00Z",
  "manifestSha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "rootPath": "/var/mobile/Containers/Data/Application/APP-UUID/Library/Application Support/terminal/runtimes/ios-alpine-arm64/versions/2026.04.0",
  "homePath": "/var/mobile/Containers/Data/Application/APP-UUID/Library/Application Support/terminal/homes/default",
  "status": "installed"
}
```

The Flutter provider reads metadata through the native bridge at startup.

## 8. Flutter-Native Bridge

Use one MethodChannel for commands and one EventChannel for terminal/session events.

Suggested names:

- MethodChannel: `kelivo.terminal/ios`
- EventChannel: `kelivo.terminal/ios/events`

### 8.1 Method API

`getRuntimeStatus`

Input:

```json
{}
```

Output:

```json
{
  "status": "installed",
  "runtimeId": "ios-alpine-arm64",
  "version": "2026.04.0",
  "rootfsBytes": 420000000,
  "homeBytes": 1048576,
  "cacheBytes": 0,
  "lastError": null
}
```

`installRuntime`

Input:

```json
{
  "manifestUrl": "https://download.kelivo.app/terminal/ios-alpine-arm64/stable.json"
}
```

Output:

```json
{
  "installId": "uuid"
}
```

`cancelInstall`

Input:

```json
{
  "installId": "uuid"
}
```

Output:

```json
{
  "cancelled": true
}
```

`startSession`

Input:

```json
{
  "sessionId": "uuid",
  "cols": 80,
  "rows": 24,
  "cwd": "/home/kelivo",
  "env": {
    "TERM": "xterm-256color",
    "LANG": "en_US.UTF-8"
  }
}
```

Output:

```json
{
  "sessionId": "uuid",
  "started": true
}
```

`writeSession`

Input:

```json
{
  "sessionId": "uuid",
  "dataBase64": "bHMK"
}
```

Output:

```json
{
  "accepted": true
}
```

`resizeSession`

Input:

```json
{
  "sessionId": "uuid",
  "cols": 100,
  "rows": 32
}
```

Output:

```json
{
  "resized": true
}
```

`stopSession`

Input:

```json
{
  "sessionId": "uuid"
}
```

Output:

```json
{
  "stopped": true
}
```

`listFiles`

Input:

```json
{
  "path": "/home/kelivo"
}
```

Output:

```json
{
  "path": "/home/kelivo",
  "entries": [
    {
      "name": "script.py",
      "path": "/home/kelivo/script.py",
      "type": "file",
      "bytes": 1234,
      "modifiedAt": "2026-04-28T12:00:00Z"
    }
  ]
}
```

`resetRuntime`

Input:

```json
{
  "mode": "home"
}
```

Output:

```json
{
  "reset": true
}
```

### 8.2 Event API

Events are maps with a `type` field.

Install progress:

```json
{
  "type": "installProgress",
  "installId": "uuid",
  "step": "download",
  "receivedBytes": 1000,
  "totalBytes": 120000000
}
```

Session output:

```json
{
  "type": "sessionOutput",
  "sessionId": "uuid",
  "dataBase64": "a2VsaXZvCg=="
}
```

Session exit:

```json
{
  "type": "sessionExit",
  "sessionId": "uuid",
  "code": 0,
  "message": null
}
```

Error:

```json
{
  "type": "error",
  "code": "hash_mismatch",
  "message": "Runtime package verification failed.",
  "details": {
    "installId": "uuid"
  }
}
```

## 9. Installer Design

### 9.1 Install State Machine

```text
notInstalled
  -> fetchingManifest
  -> downloading
  -> verifying
  -> unpacking
  -> validating
  -> activating
  -> installed
```

Failure transition:

```text
fetchingManifest/downloading/verifying/unpacking/validating/activating
  -> failed
```

Repair transition:

```text
installed
  -> repairRequired
```

### 9.2 Install Algorithm

1. Fetch manifest.
2. Validate manifest schema and platform.
3. Create install ID.
4. Download archive to `terminal/cache/downloads/<installId>.package`.
5. Verify SHA256.
6. Unpack into `terminal/runtimes/<runtimeId>/staging/<installId>`.
7. Validate required runtime files.
8. Ensure home directory exists.
9. Write runtime metadata into staging.
10. Activate by moving staging to `versions/<version>`.
11. Update active runtime pointer.
12. Clear install cache for this install.
13. Emit installed state.

Activation must be atomic at the metadata level. If moving directories cannot be guaranteed atomic across all cases, write a new active metadata file only after the target directory is fully valid.

### 9.3 Startup Cleanup

On app startup or first terminal service initialization:

- Remove stale staging directories older than one day.
- Keep active runtime untouched.
- Keep failed download files only if resume support is implemented.
- Clear session records from previous launches.

## 10. Native Runtime Integration

### 10.1 iSH ARM64 Direction

Use OpenMinis iSH ARM64 as the first runtime investigation target. It provides the closest match to the desired iOS local Linux runtime direction.

The native integration layer must isolate upstream runtime code behind `KelivoTerminalRuntime`. Flutter and app UI must not depend on upstream runtime internals.

### 10.2 Shell Start

The native layer starts the runtime with:

- Rootfs path.
- Home mount path.
- Working directory.
- Environment variables.
- Terminal size.

Default environment:

```text
TERM=xterm-256color
HOME=/home/kelivo
USER=kelivo
SHELL=/bin/sh
LANG=en_US.UTF-8
```

### 10.3 PTY Semantics

The Flutter terminal widget expects byte stream behavior equivalent to a PTY:

- Input bytes are written to session stdin.
- Output bytes are emitted as terminal output.
- Resize events update rows and columns.
- Exit event is emitted exactly once per session.

If the selected iSH runtime does not expose a PTY-like interface directly, `KelivoTerminalSession` must adapt its console IO into the same contract.

## 11. File System Boundary

Allowed virtual roots:

- `/home/kelivo`
- `/tmp`
- Runtime-visible user workspace directories explicitly mounted by Kelivo later.

Allowed physical roots:

- `Application Support/terminal/homes/default`
- selected runtime writable directories required by the guest runtime
- `Application Support/terminal/backups`
- `Application Support/terminal/cache` for installer-owned operations only

Path rules:

- Normalize all paths before access.
- Reject `..` traversal outside allowed roots.
- Reject absolute physical paths from Flutter.
- Prefer virtual runtime paths in Flutter models.
- Translate virtual paths to physical paths in native or service layer.

## 12. Backup Design

Backup archive format:

```text
kelivo-terminal-ios-backup.zip
  manifest.json
  home/
    README.txt
    scripts/
      hello.py
  settings/
    terminal_preferences.json
```

Backup manifest:

```json
{
  "schemaVersion": 1,
  "platform": "ios",
  "createdAt": "2026-04-28T12:00:00Z",
  "runtime": {
    "runtimeId": "ios-alpine-arm64",
    "version": "2026.04.0"
  },
  "contents": {
    "home": true,
    "settings": true,
    "rootfs": false,
    "cache": false
  }
}
```

Restore algorithm:

1. Stop active terminal sessions.
2. Read backup manifest.
3. Validate schema and platform.
4. Validate archive paths to block zip-slip traversal.
5. Extract into temporary restore directory.
6. Move current home to a rollback directory.
7. Move restored home into place.
8. Validate restored home can be listed.
9. Delete rollback directory after success.
10. Restore rollback directory if validation fails.

## 13. Terminal UI Technical Notes

Recommended terminal renderer:

- Use a Flutter terminal emulator package such as `xterm.dart` after dependency evaluation.

Output handling:

- Native output events append to terminal controller.
- Avoid `setState` per output chunk for the whole page.
- Keep terminal controller isolated from management provider state.

Keyboard shortcut row:

- Shortcut buttons send bytes or control sequences to the terminal controller.
- `Ctrl` acts as a sticky modifier for the next key where practical.
- Arrow keys send ANSI escape sequences.

Resize:

- Calculate rows and columns from terminal viewport and font metrics.
- Debounce resize events.
- Send resize to native only when rows or columns changed.

## 14. Error Model

Use stable error codes across Flutter and native.

Required error codes:

- `manifest_fetch_failed`
- `manifest_invalid`
- `download_failed`
- `hash_mismatch`
- `unpack_failed`
- `runtime_validation_failed`
- `runtime_not_installed`
- `runtime_start_failed`
- `session_not_found`
- `session_write_failed`
- `session_resize_failed`
- `file_not_found`
- `path_not_allowed`
- `backup_invalid`
- `restore_failed`

Each error includes:

- code
- localized user message key in Flutter
- technical message for diagnostics
- optional details map

Native must return technical codes. Flutter maps codes to localized user-facing text.

## 15. Persistence

Use lightweight JSON files for runtime metadata and install metadata because runtime state is platform-owned and must be readable before Flutter model initialization is complete.

Use SharedPreferences only for UI preferences such as:

- terminal font scale
- shortcut row visibility
- last opened virtual path

Do not store secrets in SharedPreferences. Future SSH credentials must use secure storage.

## 16. App Lifecycle

When app enters background:

- Keep active session only as long as iOS allows the app to run.
- Flush pending metadata writes.
- Do not claim background terminal execution support.

When app returns foreground:

- Check session liveness.
- If session exited, show terminal exited state.
- Let user restart session.

When app is killed:

- Active sessions are considered gone.
- On next launch, stale session IDs are cleared.

## 17. Testing Strategy

### 17.1 Dart Unit Tests

Cover:

- Manifest parsing.
- Runtime state transitions.
- Error code mapping.
- Backup manifest validation.
- Virtual path validation.
- Storage size formatting.

### 17.2 Flutter Widget Tests

Cover:

- Management page not installed state.
- Management page installing state.
- Management page installed state.
- Failed install state with retry action.
- Destructive reset confirmation.
- File browser empty directory.

### 17.3 iOS Native Tests

Cover:

- Manifest validation.
- SHA256 verification.
- Staging cleanup.
- Allowed path resolution.
- Rejected path traversal.
- Session start failure when runtime is missing.

### 17.4 Integration Tests

Run on iOS simulator where possible:

- Install mocked small runtime package.
- Open terminal page.
- Start session against a test runtime adapter.
- Validate output stream reaches Flutter.

Run on physical iOS device:

- Install real runtime.
- Execute `pwd`.
- Execute `ls`.
- Execute `echo kelivo`.
- Execute `python3 --version` on Python-enabled runtime.
- Back up home.
- Reset home.
- Restore backup.

## 18. Verification Commands

After implementation changes:

```sh
flutter gen-l10n
dart format lib/features/terminal ios/Runner
flutter analyze
flutter test
flutter build ios --no-codesign
```

For native runtime changes, also run an iOS device or simulator verification. If the real runtime requires physical device behavior, simulator-only verification is not sufficient.

## 19. Milestones

### Milestone 1: Native Runtime Spike

Goal:

- Prove that the selected iSH ARM64 runtime can be embedded and started from Kelivo's iOS Runner.

Acceptance:

- Native code can start a shell-like session.
- Native code can emit output bytes.
- Native code can accept input bytes.

### Milestone 2: Flutter Bridge Spike

Goal:

- Prove Flutter can open a terminal page and communicate with native session IO.

Acceptance:

- User opens a temporary terminal screen.
- Output appears in the terminal renderer.
- Keyboard input reaches native.

### Milestone 3: Runtime Installer

Goal:

- Install runtime through manifest download and activation.

Acceptance:

- Manifest is fetched.
- Archive is downloaded.
- SHA256 is verified.
- Runtime is unpacked and activated.
- Failed hash blocks activation.

### Milestone 4: Product UI

Goal:

- Add the user-facing iOS terminal management and terminal pages.

Acceptance:

- Settings entry opens management page.
- Management page shows runtime status and actions.
- Terminal page starts a real runtime session.
- Shortcut row works for required keys.

### Milestone 5: Files and Backup

Goal:

- Add runtime file browser and backup/restore.

Acceptance:

- User can browse home.
- User can import and export files.
- User can back up and restore home.
- Reset home preserves runtime installation.

## 20. Risk Register

### 20.1 Runtime Embed Risk

Risk:

- OpenMinis iSH ARM64 may require native project changes that conflict with Flutter Runner structure.

Mitigation:

- Keep all runtime code behind `KelivoTerminalPlugin`.
- Build a spike before product UI work.
- Avoid Flutter-side dependencies on runtime internals.

### 20.2 IO Contract Risk

Risk:

- Runtime console IO may not map cleanly to PTY-style byte streams.

Mitigation:

- Define `KelivoTerminalSession` as an adapter.
- Test output, input, resize, and exit independently.

### 20.3 Package Size Risk

Risk:

- Rootfs and tools can be large.

Mitigation:

- Download runtime package after install.
- Keep base app package small.
- Show compressed and unpacked sizes before installation.
- Make installer cache clearable.

### 20.4 Data Loss Risk

Risk:

- Reset, reinstall, or restore can delete user files.

Mitigation:

- Use explicit destructive confirmations.
- Stop sessions before destructive actions.
- Use staging and rollback directories.
- Default backup excludes rootfs but includes home.

### 20.5 Performance Risk

Risk:

- High terminal output volume can make Flutter UI janky.

Mitigation:

- Append output directly to terminal controller.
- Debounce UI state updates.
- Avoid full-page rebuilds for output chunks.

## 21. Compatibility Boundary

The iOS terminal feature introduces new app data under `Application Support/terminal`. It must not modify existing chat, provider, assistant, backup, or settings data except for adding terminal preferences and localization keys.

Existing user data compatibility requirements:

- Existing chats remain untouched.
- Existing backup flows remain untouched unless terminal backup integration is explicitly added later.
- Existing storage page behavior remains unchanged in the first terminal release.
- Removing terminal data must not delete app-wide files outside `Application Support/terminal`.

## 22. Documentation Updates During Implementation

When implementation starts, update or create:

- User-facing help text inside localized UI only where needed.
- Developer notes for preparing iOS runtime packages.
- Runtime manifest schema documentation.
- Manual verification checklist for iOS device testing.

## 23. References

- iSH: https://github.com/ish-app/ish
- OpenMinis iSH ARM64: https://github.com/OpenMinis/ish-arm64
- Apple On-Demand Resources: https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/On_Demand_Resources_Guide/
- Kelivo iOS native entry: `ios/Runner/AppDelegate.swift`
- Kelivo app data helper: `lib/utils/app_directories.dart`
- Kelivo mobile settings page: `lib/features/settings/pages/settings_page.dart`
