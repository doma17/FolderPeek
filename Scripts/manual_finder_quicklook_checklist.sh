#!/usr/bin/env bash
set -euo pipefail
cat <<'CHECKLIST'
# Manual Finder Quick Look Checklist — FolderPeek

Prerequisite: full Xcode selected and FolderPeek host app + Quick Look extension built, signed, installed, and enabled.

1. Run `Scripts/create_test_fixtures.sh`.
2. Open `Fixtures/Verification` in Finder.
3. Select `small-mixed-folder` and press Space.
   - Expect FolderPeek preview UI with header, summary, type chips, thumbnails/icons, and sampled contents.
4. Select `large-mixed-folder` and press Space.
   - Expect partial/sample disclosure and bounded item list.
5. Select `empty-folder` and press Space.
   - Expect empty state.
6. Select `archive-containing-folder` and press Space.
   - Expect zip/tar listed as archive files only, no internal tree.
7. Select `small-archive.zip` and press Space, then `small-archive.tar` and press Space.
   - Expect FolderPeek archive preview route. If the local Quick Look sandbox denies child `bsdtar`, expect a readable non-crashing error state that says no extraction occurred.
8. Select `nested-unicode-archive.zip` or `.tar` and press Space.
   - Expect the same archive preview route/error-state behavior; no tree UI and no extraction.
9. Select `dev-looking-folder` and press Space.
   - Expect ordinary folder content preview, no README/package/project summary.
10. Select `stale-refresh-folder`, preview it, change `changing.txt`, reopen preview.
   - Record whether snapshot refreshes or stale behavior appears.
11. Launch FolderPeek and open the menu bar item.
   - Expect Open FolderPeek, Quick Look Help, About FolderPeek, and Quit FolderPeek. Confirm there is no background indexing prompt.
12. If external/removable storage is available, copy `small-mixed-folder` there and repeat preview.
13. Fill `.omx/plans/m0-feasibility-evidence-template-folderpeek.md` or copy it to `.omx/evidence/m0/` with screenshots/logs.
CHECKLIST
