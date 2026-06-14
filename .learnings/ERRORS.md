# Errors

## 2026-06-03 - apply_patch unavailable in OpenClaw exec shell

- **Command:** `apply_patch <<'PATCH' ...`
- **Failure:** `/usr/bin/bash: line 1: apply_patch: command not found`
- **Context:** While editing Kelivo source files from OpenClaw.
- **Learning:** Do not assume `apply_patch` is installed in this environment. Use the OpenClaw `edit` tool for precise replacements when `apply_patch` is unavailable.

## 2026-06-03 - flutter CLI unavailable in OpenClaw exec shell

- **Command:** `flutter gen-l10n`
- **Failure:** `/usr/bin/bash: line 1: flutter: command not found`
- **Context:** While trying to regenerate Kelivo localization files after ARB changes.
- **Learning:** This workspace host may not have Flutter installed on PATH. Update checked-in generated localization files manually or run Flutter commands in an environment with the SDK available.

## 2026-06-03 - dart CLI unavailable in OpenClaw exec shell

- **Command:** `dart --version`
- **Failure:** `/usr/bin/bash: line 1: dart: command not found`
- **Context:** While trying to run static analysis after Kelivo Dart changes.
- **Learning:** This workspace host may not have the Dart SDK on PATH. Rely on textual checks here and run analyzer in a Flutter/Dart-enabled environment before release.
