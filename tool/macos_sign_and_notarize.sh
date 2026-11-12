#!/usr/bin/env bash
# Sign Kelivo.app with a Developer ID Application certificate, then notarize and
# staple the DMG. Secrets are read from the environment. When they are all
# absent (forks, pull requests), both commands exit 0 and leave the build
# unsigned. Incomplete secrets fail the command so a release is not published
# as if it had been notarized.
#
# macOS runners ship Bash 3.2. Keep this script compatible with that version.
# Setup: docs/macos-signing.md

set -euo pipefail

TEAM_ID_DEFAULT="5WN7Y88J52"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
ENTITLEMENTS="${MACOS_ENTITLEMENTS:-$REPO_ROOT/macos/Runner/Release.entitlements}"

PLAN=""
APP=""
DMG=""
MOUNTED_APP=""
MOUNT_POINT=""
WORK_DIR=""
KEYCHAIN_PATH=""
KEYCHAIN_READY=0
ORIGINAL_DEFAULT=""
ORIGINAL_KEYCHAINS=()
P12_PATH=""
API_KEY_PATH=""
SKIP_FILE=""
IDENTITY=""
NOTARY_ARGS=()

usage() {
  cat <<'EOF'
Usage:
  macos_sign_and_notarize.sh check
  macos_sign_and_notarize.sh sign-app <kelivo.app>
  macos_sign_and_notarize.sh notarize-dmg <Kelivo.dmg> <kelivo.app>

check prints skip, api, or apple-id. sign-app and notarize-dmg sign with the
Developer ID certificate. notarize-dmg also submits the DMG to notarytool,
staples the ticket, and verifies the app inside the image.
EOF
}

normalize_secret() {
  printf '%s' "${1:-}" | tr -d '\r\n'
}

# True when the value is empty after removing whitespace.
blank() {
  local value
  value=$(normalize_secret "${1:-}")
  [[ -z "${value//[[:space:]]/}" ]]
}

note_summary() {
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '%s\n' "$*" >>"$GITHUB_STEP_SUMMARY"
  fi
}

die() {
  echo "错误: $*" >&2
  exit 1
}

unwrap_keychain_path() {
  local line="$1"
  line=${line#"${line%%[![:space:]]*}"}
  line=${line%"${line##*[![:space:]]}"}
  line=${line#\"}
  line=${line%\"}
  printf '%s\n' "$line"
}

prepare_plan() {
  MACOS_CERTIFICATE_P12_BASE64=$(normalize_secret "${MACOS_CERTIFICATE_P12_BASE64:-}")
  MACOS_CERTIFICATE_PASSWORD=$(normalize_secret "${MACOS_CERTIFICATE_PASSWORD:-}")
  APP_STORE_CONNECT_API_KEY_ID=$(normalize_secret "${APP_STORE_CONNECT_API_KEY_ID:-}")
  APP_STORE_CONNECT_API_KEY_ISSUER_ID=$(normalize_secret "${APP_STORE_CONNECT_API_KEY_ISSUER_ID:-}")
  APP_STORE_CONNECT_API_KEY_P8_BASE64=$(normalize_secret "${APP_STORE_CONNECT_API_KEY_P8_BASE64:-}")
  APPLE_ID=$(normalize_secret "${APPLE_ID:-}")
  APPLE_APP_SPECIFIC_PASSWORD=$(normalize_secret "${APPLE_APP_SPECIFIC_PASSWORD:-}")
  APPLE_TEAM_ID=$(normalize_secret "${APPLE_TEAM_ID:-}")

  local any_cert=0 any_api=0 any_apple=0 api_ok=0 apple_ok=0
  if ! blank "$MACOS_CERTIFICATE_P12_BASE64" || ! blank "$MACOS_CERTIFICATE_PASSWORD"; then
    any_cert=1
  fi
  if ! blank "$APP_STORE_CONNECT_API_KEY_ID" || ! blank "$APP_STORE_CONNECT_API_KEY_ISSUER_ID" || ! blank "$APP_STORE_CONNECT_API_KEY_P8_BASE64"; then
    any_api=1
  fi
  if ! blank "$APPLE_ID" || ! blank "$APPLE_APP_SPECIFIC_PASSWORD"; then
    any_apple=1
  fi

  if [[ "$any_cert" -eq 0 && "$any_api" -eq 0 && "$any_apple" -eq 0 ]]; then
    PLAN="skip"
    return 0
  fi

  if blank "$MACOS_CERTIFICATE_P12_BASE64" || blank "$MACOS_CERTIFICATE_PASSWORD"; then
    die "Developer ID 证书配置不完整。需要同时设置 MACOS_CERTIFICATE_P12_BASE64 和 MACOS_CERTIFICATE_PASSWORD。未准备好签名时请留空这两个 secret，构建会改为未签名并成功结束。"
  fi
  if ! blank "$APP_STORE_CONNECT_API_KEY_ID" && ! blank "$APP_STORE_CONNECT_API_KEY_ISSUER_ID" && ! blank "$APP_STORE_CONNECT_API_KEY_P8_BASE64"; then
    api_ok=1
  fi
  if ! blank "$APPLE_ID" && ! blank "$APPLE_APP_SPECIFIC_PASSWORD"; then
    apple_ok=1
  fi
  if [[ "$any_api" -eq 1 && "$api_ok" -eq 0 ]]; then
    die "App Store Connect API 密钥配置不完整。需要同时设置 APP_STORE_CONNECT_API_KEY_ID、APP_STORE_CONNECT_API_KEY_ISSUER_ID 和 APP_STORE_CONNECT_API_KEY_P8_BASE64。"
  fi
  if [[ "$any_apple" -eq 1 && "$apple_ok" -eq 0 ]]; then
    die "Apple ID 公证配置不完整。需要同时设置 APPLE_ID 和 APPLE_APP_SPECIFIC_PASSWORD。"
  fi
  if [[ "$api_ok" -eq 0 && "$apple_ok" -eq 0 ]]; then
    die "已配置 Developer ID 证书，但没有公证凭据。请配置 App Store Connect API 密钥（推荐），或 APPLE_ID 与 APPLE_APP_SPECIFIC_PASSWORD。见 docs/macos-signing.md。"
  fi

  if [[ "$api_ok" -eq 1 ]]; then
    PLAN="api"
  else
    PLAN="apple-id"
  fi
}

abs_path_existing() {
  local input="$1" dir base
  if [[ ! -e "$input" ]]; then
    return 1
  fi
  dir=$(cd "$(dirname "$input")" && pwd)
  base=$(basename "$input")
  printf '%s/%s\n' "$dir" "$base"
}

detach_mount() {
  if [[ -n "${MOUNT_POINT:-}" ]]; then
    hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || hdiutil detach -force "$MOUNT_POINT" >/dev/null 2>&1 || true
    rm -rf "$MOUNT_POINT"
    MOUNT_POINT=""
  fi
  MOUNTED_APP=""
}

cleanup() {
  local status=$?
  detach_mount
  if [[ "$KEYCHAIN_READY" -eq 1 ]]; then
    if [[ ${#ORIGINAL_KEYCHAINS[@]} -gt 0 ]]; then
      security list-keychains -d user -s "${ORIGINAL_KEYCHAINS[@]}" >/dev/null 2>&1 || true
    fi
    if [[ -n "$ORIGINAL_DEFAULT" ]]; then
      security default-keychain -s "$ORIGINAL_DEFAULT" >/dev/null 2>&1 || true
    fi
    if [[ -n "$KEYCHAIN_PATH" ]]; then
      security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
    fi
    KEYCHAIN_READY=0
  fi
  if [[ "$WORK_DIR" == *kelivo-signing-* ]]; then
    rm -rf "$WORK_DIR"
    WORK_DIR=""
  fi
  exit "$status"
}

start_secure_workspace() {
  umask 077
  WORK_DIR="${RUNNER_TEMP:-/tmp}/kelivo-signing-$$"
  mkdir -p "$WORK_DIR"
  chmod 700 "$WORK_DIR"
  trap cleanup EXIT
}

import_apple_intermediate() {
  local url="$1" name="$2" dest
  dest="$WORK_DIR/$name"
  if curl -fsSL --retry 3 --retry-delay 2 -o "$dest" "$url"; then
    security import "$dest" -k "$KEYCHAIN_PATH" -T /usr/bin/codesign >/dev/null || true
    rm -f "$dest"
  else
    echo "警告: 未能下载 $name。若公证报证书链错误，请把 Developer ID 中间证书一并放进 .p12。"
  fi
}

import_certificate() {
  local identities line
  P12_PATH="$WORK_DIR/certificate.p12"
  KEYCHAIN_PATH="$WORK_DIR/kelivo-signing.keychain-db"
  printf '%s' "$MACOS_CERTIFICATE_P12_BASE64" | tr -d '[:space:]' | base64 -D >"$P12_PATH"
  chmod 600 "$P12_PATH"

  local keychain_password
  keychain_password=$(openssl rand -base64 32 | tr -d '\n') || die "无法生成临时钥匙串密码"
  # create-keychain inserts the new keychain into the search list. Record the
  # previous list first so cleanup can restore it for the rest of the job.
  ORIGINAL_KEYCHAINS=()
  if ! security list-keychains -d user >"$WORK_DIR/keychains.txt"; then
    die "无法读取钥匙串搜索列表"
  fi
  while IFS= read -r line; do
    line=$(unwrap_keychain_path "$line")
    if [[ -n "$line" ]]; then
      ORIGINAL_KEYCHAINS+=("$line")
    fi
  done <"$WORK_DIR/keychains.txt"
  local default_raw
  default_raw=$(security default-keychain) || die "无法读取当前默认钥匙串"
  ORIGINAL_DEFAULT=$(unwrap_keychain_path "$default_raw")

  security create-keychain -p "$keychain_password" "$KEYCHAIN_PATH"
  KEYCHAIN_READY=1
  security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
  security unlock-keychain -p "$keychain_password" "$KEYCHAIN_PATH"
  security list-keychains -d user -s "$KEYCHAIN_PATH" "${ORIGINAL_KEYCHAINS[@]}"
  security default-keychain -s "$KEYCHAIN_PATH"

  # Let macOS read its native PKCS#12 export. OpenSSL 3+ rejects the RC2
  # encryption used by valid Keychain exports unless a legacy provider is loaded.
  if ! security import "$P12_PATH" \
    -k "$KEYCHAIN_PATH" \
    -P "$MACOS_CERTIFICATE_PASSWORD" \
    -f pkcs12 \
    -A \
    -T /usr/bin/codesign \
    -T /usr/bin/security; then
    die "无法导入 .p12。请确认 MACOS_CERTIFICATE_PASSWORD 正确，且 MACOS_CERTIFICATE_P12_BASE64 是包含证书和私钥的 .p12 文件的 base64。"
  fi
  security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s \
    -k "$keychain_password" \
    "$KEYCHAIN_PATH" >/dev/null

  import_apple_intermediate "https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer" "DeveloperIDG2CA.cer"
  import_apple_intermediate "https://www.apple.com/certificateauthority/DeveloperIDCA.cer" "DeveloperIDCA.cer"

  identities=$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p') || die "无法列出签名身份"
  IDENTITY=""
  local team_id="${APPLE_TEAM_ID:-$TEAM_ID_DEFAULT}"
  if blank "$team_id"; then
    team_id="$TEAM_ID_DEFAULT"
  fi
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" == *"$team_id"* ]]; then
      IDENTITY=$line
      break
    fi
    if [[ -z "$IDENTITY" ]]; then
      IDENTITY=$line
    fi
  done <<<"$identities"
  if [[ -z "$IDENTITY" ]]; then
    echo "钥匙串中的代码签名身份：" >&2
    security find-identity -v -p codesigning "$KEYCHAIN_PATH" >&2 || true
    die "没有找到带私钥的有效 Developer ID Application 签名身份。请连同私钥导出 Developer ID Application（Team ID ${team_id}），不要用 Apple Development、Mac App Distribution 或 Developer ID Installer。"
  fi
  echo "签名身份: $IDENTITY"
  rm -f "$P12_PATH"
  P12_PATH=""
}

build_notary_args() {
  local team_id="${APPLE_TEAM_ID:-$TEAM_ID_DEFAULT}"
  if blank "$team_id"; then
    team_id="$TEAM_ID_DEFAULT"
  fi
  if [[ "$PLAN" == "api" ]]; then
    API_KEY_PATH="$WORK_DIR/AuthKey.p8"
    printf '%s' "$APP_STORE_CONNECT_API_KEY_P8_BASE64" | tr -d '[:space:]' | base64 -D >"$API_KEY_PATH"
    chmod 600 "$API_KEY_PATH"
    if ! grep -q "PRIVATE KEY" "$API_KEY_PATH"; then
      die "APP_STORE_CONNECT_API_KEY_P8_BASE64 解码后不是 .p8 私钥。请对 AuthKey_XXXX.p8 文件本身做 base64，不要再包一层。"
    fi
    NOTARY_ARGS=(--key "$API_KEY_PATH" --key-id "$APP_STORE_CONNECT_API_KEY_ID" --issuer "$APP_STORE_CONNECT_API_KEY_ISSUER_ID")
    echo "公证方式: App Store Connect API 密钥"
  else
    NOTARY_ARGS=(--apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$team_id")
    echo "公证方式: Apple ID（Team ID ${team_id}）"
  fi
}

resolve_path() {
  local path="$1" dir target
  while [[ -L "$path" ]]; do
    target=$(readlink "$path")
    if [[ "$target" != /* ]]; then
      dir=$(dirname "$path")
      target="$dir/$target"
    fi
    path=$target
  done
  printf '%s\n' "$path"
}

bundle_main_executable() {
  local bundle="$1" plist exec_name candidate resolved
  exec_name=""
  for plist in \
    "$bundle/Contents/Info.plist" \
    "$bundle/Resources/Info.plist" \
    "$bundle/Versions/A/Resources/Info.plist" \
    "$bundle/Versions/Current/Resources/Info.plist"; do
    if [[ -f "$plist" ]]; then
      exec_name=$(plutil -extract CFBundleExecutable raw "$plist" 2>/dev/null || true)
      if [[ -n "$exec_name" ]]; then
        break
      fi
    fi
  done
  if [[ -z "$exec_name" ]]; then
    exec_name=$(basename "$bundle")
    exec_name="${exec_name%.*}"
  fi
  for candidate in \
    "$bundle/Contents/MacOS/$exec_name" \
    "$bundle/Versions/A/$exec_name" \
    "$bundle/Versions/Current/$exec_name" \
    "$bundle/$exec_name"; do
    if [[ -e "$candidate" ]]; then
      resolved=$(resolve_path "$candidate")
      if [[ -f "$resolved" ]]; then
        printf '%s\n' "$resolved"
        return 0
      fi
    fi
  done
}

is_skipped() {
  grep -F -x -q "$1" "$SKIP_FILE"
}

should_probe() {
  case "$1" in
    *.png | *.jpg | *.jpeg | *.gif | *.webp | *.svg | *.ico | *.icns | *.ttf | *.otf | *.woff | *.woff2 | *.json | *.txt | *.md | *.html | *.css | *.js | *.dart | *.yaml | *.yml | *.xml | *.plist | *.strings | *.nib | *.car | *.metallib | *.onnx | *.model | *.vocab | *.pak | *.dat | *.zip | *.gz | *.pdf | *.stringsdict | *.storyboard | *.xib | *.modulemap | *.h | *.swift | *.m | *.mm | *.c | *.cc | *.pcm)
      return 1
      ;;
  esac
  return 0
}

is_macho() {
  local kind
  kind=$(file -b "$1" 2>/dev/null || true)
  case "$kind" in
    Mach-O*) return 0 ;;
  esac
  return 1
}

sign_code() {
  local target="$1"
  shift
  echo "签名: ${target#"$APP"/}"
  # `|| exit` is required so a codesign failure still aborts inside `while`
  # on the Bash 3.2 that ships with macOS.
  codesign --force --options runtime --timestamp \
    --sign "$IDENTITY" \
    --keychain "$KEYCHAIN_PATH" \
    "$@" \
    "$target" || exit 1
}

clean_app_metadata() {
  # Finder metadata and AppleDouble files make codesign reject the bundle as
  # "detritus". Strip them before signing, then do not touch the bundle again.
  if command -v dot_clean >/dev/null 2>&1; then
    dot_clean -m "$APP" >/dev/null 2>&1 || true
  fi
  xattr -cr "$APP" >/dev/null 2>&1 || true
  find "$APP" \( -name '.DS_Store' -o -name '._*' \) -delete || true
}

sign_nested_code() {
  local f bundle macho_count=0 bundle_count=0
  [[ -f "$ENTITLEMENTS" ]] || die "找不到 entitlements: $ENTITLEMENTS"
  plutil -lint "$ENTITLEMENTS" >/dev/null
  SKIP_FILE="$WORK_DIR/skip-main-executables.txt"
  : >"$SKIP_FILE"

  while IFS= read -r -d '' bundle; do
    bundle_main_executable "$bundle" >>"$SKIP_FILE" || true
  done < <(find "$APP" -type d \( -name '*.app' -o -name '*.framework' -o -name '*.xpc' -o -name '*.bundle' -o -name '*.appex' -o -name '*.plugin' \) -print0)

  while IFS= read -r -d '' f; do
    if is_skipped "$f"; then
      continue
    fi
    if ! should_probe "$f"; then
      continue
    fi
    if is_macho "$f"; then
      sign_code "$f"
      macho_count=$((macho_count + 1))
    fi
  done < <(find "$APP" -type f -print0)

  # Sign bundle directories inside-out. --deep signs outside-in and misses
  # nested Mach-O files, so each framework, plugin, and helper is signed here.
  while IFS= read -r -d '' bundle; do
    if [[ "$bundle" == "$APP" ]]; then
      continue
    fi
    sign_code "$bundle"
    bundle_count=$((bundle_count + 1))
  done < <(find "$APP" -depth -type d \( -name '*.app' -o -name '*.framework' -o -name '*.xpc' -o -name '*.bundle' -o -name '*.appex' -o -name '*.plugin' \) -print0)

  sign_code "$APP" --entitlements "$ENTITLEMENTS"
  echo "已签名独立 Mach-O ${macho_count} 个、内嵌 bundle ${bundle_count} 个，并签名主应用。"
}

verify_signed_app() {
  local display
  echo "验证应用签名"
  codesign --verify --deep --strict --verbose=2 "$APP"
  display=$(codesign --display --verbose=4 --entitlements - "$APP" 2>&1 || true)
  printf '%s\n' "$display"
  if ! printf '%s\n' "$display" | grep -E -q 'flags=.*runtime'; then
    die "应用没有启用 Hardened Runtime。"
  fi
  if ! printf '%s\n' "$display" | grep -a -q 'com.apple.security.cs.allow-jit'; then
    die "应用签名缺少 com.apple.security.cs.allow-jit。Flutter 引擎和内置 WebView 在 Hardened Runtime 下需要这项 entitlement。"
  fi
  if ! printf '%s\n' "$display" | grep -q 'Developer ID Application'; then
    die "应用不是用 Developer ID Application 签名的。"
  fi
}

sign_dmg() {
  echo "签名 DMG: $(basename "$DMG")"
  codesign --force --timestamp \
    --sign "$IDENTITY" \
    --keychain "$KEYCHAIN_PATH" \
    "$DMG"
  codesign --verify --verbose=2 "$DMG"
}

mount_dmg() {
  detach_mount
  MOUNT_POINT=$(mktemp -d) || die "无法创建挂载点"
  if ! hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MOUNT_POINT"; then
    rm -rf "$MOUNT_POINT"
    MOUNT_POINT=""
    die "无法挂载 DMG: $DMG"
  fi
}

find_mounted_app() {
  local candidate
  MOUNTED_APP=""
  while IFS= read -r candidate; do
    MOUNTED_APP=$candidate
    break
  done < <(find "$MOUNT_POINT" -maxdepth 3 -type d -name 'kelivo.app')
  [[ -n "$MOUNTED_APP" ]] || die "DMG 里没有 kelivo.app"
}

ensure_dmg_contains_signed_app() {
  echo "检查已签名的应用"
  codesign --verify --deep --strict --verbose=2 "$APP" || die "应用签名无效。sign-app 需要先成功。"
  mount_dmg
  find_mounted_app
  if codesign --verify --deep --strict --verbose=2 "$MOUNTED_APP"; then
    echo "DMG 内的应用签名有效。"
    detach_mount
    return 0
  fi
  echo "DMG 内的应用签名无效。create-dmg 写入 Finder 信息时会破坏签名，改用 hdiutil 从已签名的 .app 重新打包。"
  detach_mount
  rm -f "$DMG"
  hdiutil create -volname Kelivo -srcfolder "$APP" -ov -format UDZO "$DMG"
  mount_dmg
  find_mounted_app
  if ! codesign --verify --deep --strict --verbose=2 "$MOUNTED_APP"; then
    die "重新打包后，DMG 内的应用签名仍然无效。"
  fi
  echo "hdiutil 打包后的应用签名有效。"
  detach_mount
}

submit_for_notarization() {
  local plist="$WORK_DIR/notary.plist" rc submission_id="" status
  echo "提交公证（notarytool --wait，通常需要几分钟到几十分钟）"
  set +e
  xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" --wait --timeout 60m --output-format plist >"$plist"
  rc=$?
  set -e
  if [[ -s "$plist" ]]; then
    echo "notarytool 结果:"
    plutil -p "$plist" || true
    submission_id=$(plutil -extract id raw "$plist" 2>/dev/null || true)
  fi
  if [[ "$rc" -ne 0 || -z "$submission_id" ]]; then
    if [[ -n "$submission_id" ]]; then
      echo "公证未通过，Apple 返回的日志："
      xcrun notarytool log "$submission_id" "${NOTARY_ARGS[@]}" || true
    fi
    die "公证失败（notarytool 退出码 ${rc}）。"
  fi
  status=$(plutil -extract status raw "$plist") || die "无法读取公证状态"
  if [[ "$status" != "Accepted" ]]; then
    echo "公证未通过，Apple 返回的日志："
    xcrun notarytool log "$submission_id" "${NOTARY_ARGS[@]}" || true
    die "公证状态是 ${status}，不是 Accepted。"
  fi
  echo "公证已通过: $submission_id"
}

staple_with_retry() {
  local target="$1" attempt
  for attempt in 1 2 3 4 5 6; do
    if xcrun stapler staple "$target"; then
      xcrun stapler validate "$target"
      return 0
    fi
    if [[ "$attempt" -lt 6 ]]; then
      echo "stapler 尚未拿到票据（第 ${attempt}/6 次），20 秒后重试..."
      sleep 20
    fi
  done
  die "无法把公证票据钉到 $target"
}

assess_gatekeeper() {
  local kind="$1" target="$2" attempt
  for attempt in 1 2 3 4 5 6; do
    if [[ "$kind" == "open" ]]; then
      if spctl --assess --type open --context context:primary-signature --verbose=4 "$target"; then
        return 0
      fi
    elif spctl --assess --type "$kind" --verbose=4 "$target"; then
      return 0
    fi
    if [[ "$attempt" -lt 6 ]]; then
      echo "Gatekeeper 尚未接受（第 ${attempt}/6 次），20 秒后重试..."
      sleep 20
    fi
  done
  die "Gatekeeper 拒绝了 $target"
}

verify_distributed() {
  echo "钉合公证票据"
  staple_with_retry "$DMG"
  echo "挂载 DMG 并验证其中的应用"
  mount_dmg
  find_mounted_app
  codesign --verify --deep --strict --verbose=2 "$MOUNTED_APP"
  codesign --display --verbose=4 "$MOUNTED_APP"
  assess_gatekeeper execute "$MOUNTED_APP"
  detach_mount
  assess_gatekeeper open "$DMG"
  codesign --verify --verbose=2 "$DMG"
}

cmd_check() {
  prepare_plan
  printf '%s\n' "$PLAN"
}

cmd_sign_app() {
  prepare_plan
  if [[ "$PLAN" == "skip" ]]; then
    echo "未配置 Apple 签名 secrets，跳过签名，继续使用未签名构建。"
    note_summary "macOS：未配置签名 secrets，产物未签名、未公证。"
    return 0
  fi
  APP=$(abs_path_existing "$1") || die "找不到应用: $1"
  echo "准备签名: $APP"
  start_secure_workspace
  import_certificate
  clean_app_metadata
  sign_nested_code
  verify_signed_app
  note_summary "macOS：已用 Developer ID 签名（Hardened Runtime）。"
}

cmd_notarize_dmg() {
  prepare_plan
  if [[ "$PLAN" == "skip" ]]; then
    echo "未配置 Apple 签名 secrets，跳过 DMG 签名和公证。"
    return 0
  fi
  DMG=$(abs_path_existing "$1") || die "找不到 DMG: $1"
  APP=$(abs_path_existing "$2") || die "找不到应用: $2"
  echo "准备公证: $DMG"
  start_secure_workspace
  import_certificate
  build_notary_args
  ensure_dmg_contains_signed_app
  sign_dmg
  submit_for_notarization
  verify_distributed
  note_summary "macOS：DMG 已用 Developer ID 签名、公证并 staple。Gatekeeper 检查已通过。"
}

main() {
  local cmd="${1:-}"
  if [[ $# -gt 0 ]]; then
    shift
  fi
  case "$cmd" in
    check)
      [[ $# -eq 0 ]] || die "check 不接受参数"
      cmd_check
      ;;
    sign-app)
      [[ $# -eq 1 ]] || die "用法: $0 sign-app <kelivo.app>"
      cmd_sign_app "$1"
      ;;
    notarize-dmg)
      [[ $# -eq 2 ]] || die "用法: $0 notarize-dmg <file.dmg> <kelivo.app>"
      cmd_notarize_dmg "$1" "$2"
      ;;
    -h | --help | help)
      usage
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
