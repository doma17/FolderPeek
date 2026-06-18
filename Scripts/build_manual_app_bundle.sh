#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SWIFTC="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
SDK="$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
ARCH="${ARCH:-$(uname -m)}"
MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-12.0}"
OUT="$root/.build/manual"
APP="$OUT/FolderPeek.app"
APPEX="$APP/Contents/PlugIns/FolderPeekPreview.appex"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/PlugIns" "$APPEX/Contents/MacOS"

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
  -D FOLDERPEEK_EVIDENCE \
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

python3 - <<'PY'
from pathlib import Path
import plistlib
root=Path('.').resolve()
app=root/'.build/manual/FolderPeek.app'
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
