#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

plutil -lint FolderPeek/Host/Info.plist FolderPeek/QuickLookExtension/Info.plist FolderPeek/Host/FolderPeek.entitlements FolderPeek/QuickLookExtension/FolderPeekPreview.entitlements >/dev/null

if ! grep -F '<key>com.apple.security.app-sandbox</key>' FolderPeek/Host/FolderPeek.entitlements >/dev/null; then
  echo "FAILED: host app sandbox entitlement is required for App Store readiness" >&2
  exit 1
fi
if ! grep -F '<key>com.apple.security.app-sandbox</key>' FolderPeek/QuickLookExtension/FolderPeekPreview.entitlements >/dev/null; then
  echo "FAILED: Quick Look extension sandbox entitlement is required for App Store readiness" >&2
  exit 1
fi
if ! grep -F '<key>LSUIElement</key>' FolderPeek/Host/Info.plist >/dev/null; then
  echo "FAILED: host app should remain menu-bar-primary for this release" >&2
  exit 1
fi
if ! test -s Assets/AppIcon/FolderPeek.icns || ! test -s Assets/AppIcon/FolderPeekAppIcon-1024.png; then
  echo "FAILED: App Store icon assets are missing" >&2
  exit 1
fi
if grep -R -- "-D FOLDERPEEK_EVIDENCE" FolderPeek/Host FolderPeek/QuickLookExtension FolderPeek/Shared >/dev/null; then
  echo "FAILED: shipping source must not force evidence-only runtime logging flags" >&2
  exit 1
fi
if ! grep -F "#if FOLDERPEEK_EVIDENCE" FolderPeek/QuickLookExtension/PreviewProvider.swift >/dev/null; then
  echo "FAILED: evidence logging boundary should stay compile-time gated" >&2
  exit 1
fi
if ! grep -F "does not collect data" Docs/AppStoreMetadataDraft.md >/dev/null; then
  echo "FAILED: App Store metadata draft must include privacy copy" >&2
  exit 1
fi
if ! grep -F "rovin1273@gmail.com" Docs/AppStoreSubmission.md Docs/AppStoreMetadataDraft.md >/dev/null; then
  echo "FAILED: App Store submission docs must include support contact" >&2
  exit 1
fi

echo "FolderPeek App Store readiness static checks passed"
