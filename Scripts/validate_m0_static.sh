#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
ARCH="${ARCH:-$(uname -m)}"
MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-12.0}"
plutil -lint FolderPeek/Host/Info.plist FolderPeek/QuickLookExtension/Info.plist FolderPeek/Host/FolderPeek.entitlements FolderPeek/QuickLookExtension/FolderPeekPreview.entitlements
python3 - <<'PY'
import plistlib
from pathlib import Path

info = plistlib.loads(Path("FolderPeek/QuickLookExtension/Info.plist").read_bytes())
types = set(info["NSExtension"]["NSExtensionAttributes"]["QLSupportedContentTypes"])
required = {"public.folder", "public.directory", "public.zip-archive", "public.tar-archive"}
missing = sorted(required - types)
if missing:
    raise SystemExit(f"missing Quick Look content type(s): {', '.join(missing)}")
PY
swiftc -typecheck -target "$ARCH-apple-macosx$MACOSX_DEPLOYMENT_TARGET" -framework AppKit -framework QuickLookThumbnailing FolderPeek/Shared/ArchiveCore.swift FolderPeek/Shared/PreviewCore.swift FolderPeek/Shared/PreviewHTMLRenderer.swift FolderPeek/Shared/ThumbnailPipeline.swift
swiftc -typecheck -target "$ARCH-apple-macosx$MACOSX_DEPLOYMENT_TARGET" -framework Cocoa -framework QuickLookUI -framework QuickLookThumbnailing -framework UniformTypeIdentifiers FolderPeek/Shared/ArchiveCore.swift FolderPeek/Shared/PreviewCore.swift FolderPeek/Shared/PreviewHTMLRenderer.swift FolderPeek/Shared/ThumbnailPipeline.swift FolderPeek/QuickLookExtension/PreviewProvider.swift
swiftc -typecheck -target "$ARCH-apple-macosx$MACOSX_DEPLOYMENT_TARGET" -framework SwiftUI -framework AppKit FolderPeek/Host/FolderPeekApp.swift FolderPeek/Host/ContentView.swift FolderPeek/Host/MenuBarController.swift
