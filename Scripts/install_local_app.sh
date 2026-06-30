#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

app_path="${FOLDERPEEK_INSTALL_APP_PATH:-/Applications/FolderPeek.app}"
stale_appex_paths=(
  "$HOME/Applications/FolderPeek.app/Contents/PlugIns/FolderPeekPreview.appex"
  "$HOME/Applications/FolderPeekRuntimeVerification/FolderPeek.app/Contents/PlugIns/FolderPeekPreview.appex"
  "/Applications/FolderPeek.app/Contents/PlugIns/FolderPeekPreview.appex"
)

./Scripts/build_manual_app_bundle.sh

mkdir -p "$(dirname "$app_path")"
rm -rf "$app_path"
cp -R .build/manual/FolderPeek.app "$app_path"

# Remove older per-user copies that can make LaunchServices open a stale build
# when the user launches "FolderPeek.app" by app name.
if [ "$app_path" = "/Applications/FolderPeek.app" ]; then
  rm -rf "$HOME/Applications/FolderPeek.app"
  rm -rf "$HOME/Applications/FolderPeekRuntimeVerification/FolderPeek.app"
fi

lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$lsregister" ]; then
  "$lsregister" -f "$app_path"
fi

# Keep the current local install as the only expected FolderPeek Quick Look
# registration. Stale verification/system copies can otherwise keep winning
# PlugInKit selection depending on local launch history.
pluginkit -r "$app_path" >/dev/null 2>&1 || true
for stale_appex in "${stale_appex_paths[@]}"; do
  if [ -e "$stale_appex" ]; then
    pluginkit -r "$stale_appex" >/dev/null 2>&1 || true
  fi
done
pluginkit -a "$app_path"
pluginkit -a "$app_path/Contents/PlugIns/FolderPeekPreview.appex"
qlmanage -r
qlmanage -r cache

sleep 1
pluginkit -mADv -p com.apple.quicklook.preview -i com.folderpeek.app.preview
printf '\nInstalled FolderPeek at %s\n' "$app_path"
