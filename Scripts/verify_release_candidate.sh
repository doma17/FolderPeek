#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
mkdir -p .omx/evidence/release-finish

rc_out="$root/.build/manual"
evidence_out="$root/.build/manual-evidence"
rc_binary="$rc_out/FolderPeek.app/Contents/PlugIns/FolderPeekPreview.appex/Contents/MacOS/FolderPeekPreview"
evidence_binary="$evidence_out/FolderPeek.app/Contents/PlugIns/FolderPeekPreview.appex/Contents/MacOS/FolderPeekPreview"
rc_icon="$rc_out/FolderPeek.app/Contents/Resources/FolderPeek.icns"

./Scripts/build_manual_app_bundle.sh > .omx/evidence/release-finish/rc-build.log 2>&1
if strings "$rc_binary" | grep -F 'FolderPeekEvidence' > .omx/evidence/release-finish/rc-evidence-marker.log; then
  echo "FAILED: default release-candidate bundle contains FolderPeekEvidence marker" >&2
  exit 1
fi
: > .omx/evidence/release-finish/rc-evidence-marker.log

test -f "$rc_icon"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$rc_out/FolderPeek.app/Contents/Info.plist" | grep -Fx 'FolderPeek' > .omx/evidence/release-finish/rc-icon-key.log
file "$rc_icon" > .omx/evidence/release-finish/rc-icon-file.log

FOLDERPEEK_EVIDENCE=1 FOLDERPEEK_MANUAL_BUILD_OUT="$evidence_out" ./Scripts/build_manual_app_bundle.sh > .omx/evidence/release-finish/evidence-build.log 2>&1
strings "$evidence_binary" | grep -F 'FolderPeekEvidence' > .omx/evidence/release-finish/evidence-marker.log

echo "FolderPeek release-candidate artifact verification passed"
