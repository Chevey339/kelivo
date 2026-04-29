#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ish_dir="$repo_root/dependencies/ish-arm64"
configuration="${OPENMINIS_CONFIGURATION:-Release}"
derived_data="${DERIVED_DATA_DIR:-$repo_root/build/openminis-ish-arm64-simulator-derived}"

if [[ -n "${KELIVO_LLD_BIN:-}" ]]; then
  export PATH="$KELIVO_LLD_BIN:$PATH"
fi

if [[ -d /opt/homebrew/opt/lld/bin ]]; then
  export PATH="/opt/homebrew/opt/lld/bin:$PATH"
fi

if [[ -d /opt/homebrew/opt/llvm/bin ]]; then
  export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
fi

"$repo_root/scripts/ios/check_openminis_ish_arm64.sh"

xcodebuild \
  -project "$ish_dir/iSH.xcodeproj" \
  -target "libish" \
  -target "libish_emu" \
  -target "libfakefs" \
  -configuration "$configuration" \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  SYMROOT="$derived_data/Build/Products" \
  OBJROOT="$derived_data/Build/Intermediates.noindex" \
  GUEST_ARCH=arm64 \
  NINJA_TARGETS="libish.a libish_emu.a libfakefs.a" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  EXCLUDED_ARCHS=x86_64 \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

echo "OpenMinis iSH ARM64 simulator build finished."
echo "Derived data: $derived_data"
echo "Static libraries: $derived_data/Build/Products/$configuration-iphonesimulator"
