#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SWIFTC="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
SDK="$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
ARCH="${ARCH:-$(uname -m)}"
MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-12.0}"
mkdir -p "$root/.build/module-cache" "$root/.build/clang-cache"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$root/.build/clang-cache}"
export SWIFT_MODULE_CACHE_PATH="${SWIFT_MODULE_CACHE_PATH:-$root/.build/module-cache}"
OUT="${FOLDERPEEK_MANUAL_BUILD_OUT:-$root/.build/manual}"
APP="$OUT/FolderPeek.app"
APPEX="$APP/Contents/PlugIns/FolderPeekPreview.appex"
EVIDENCE_DEFINE_FLAG=""
if [ "${FOLDERPEEK_EVIDENCE:-0}" = "1" ]; then
  EVIDENCE_DEFINE_FLAG="-D FOLDERPEEK_EVIDENCE"
fi
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/PlugIns" "$APPEX/Contents/MacOS"

"$SWIFTC" \
  -target "$ARCH-apple-macosx$MACOSX_DEPLOYMENT_TARGET" \
  -sdk "$SDK" \
  -emit-executable \
  -module-name FolderPeek \
  -framework SwiftUI \
  -framework AppKit \
  FolderPeek/Host/FolderPeekApp.swift \
  FolderPeek/Host/ContentView.swift \
  FolderPeek/Host/MenuBarController.swift \
  -o "$APP/Contents/MacOS/FolderPeek"

"$SWIFTC" \
  -target "$ARCH-apple-macosx$MACOSX_DEPLOYMENT_TARGET" \
  -sdk "$SDK" \
  -emit-executable \
  -parse-as-library \
  ${EVIDENCE_DEFINE_FLAG:+$EVIDENCE_DEFINE_FLAG} \
  -module-name FolderPeekPreview \
  -framework Cocoa \
  -framework Quartz \
  -framework QuickLookUI \
  -framework QuickLookThumbnailing \
  -framework UniformTypeIdentifiers \
  -Xlinker -e -Xlinker _NSExtensionMain \
  FolderPeek/Shared/ArchiveCore.swift \
  FolderPeek/Shared/PreviewCore.swift \
  FolderPeek/Shared/PreviewHTMLRenderer.swift \
  FolderPeek/Shared/ThumbnailPipeline.swift \
  FolderPeek/QuickLookExtension/PreviewProvider.swift \
  -o "$APPEX/Contents/MacOS/FolderPeekPreview"

if [ ! -f "Assets/AppIcon/FolderPeek.icns" ]; then
  ./Scripts/generate_app_icon.py >/dev/null
fi
cp "Assets/AppIcon/FolderPeek.icns" "$APP/Contents/Resources/FolderPeek.icns"

FOLDERPEEK_APP_BUNDLE="$APP" python3 - <<'PY'
from pathlib import Path
import plistlib
import os
root=Path('.').resolve()
app=Path(os.environ['FOLDERPEEK_APP_BUNDLE'])
appex=app/'Contents/PlugIns/FolderPeekPreview.appex'

def write_info(src, dst, replacements, extra=None):
    data=plistlib.loads(Path(src).read_bytes())
    def repl(v):
        if isinstance(v, str):
            for k,val in replacements.items():
                v=v.replace(k,val)
            return v
        if isinstance(v, dict):
            return {k: repl(val) for k,val in v.items()}
        if isinstance(v, list):
            return [repl(x) for x in v]
        return v
    data=repl(data)
    if extra:
        data.update(extra)
    Path(dst).write_bytes(plistlib.dumps(data, sort_keys=False))

write_info('FolderPeek/Host/Info.plist', app/'Contents/Info.plist', {
    '$(DEVELOPMENT_LANGUAGE)': 'en',
    '$(EXECUTABLE_NAME)': 'FolderPeek',
    '$(PRODUCT_BUNDLE_IDENTIFIER)': 'com.folderpeek.app',
}, {'LSMinimumSystemVersion': '12.0', 'NSHighResolutionCapable': True})
write_info('FolderPeek/QuickLookExtension/Info.plist', appex/'Contents/Info.plist', {
    '$(DEVELOPMENT_LANGUAGE)': 'en',
    '$(EXECUTABLE_NAME)': 'FolderPeekPreview',
    '$(PRODUCT_BUNDLE_IDENTIFIER)': 'com.folderpeek.app.preview',
    '$(PRODUCT_BUNDLE_PACKAGE_TYPE)': 'XPC!',
    '$(PRODUCT_MODULE_NAME)': 'FolderPeekPreview',
}, {'LSMinimumSystemVersion': '12.0'})
PY

plutil -lint "$APP/Contents/Info.plist" "$APPEX/Contents/Info.plist"
if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - --entitlements FolderPeek/QuickLookExtension/FolderPeekPreview.entitlements "$APPEX" >/dev/null
  codesign --force --sign - --entitlements FolderPeek/Host/FolderPeek.entitlements "$APP" >/dev/null
  codesign --verify --deep --strict "$APP"
fi
printf '%s\n' "$APP"
