# markstream

Internal Markdown syntax package for Kelivo. `lib/src/core` contains the
immutable AST and source-coordinate types. Core code uses Dart libraries only;
Flutter functionality belongs outside that directory.

Use `package:markstream/markstream_core.dart` from code that must stay independent
of Flutter. Every source interval refers to UTF-16 offsets in the original,
unmodified input. AST child lists are immutable snapshots.

Run `flutter pub get`, `dart analyze --fatal-infos`, and `flutter test` from this
directory. The import guard checks every core source and the core barrel;
root-package tests do not discover this package's tests.
