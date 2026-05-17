#!/bin/bash
set -e

cd example
flutter pub get
flutter build web --no-tree-shake-icons

cd build/web
npx --yes serve -l 5000 -s .
