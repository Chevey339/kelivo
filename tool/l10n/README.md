# Localization workflow

Product changes are authored in `lib/l10n/app_en.arb` and `app_zh.arb`.
English owns the keys and placeholder types; Chinese supplies semantic context.
Every English resource has an `@key.description` explaining its location, UI
role, intended meaning, and any ambiguous terms or placeholders. Write or update
this description together with the source text.

Run from the repository root, with Python 3 and the project's Flutter SDK on PATH:

```sh
flutter pub get --directory tool/l10n --enforce-lockfile
python3 tool/l10n/translate.py status
python3 tool/l10n/translate.py sync
python3 tool/l10n/translate.py check
```

The first command initializes the tool's separate Dart package after checkout.
Its declared SDK dependency on `flutter_tools` gives the
IDE and command-line validator the same package resolution, without adding the
Flutter build tools to the app's dependencies. CI analyzes `tool/` along with
`lib/`, `test/`, and `integration_test/`.
When upgrading the pinned Flutter SDK, refresh this package's lockfile with
`flutter pub get --directory tool/l10n` and commit the updated lockfile.

`sync` translates only missing or stale messages, synchronizes Simplified Chinese
aliases, updates changed native resources, and runs `flutter gen-l10n`. Commit the ARBs, `tool/l10n/state/*.json`, and
generated Dart files. `check` is offline and also runs in CI. It rejects outdated
source fingerprints, missing keys, invalid placeholders, and invalid Flutter ICU.
Keep the normal Dart formatting, analysis, and affected tests in the root
`AGENTS.md` checklist.

## API credentials and batching

Supply `KELIVO_L10N_API_KEY` in the process environment. Otherwise the tool reads
`~/.config/kelivo/l10n-api-key` (or `KELIVO_L10N_API_KEY_FILE`) and finally offers a
hidden terminal prompt. Keep a local credential file outside the repository with
owner-only permissions (`0600`). Never store the key in source files.
Optional environment variables:

- `KELIVO_L10N_API_URL`: complete Chat Completions URL; no suffix is appended.
- `KELIVO_L10N_MODEL`: model ID; default `deepseek-v4.1-flash-1017`.

The default endpoint is `https://tokendance.space/gateway/v1/chat/completions`.
Requests disable thinking and require JSON. The tool retries transient errors,
checks the finish reason, and retries invalid messages without retranslating the
successful ones. `--batch-size` and `--interval` control request size and pacing.
Completed batches are persisted, so rerunning resumes after interruption.
When deliberately running separate language workers, use `--no-generate` and
run one normal `sync` after all workers finish. Each worker must own a different
target locale.

`describe` can bootstrap missing descriptions using the bilingual sources and
nearby Dart callers. Review generated descriptions, especially destructive actions
and ambiguous labels. Existing descriptions are retained. Ordinary development
should supply the description directly with each new key.

## Translation corrections and new languages

Human corrections can edit the target ARB directly. Unchanged source fingerprints
preserve those corrections on subsequent runs. If source text, descriptions,
placeholder metadata, or the language glossary changes, the message is translated
again. For a selected subset, pass `--keys keyOne,keyTwo`.
To request a fresh machine translation after a quality review, use
`sync --locales ru --keys keyOne --force`; otherwise unchanged source fingerprints
intentionally preserve edited translations.

To add a language, register its native name and locale in
`lib/l10n/app_language.dart`, and its target name and glossary in `translate.py`.
Generate and check its complete ARB before exposing it to users. Include platform
resources (iOS locale declarations, permission strings and share extension;
Android accessibility strings) and exercise desktop/mobile language switching,
follow-system behavior, persistence, and long labels.

Native translations use the shipping bilingual `ios/Runner/Info.plist`, the
English/Chinese share-extension strings, and English/Chinese Android accessibility
XML as their sources. Updating these sources invalidates the native fingerprint.
The supported native targets currently share the `ru` / `ko` / `tr` locale codes.

Validation uses the parser from the installed Flutter SDK, so it agrees with
`flutter gen-l10n` instead of approximating ICU with regular expressions. This
adapter is checked against the Flutter version pinned by CI. Flutter maps `=1`
and `one` to the same branch; never emit both. Russian categories must keep the
numeric placeholder so that 21 is rendered as 21, not a literal 1.
