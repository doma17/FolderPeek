#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
fixtures="Fixtures/Verification"
[ -d "$fixtures" ] || ./Scripts/create_test_fixtures.sh >/dev/null

fail() { echo "FAILED: $*" >&2; exit 1; }
[ -d "$fixtures/empty-folder" ] || fail "empty-folder missing"
[ -d "$fixtures/small-mixed-folder/Subfolder" ] || fail "small mixed subfolder missing"
[ "$(find "$fixtures/large-mixed-folder" -maxdepth 1 -type f | wc -l | tr -d ' ')" -gt 150 ] || fail "large folder should have >150 files"
[ "$(find "$fixtures/visual-folder" -maxdepth 1 -name '*.jpg' | wc -l | tr -d ' ')" -ge 12 ] || fail "visual folder jpg count"
[ -f "$fixtures/archive-containing-folder/materials.zip" ] || fail "zip fixture missing"
[ -f "$fixtures/archive-containing-folder/export.tar" ] || fail "tar fixture missing"
[ -f "$fixtures/small-archive.zip" ] || fail "selected zip archive fixture missing"
[ -f "$fixtures/small-archive.tar" ] || fail "selected tar archive fixture missing"
LC_ALL=C /usr/bin/bsdtar -tvf "$fixtures/small-archive.zip" >/dev/null || fail "selected zip archive is not listable with bsdtar contract"
LC_ALL=C /usr/bin/bsdtar -tvf "$fixtures/small-archive.tar" >/dev/null || fail "selected tar archive is not listable with bsdtar contract"
[ -f "$fixtures/nested-unicode-archive.zip" ] || fail "nested unicode zip archive fixture missing"
[ -f "$fixtures/nested-unicode-archive.tar" ] || fail "nested unicode tar archive fixture missing"
LC_ALL=C /usr/bin/bsdtar -tvf "$fixtures/nested-unicode-archive.zip" >/dev/null || fail "nested unicode zip archive is not listable"
LC_ALL=C /usr/bin/bsdtar -tvf "$fixtures/nested-unicode-archive.tar" >/dev/null || fail "nested unicode tar archive is not listable"
[ -f "$fixtures/large-archive.zip" ] || fail "large zip archive fixture missing"
[ -f "$fixtures/large-archive.tar" ] || fail "large tar archive fixture missing"
[ "$(LC_ALL=C /usr/bin/bsdtar -tvf "$fixtures/large-archive.zip" | wc -l | tr -d ' ')" -ge 250 ] || fail "large zip archive should contain >=250 entries"
[ "$(LC_ALL=C /usr/bin/bsdtar -tvf "$fixtures/large-archive.tar" | wc -l | tr -d ' ')" -ge 250 ] || fail "large tar archive should contain >=250 entries"
[ -f "$fixtures/corrupt-archive.zip" ] || fail "corrupt zip archive fixture missing"
[ -f "$fixtures/corrupt-archive.tar" ] || fail "corrupt tar archive fixture missing"
if LC_ALL=C /usr/bin/bsdtar -tvf "$fixtures/corrupt-archive.zip" >/dev/null 2>&1; then fail "corrupt zip archive should not be listable"; fi
if LC_ALL=C /usr/bin/bsdtar -tvf "$fixtures/corrupt-archive.tar" >/dev/null 2>&1; then fail "corrupt tar archive should not be listable"; fi
[ -f "$fixtures/dev-looking-folder/package.json" ] || fail "package fixture missing"
[ -d "$fixtures/dev-looking-folder/src" ] || fail "src fixture missing"
[ -f "$fixtures/thumbnail-failure-folder/corrupt.jpg" ] || fail "thumbnail failure fixture missing"
[ -f "$fixtures/stale-refresh-folder/changing.txt" ] || fail "stale refresh fixture missing"

echo "FolderPeek verification fixtures passed"
