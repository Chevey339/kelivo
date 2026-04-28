# Kelivo iOS Local Terminal Requirements

## 1. Background

Kelivo needs a mobile-first terminal capability. The first mobile target is iOS. The iOS terminal is not intended to operate the iOS host system directly. It provides a local Linux-like runtime inside Kelivo's app sandbox so users can run shell commands, manage files inside the runtime, and execute common developer tools such as shell utilities and Python.

The preferred technical direction is a guest Linux runtime inspired by iSH and OpenMinis iSH ARM64. The runtime is installed into Kelivo's app data directory through a downloadable resource package instead of being bundled entirely into the base app package.

## 2. Product Goal

Build an iOS local terminal feature that lets users install and use a Kelivo-managed Linux runtime on iPhone and iPad.

The feature must support:

- Installing a downloadable iOS Linux runtime package.
- Opening an interactive terminal session.
- Running basic shell commands inside the runtime.
- Managing runtime files.
- Resetting, backing up, and restoring terminal data.
- Reporting installation, runtime, and storage state clearly.

## 3. Non-Goals

The first iOS version does not provide:

- Direct access to the iOS host shell.
- System-wide package installation on iOS.
- Jailbreak-only capabilities.
- Root access to iOS.
- Full iOS filesystem browsing.
- SSH client functionality. SSH is planned as a later cross-platform terminal runtime.
- Desktop terminal behavior. Desktop support will use a separate native PTY backend later.
- App Store compliance guarantees. Review strategy is intentionally outside the first implementation boundary.

## 4. Definitions

- Local Terminal: The terminal feature inside Kelivo.
- Runtime: The installed Linux guest environment used by the terminal.
- Rootfs: The unpacked filesystem image used by the guest runtime.
- Home: The user-writable home directory inside the runtime.
- Runtime Package: A compressed, signed or checksummed downloadable archive containing rootfs and runtime metadata.
- Session: One interactive terminal instance connected to the runtime.
- Terminal Management Page: The settings page where users install, inspect, reset, back up, and open the runtime.

## 5. Target Users

### 5.1 Primary User

A mobile-first LLM user who wants a local command-line workspace inside Kelivo for:

- Inspecting files.
- Running simple scripts.
- Trying shell commands suggested by the assistant.
- Running Python scripts locally.
- Managing small local projects inside the app sandbox.

### 5.2 Advanced User

A technical user who wants a stronger mobile development environment:

- More packages.
- Larger runtime.
- Better file import/export.
- Backup and restore.
- Later SSH access to remote servers.

## 6. User Experience Requirements

### 6.1 Settings Entry

iOS settings must expose a Terminal entry in the mobile settings page.

Required behavior:

- The entry is visible on iOS.
- The entry title and any visible copy must use `AppLocalizations`.
- The entry opens the Terminal Management Page.
- The entry must not be hidden behind desktop-only UI.

### 6.2 Terminal Management Page

The Terminal Management Page is the main control surface for the local terminal runtime.

It must show:

- Runtime installation status.
- Runtime version.
- Runtime package source.
- Runtime size.
- Home directory size.
- Cache size.
- Last install or update time.
- Last error, if any.

It must provide these primary actions:

- Install runtime.
- Open terminal.
- Browse files.
- Back up terminal data.
- Reset terminal data.

It must provide these secondary actions:

- Retry failed install.
- Clear installer cache.
- View runtime details.
- Export diagnostic log.

It must provide destructive actions only behind confirmation dialogs:

- Reset home directory.
- Reinstall runtime.
- Delete all terminal data.

### 6.3 First-Run Installation

When the user opens Terminal for the first time:

- If no runtime is installed, show an installation screen.
- Show compressed download size and expected unpacked size before starting.
- Let the user start installation explicitly.
- Show download progress.
- Show verification progress.
- Show unpack progress.
- Show a clear error if installation fails.
- Do not present a fake success state if any install step fails.

The user must be able to leave the page while install is running. On return, the page must reflect the current install state.

### 6.4 Interactive Terminal

After installation, users can open an interactive terminal.

Required behavior:

- Display a terminal viewport.
- Accept keyboard input.
- Support paste.
- Support copy from selected terminal text.
- Send terminal resize information to the runtime.
- Show session connection state.
- Recover cleanly from runtime process exit.
- Let the user restart the session.
- Let the user clear visible scrollback.

Required mobile controls:

- A compact top bar with session title and status.
- A bottom shortcut row for keys that are awkward on mobile keyboards.
- Required shortcut keys: `Esc`, `Tab`, `Ctrl`, `/`, `-`, `|`, `~`, arrow keys.
- A menu for copy, paste, clear, restart, font size, and close.

### 6.5 Terminal File Browser

The user must be able to browse runtime files from the management page.

Required behavior:

- Start at the runtime home directory.
- Navigate directories.
- Show file name, type, size, and modified time.
- Open text files in a read-only viewer.
- Export files through the iOS document picker.
- Import files into the current runtime directory through the iOS document picker.
- Create folders.
- Rename files and folders.
- Delete files and folders after confirmation.

Initial boundary:

- Browse Kelivo terminal runtime directories only.
- Do not implement full iOS filesystem access.
- Do not expose implementation-only internal files by default.

### 6.6 Backup and Restore

The user must be able to back up terminal data.

Backup must include:

- Home directory.
- User-created files and folders.
- Runtime profile metadata.
- Installed runtime manifest.
- User terminal settings.

Backup must not include by default:

- Runtime rootfs package.
- Installer cache.
- Download cache.
- Diagnostic logs.

Restore behavior:

- Validate backup format before writing files.
- Show backup summary before restore.
- Support restore into an existing installed runtime.
- Stop active terminal sessions before restore.
- Restore failure must leave the previous valid state intact when possible.

### 6.7 Runtime Reset

The product must support three reset levels:

- Reset session: close and restart the current terminal process.
- Reset home: clear user home data while keeping runtime installed.
- Reinstall runtime: delete rootfs and reinstall from a runtime package.

Each reset level must use a different confirmation message.

### 6.8 Runtime Updates

The first version must support checking whether the installed runtime version differs from the currently configured manifest.

Required behavior:

- Show available update status.
- Download and verify the new runtime before switching.
- Preserve the user home directory during runtime update.
- Keep the previous runtime until the new runtime is verified.
- Allow rollback if activation fails.

Automatic background update is not required for the first version.

### 6.9 Diagnostics

The product must expose enough diagnostic information to support debugging.

Required diagnostics:

- Runtime status.
- Runtime version.
- Install step.
- Download URL host.
- SHA256 verification result.
- Unpack result.
- Last session exit code or signal, when available.
- Native runtime error messages.

Diagnostic logs must not include secrets.

## 7. Functional Requirements

### 7.1 Runtime State

Kelivo must track these runtime states:

- `notInstalled`
- `installing`
- `installed`
- `updateAvailable`
- `repairRequired`
- `failed`

The UI must render each state distinctly.

### 7.2 Installer

The installer must:

- Read a runtime manifest.
- Download the referenced package.
- Validate package hash.
- Unpack into a staging directory.
- Validate required runtime files.
- Atomically activate the runtime.
- Persist installed runtime metadata.
- Clean stale staging directories on next launch.

### 7.3 Session Lifecycle

The session system must:

- Start a runtime shell session.
- Stream output from native runtime to Flutter.
- Stream input from Flutter to native runtime.
- Resize sessions.
- Stop sessions.
- Report session exit.
- Support at least one active session in the first release.

Multiple terminal tabs are not required for the first iOS release.

### 7.4 Runtime File Operations

The file service must:

- Resolve paths relative to allowed terminal roots.
- Reject path traversal outside allowed roots.
- List directories.
- Read text files within a size limit.
- Import files.
- Export files.
- Rename entries.
- Delete entries after confirmation.
- Create directories.

### 7.5 Storage Reporting

The terminal management page must report:

- Rootfs size.
- Home size.
- Cache size.
- Backup size.
- Total terminal size.

Terminal storage should later be included in the app-wide storage page.

### 7.6 Localization

All user-visible strings must use the existing localization system.

When implementation starts, every new string must be added to all four ARB files:

- `lib/l10n/app_en.arb`
- `lib/l10n/app_zh.arb`
- `lib/l10n/app_zh_Hans.arb`
- `lib/l10n/app_zh_Hant.arb`

After ARB changes, `flutter gen-l10n` is required.

## 8. Non-Functional Requirements

### 8.1 Reliability

- Installation must be resumable or safely retryable.
- Failed install must not corrupt a previously working runtime.
- Runtime activation must be atomic.
- Active session state must not pretend to survive app termination.
- On app restart, stale session records must be cleared.

### 8.2 Performance

- Terminal output must remain responsive for common command output.
- Large output must not rebuild the full Flutter page for every byte.
- Installer decompression must not block the Flutter UI isolate.
- File size calculation must run asynchronously.
- The terminal page must avoid loading the full runtime tree into memory.

### 8.3 Storage

- Runtime packages must not be bundled into the base app package unless explicitly configured for development builds.
- Installer cache must be clearable.
- Backups must be compressed.
- The product must show large storage usage before destructive operations.

### 8.4 Security

- Terminal file APIs must stay inside allowed terminal directories.
- Runtime package integrity must be verified before activation.
- Download failures must be explicit.
- Logs must not include full secret values.
- Future SSH credentials must use platform secure storage, not plain SharedPreferences.

### 8.5 Accessibility

- Buttons must have accessible labels.
- Destructive actions must be reachable and understandable with screen readers.
- Terminal controls outside the terminal canvas must be accessible.
- Text size controls must not break terminal layout.

### 8.6 Offline Behavior

- Installed runtime must work offline.
- Install and update require network access.
- If manifest fetch fails, the UI must show the last installed runtime if available.

## 9. Acceptance Criteria

### 9.1 First Install

Given no runtime is installed, when the user opens Terminal Management and starts install, then Kelivo downloads, verifies, unpacks, activates, and shows the runtime as installed.

### 9.2 Shell Session

Given runtime is installed, when the user opens Terminal, then a shell prompt appears and these commands work:

```sh
pwd
ls
echo kelivo
python3 --version
```

`python3 --version` may be satisfied by a runtime package variant that includes Python.

### 9.3 Failed Download

Given runtime download fails, when the user returns to Terminal Management, then the page shows failed state and retry action, and no installed runtime is marked active.

### 9.4 Failed Hash Verification

Given downloaded package hash does not match the manifest, when install runs, then activation is blocked and the error identifies verification failure.

### 9.5 File Browser

Given runtime is installed, when the user opens Browse Files, then the home directory is shown and the user can import, export, create, rename, and delete files within allowed runtime roots.

### 9.6 Backup and Restore

Given the user has files in home, when they create a backup and restore it after clearing home, then the files are restored with names and contents intact.

### 9.7 Reset Home

Given runtime is installed and home contains files, when the user confirms Reset Home, then active sessions stop and home is recreated empty while runtime remains installed.

## 10. Requirement Scenario Set

Minimum implementation tests must cover:

- Happy path: install runtime, open terminal, run basic commands.
- Boundary inputs: empty home, large directory listing, file names with spaces, terminal resize to small dimensions.
- Failure paths: download failure, hash mismatch, unpack failure, session start failure.
- State transitions: `notInstalled -> installing -> installed`, `installing -> failed`, `installed -> repairRequired`, active session close and restart.

## 11. Implementation Boundary

In scope for iOS first release:

- Mobile settings entry.
- iOS Terminal Management Page.
- iOS local runtime installer.
- iOS local terminal session.
- Runtime file browser.
- Runtime backup and restore.
- Diagnostics.

Out of scope for iOS first release:

- Android runtime.
- Desktop runtime.
- SSH.
- Multiple terminal tabs.
- Background long-running terminal tasks after app termination.
- Package repository UI.
- Assistant tool execution through terminal.

## 12. References

- iSH: https://github.com/ish-app/ish
- OpenMinis iSH ARM64: https://github.com/OpenMinis/ish-arm64
- Apple On-Demand Resources: https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/On_Demand_Resources_Guide/
- Kelivo mobile settings entry: `lib/features/settings/pages/settings_page.dart`
- Kelivo app data directory helper: `lib/utils/app_directories.dart`
