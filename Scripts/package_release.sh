#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

release_version="${FOLDERPEEK_RELEASE_VERSION:-0.3}"
release_build="${FOLDERPEEK_RELEASE_BUILD:-1}"
release_name="FolderPeek-${release_version}"
manual_out="$root/.build/manual"
app="$manual_out/FolderPeek.app"
appex="$app/Contents/PlugIns/FolderPeekPreview.appex"
app_info="$app/Contents/Info.plist"
appex_info="$appex/Contents/Info.plist"
app_bin="$app/Contents/MacOS/FolderPeek"
appex_bin="$appex/Contents/MacOS/FolderPeekPreview"
release_out="$root/.build/release"
zip_path="$release_out/${release_name}.zip"
checksums_path="$release_out/SHA256SUMS.txt"
staging_root="$release_out/staging"
staging_app="$staging_root/FolderPeek.app"
verify_root="$release_out/verify-unzip"

fail() {
  echo "FAILED: $*" >&2
  exit 1
}

read_plist() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1"
}

mkdir -p "$release_out"
rm -rf "$staging_root" "$verify_root" "$zip_path" "$checksums_path"

./Scripts/build_manual_app_bundle.sh >/dev/null

test -d "$app" || fail "manual app bundle was not built at $app"
test -d "$appex" || fail "Quick Look extension is missing from $app"
test -x "$app_bin" || fail "host executable is missing"
test -x "$appex_bin" || fail "Quick Look executable is missing"

host_version="$(read_plist "$app_info" CFBundleShortVersionString)"
host_build="$(read_plist "$app_info" CFBundleVersion)"
appex_version="$(read_plist "$appex_info" CFBundleShortVersionString)"
appex_build="$(read_plist "$appex_info" CFBundleVersion)"

[ "$host_version" = "$release_version" ] || fail "host version is $host_version, expected $release_version"
[ "$appex_version" = "$release_version" ] || fail "extension version is $appex_version, expected $release_version"
[ "$host_build" = "$release_build" ] || fail "host build is $host_build, expected $release_build"
[ "$appex_build" = "$release_build" ] || fail "extension build is $appex_build, expected $release_build"

if strings "$appex_bin" | grep -F 'FolderPeekEvidence' >/dev/null; then
  fail "default release bundle contains FolderPeekEvidence marker"
fi
if strings "$app_bin" | grep -F 'FolderPeekEvidence' >/dev/null; then
  fail "host bundle contains FolderPeekEvidence marker"
fi

if find "$app" -path '*/.omx/*' -o -name '*.log' -o -name '*evidence*' | grep . >/dev/null; then
  fail "release app contains evidence/log artifacts"
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --verify --deep --strict "$app" >/dev/null
fi

mkdir -p "$staging_root"
cp -R "$app" "$staging_app"
# Keep the zip artifact stable across repeated packaging runs when the
# bundle contents have not changed. zip stores file mtimes even with -X.
find "$staging_app" -exec touch -h -t 202606300000 {} +

(
  cd "$staging_root"
  /usr/bin/zip -qry -X "$zip_path" FolderPeek.app
)

test -s "$zip_path" || fail "release zip was not created"

/usr/bin/zipinfo -1 "$zip_path" > "$release_out/zip-contents.txt"
if awk -F/ 'NF && $1 != "FolderPeek.app" { bad=1 } END { exit bad ? 0 : 1 }' "$release_out/zip-contents.txt"; then
  fail "release zip contains files outside top-level FolderPeek.app"
fi
if ! grep -Fx 'FolderPeek.app/' "$release_out/zip-contents.txt" >/dev/null; then
  fail "release zip does not contain top-level FolderPeek.app"
fi

mkdir -p "$verify_root"
/usr/bin/ditto -x -k "$zip_path" "$verify_root"
test -d "$verify_root/FolderPeek.app" || fail "unzipped archive does not contain FolderPeek.app"
test -d "$verify_root/FolderPeek.app/Contents/PlugIns/FolderPeekPreview.appex" || fail "unzipped app does not contain Quick Look extension"
if [ "$(find "$verify_root" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" != "1" ]; then
  fail "unzipped archive has more than one top-level item"
fi
if command -v codesign >/dev/null 2>&1; then
  codesign --verify --deep --strict "$verify_root/FolderPeek.app" >/dev/null
fi

(
  cd "$release_out"
  shasum -a 256 "${release_name}.zip" > SHA256SUMS.txt
)

echo "Release package created: $zip_path"
echo "Checksum file created: $checksums_path"
cat "$checksums_path"
