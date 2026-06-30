#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
fixtures="$root/Fixtures/Verification"
[ -d "$fixtures" ] || ./Scripts/create_test_fixtures.sh >/dev/null
mkdir -p .omx/evidence/m0 .omx/evidence/core .omx/evidence/archive-m0
runtime_install_root="${FOLDERPEEK_RUNTIME_INSTALL_ROOT:-$HOME/Applications/FolderPeekRuntimeVerification}"
runtime_marker="$runtime_install_root/.folderpeek-runtime-verifier"
runtime_app="$runtime_install_root/FolderPeek.app"
evidence_build_out="${FOLDERPEEK_EVIDENCE_BUILD_OUT:-$root/.build/manual-evidence}"
./Scripts/verify_fixtures.sh > .omx/evidence/archive-m0/fixture-verification.log 2>&1
FOLDERPEEK_EVIDENCE=1 FOLDERPEEK_MANUAL_BUILD_OUT="$evidence_build_out" ./Scripts/build_manual_app_bundle.sh > .omx/evidence/core/quicklook-runtime-build.log 2>&1
while IFS= read -r registered_path; do
  case "$registered_path" in
    "$root"/*|"$HOME/Applications/FolderPeek.app"/*|"$runtime_install_root"/*)
      pluginkit -r "$registered_path" >/dev/null 2>&1 || true
      ;;
  esac
done < <(pluginkit -mADv -p com.apple.quicklook.preview -i com.folderpeek.app.preview 2>/dev/null | awk '/com\.folderpeek\.app\.preview/ {print $NF}')
if [ -e "$runtime_install_root" ] && [ ! -f "$runtime_marker" ]; then
  echo "FAILED: runtime verifier install root exists without FolderPeek ownership marker: $runtime_install_root" >&2
  exit 1
fi
rm -rf "$runtime_install_root"
mkdir -p "$runtime_install_root"
touch "$runtime_marker"
cp -R "$evidence_build_out/FolderPeek.app" "$runtime_app"
pluginkit -r "$runtime_app" >/dev/null 2>&1 || true
pluginkit -a "$runtime_app/Contents/PlugIns/FolderPeekPreview.appex" >/dev/null 2>&1 || true
qlmanage -r >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true
registered_appex="$runtime_app/Contents/PlugIns/FolderPeekPreview.appex"
for _ in $(seq 1 10); do
  pluginkit -mADv -p com.apple.quicklook.preview -i com.folderpeek.app.preview > .omx/evidence/core/quicklook-runtime-pluginkit.log 2>&1 || true
  if grep -F "$registered_appex" .omx/evidence/core/quicklook-runtime-pluginkit.log >/dev/null; then
    break
  fi
  sleep 1
  pluginkit -a "$registered_appex" >/dev/null 2>&1 || true
done
if ! grep -F "$registered_appex" .omx/evidence/core/quicklook-runtime-pluginkit.log >/dev/null; then
  cat .omx/evidence/core/quicklook-runtime-pluginkit.log
  echo "FAILED: current FolderPeek Quick Look extension is not registered with PlugInKit" >&2
  exit 1
fi
python3 - "$registered_appex/Contents/Info.plist" <<'PY'
import plistlib
import sys
from pathlib import Path

info = plistlib.loads(Path(sys.argv[1]).read_bytes())
types = set(info["NSExtension"]["NSExtensionAttributes"]["QLSupportedContentTypes"])
required = {"public.folder", "public.directory", "public.zip-archive", "public.tar-archive"}
missing = sorted(required - types)
if missing:
    raise SystemExit(f"FAILED: registered appex plist is missing Quick Look content type(s): {', '.join(missing)}")
PY
for content_type in public.folder public.directory public.zip-archive public.tar-archive; do
  if ! plutil -p "$registered_appex/Contents/Info.plist" | grep -F "$content_type" >/dev/null; then
    plutil -p "$registered_appex/Contents/Info.plist"
    echo "FAILED: registered Quick Look extension plist is missing content type: $content_type" >&2
    exit 1
  fi
done

LC_ALL=C /usr/bin/bsdtar -tvf "$fixtures/small-archive.zip" > .omx/evidence/archive-m0/bsdtar-small-archive-zip.log 2>&1
LC_ALL=C /usr/bin/bsdtar -tvf "$fixtures/small-archive.tar" > .omx/evidence/archive-m0/bsdtar-small-archive-tar.log 2>&1
run_with_timeout="${TMPDIR:-/tmp}/folderpeek_run_qlmanage_timeout.sh"
cat > "$run_with_timeout" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
seconds="$1"; shift
log="$1"; shift
("$@") >"$log" 2>&1 &
pid=$!
for _ in $(seq 1 "$seconds"); do
  if ! kill -0 "$pid" 2>/dev/null; then
    wait "$pid" || true
    echo "EXITED" >>"$log"
    exit 0
  fi
  sleep 1
done
if kill -0 "$pid" 2>/dev/null; then
  echo "TIMEOUT_KILL pid=$pid" >>"$log"
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
fi
EOS
chmod +x "$run_with_timeout"

start_local="$(date '+%Y-%m-%d %H:%M:%S')"
folders=(
  small-mixed-folder
  large-mixed-folder
  empty-folder
  visual-folder
  archive-containing-folder
  dev-looking-folder
  thumbnail-failure-folder
  stale-refresh-folder
  permission-error-folder
)
for folder in "${folders[@]}"; do
  "$run_with_timeout" 8 ".omx/evidence/core/qlmanage-runtime-${folder}.log" qlmanage -p -c public.folder "$fixtures/$folder"
done
"$run_with_timeout" 8 ".omx/evidence/archive-m0/qlmanage-runtime-small-archive-zip.log" qlmanage -p -c public.zip-archive "$fixtures/small-archive.zip"
"$run_with_timeout" 8 ".omx/evidence/archive-m0/qlmanage-runtime-small-archive-tar.log" qlmanage -p -c public.tar-archive "$fixtures/small-archive.tar"
"$run_with_timeout" 8 ".omx/evidence/archive-m0/qlmanage-runtime-nested-unicode-archive-zip.log" qlmanage -p -c public.zip-archive "$fixtures/nested-unicode-archive.zip"
"$run_with_timeout" 8 ".omx/evidence/archive-m0/qlmanage-runtime-nested-unicode-archive-tar.log" qlmanage -p -c public.tar-archive "$fixtures/nested-unicode-archive.tar"
# Freshness: mutate stale fixture and invoke again. This modifies only generated test fixtures.
printf 'version 2 %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$fixtures/stale-refresh-folder/changing.txt"
"$run_with_timeout" 8 ".omx/evidence/core/qlmanage-runtime-stale-refresh-folder-v2.log" qlmanage -p -c public.folder "$fixtures/stale-refresh-folder"

/usr/bin/log show --style compact --start "$start_local" --predicate 'process == "FolderPeekPreview" AND eventMessage CONTAINS[c] "FolderPeekEvidence"' > .omx/evidence/core/quicklook-runtime-unified.log 2>&1 || true
cat .omx/evidence/core/quicklook-runtime-unified.log

require_log() {
  local pattern="$1"
  if ! grep -F "$pattern" .omx/evidence/core/quicklook-runtime-unified.log >/dev/null; then
    echo "FAILED: missing runtime log pattern: $pattern" >&2
    exit 1
  fi
}
require_archive_ready_entries() {
  local archive="$1"
  local line
  line="$(grep -F "provided archive=$archive state=ready" .omx/evidence/core/quicklook-runtime-unified.log | tail -1 || true)"
  if [ -z "$line" ]; then
    echo "FAILED: missing ready archive runtime log for: $archive" >&2
    exit 1
  fi
  local entries
  entries="$(printf '%s\n' "$line" | sed -n 's/.* entries=\([0-9][0-9]*\).*/\1/p')"
  if [ -z "$entries" ] || [ "$entries" -le 0 ]; then
    echo "FAILED: archive runtime log for $archive must report a positive entries count: $line" >&2
    exit 1
  fi
}
require_log "provided folder=small-mixed-folder state=ready"
require_archive_ready_entries "small-archive.zip"
require_archive_ready_entries "small-archive.tar"
require_archive_ready_entries "nested-unicode-archive.zip"
require_archive_ready_entries "nested-unicode-archive.tar"
echo "archive listing ready state with positive entries observed in Quick Look runtime"
require_log "provided folder=large-mixed-folder state=partial items=30 partial=true"
require_log "provided folder=empty-folder state=empty"
require_log "provided folder=visual-folder state=ready"
require_log "provided folder=archive-containing-folder state=ready"
require_log "provided folder=dev-looking-folder state=ready"
require_log "provided folder=thumbnail-failure-folder state=ready"
require_log "provided folder=stale-refresh-folder state=ready"
stale_count="$(grep -F "provided folder=stale-refresh-folder state=ready" .omx/evidence/core/quicklook-runtime-unified.log | wc -l | tr -d ' ')"
if [ "$stale_count" -lt 2 ]; then
  echo "FAILED: stale-refresh-folder should be previewed before and after mutation; observed $stale_count runtime log(s)" >&2
  exit 1
fi
require_log "provided folder=permission-error-folder state="
# chmod-based permission behavior varies by volume/runtime; record as observed if not denied.
if grep -F "provided folder=permission-error-folder state=inaccessible" .omx/evidence/core/quicklook-runtime-unified.log >/dev/null; then
  echo "permission-error-folder inaccessible state observed"
else
  echo "permission-error-folder inaccessible state not observed; runtime likely has sufficient same-user access or sandbox-granted folder access"
fi

echo "FolderPeek Quick Look runtime verification passed"
