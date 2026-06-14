#!/bin/sh
set -e
# Check if --set-exit-if-changed is passed as an argument
SET_EXIT_IF_CHANGED=""
for arg in "$@"; do
  if [ "$arg" = "--set-exit-if-changed" ]; then
    SET_EXIT_IF_CHANGED="--set-exit-if-changed"
    break
  fi
done

# List of files to ignore
IGNORED_FILES=".*\.g\.dart$|.*\.mocks\.dart$|.*\.gen\.dart$|firebase_options_prod\.dart$|firebase_options_dev\.dart$|dart_plugin_registrant\.dart$|.*\.freezed\.dart$"

# Check if "--only-staged" argument is provided
if echo "$@" | grep -q -- "--only-staged"; then
  # Get the list of staged files
  STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

  if [ -z "$STAGED_FILES" ]; then
    echo "No staged files to format."
    exit 0
  fi

  # Filter Dart files from staged files
  DART_STAGED_FILES=$(echo "$STAGED_FILES" | awk '/\.dart$/')

  if [ -z "$DART_STAGED_FILES" ]; then
    echo "No Dart files among staged files to format."
    exit 0
  fi

  # Exclude ignored files
  FILES_TO_FORMAT=$(echo "$DART_STAGED_FILES" | grep -Ev "$IGNORED_FILES" || true)

  if [ -z "$FILES_TO_FORMAT" ]; then
    echo "No Dart files to format."
    exit 0
  fi

else
  # Get the list of all Dart files excluding the ignored ones
  FILES_TO_FORMAT=$(git ls-files | grep '\.dart$' | grep -Ev "$IGNORED_FILES")
fi

# Check if there are any files to format
if [ -n "$FILES_TO_FORMAT" ]; then
  # Format the Dart files
  dart format $FILES_TO_FORMAT -l 120 $SET_EXIT_IF_CHANGED
else
  echo "No Dart files to format."
fi
