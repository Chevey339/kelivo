#!/bin/bash
set -e -x # exit on first error

###############################################################################
# VERIFICATION FUNCTION FOR FLUTTER APP/PACKAGES
###############################################################################
verifyFlutter () {
  cd $1
  echo "Checking `pwd`"
  flutter --version
  flutter clean
  flutter pub get
  sh ./scripts/format.sh --set-exit-if-changed
  flutter analyze --no-pub .

  ###############################################################################
  # CODE COVERAGE
  ###############################################################################

  rm -rf coverage
  flutter test
}

###############################################################################
# INVOKE VERIFICATION FUNCTIONS
###############################################################################
verifyFlutter "."
