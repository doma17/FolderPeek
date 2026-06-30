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
   - Expect FolderPeek archive preview UI with a flat internal listing, positive entry count, and no extraction.
8. Select `nested-unicode-archive.zip` or `.tar` and press Space.
   - Expect nested paths, spaces, and Unicode names to appear in the same flat archive listing; no tree UI and no extraction.
9. Select `dev-looking-folder` and press Space.
   - Expect ordinary folder content preview, no README/package/project summary.
10. Select `stale-refresh-folder`, preview it, change `changing.txt`, reopen preview.
   - Record whether snapshot refreshes or stale behavior appears.
11. Launch FolderPeek and open the menu bar item.
   - Expect the status item to be the primary management surface, with Open FolderPeek Guide…, Quick Look Setup Check…, Close Window, About FolderPeek, and Quit FolderPeek.
   - Confirm launching FolderPeek shows no window automatically.
   - Confirm Open FolderPeek Guide… and Quick Look Setup Check… reuse one tabbed help window with the requested tab selected. Confirm Command-W closes that window and Command-Q quits FolderPeek.
   - Confirm the help window uses the app icon, blue pill tabs/buttons, and a single Open Extension Settings button.
   - Confirm there is no background indexing prompt, repair action, permission prompt, or preview history surface.
12. If external/removable storage is available, copy `small-mixed-folder` there and repeat preview.
13. Fill `.omx/plans/m0-feasibility-evidence-template-folderpeek.md` or copy it to `.omx/evidence/m0/` with screenshots/logs.
CHECKLIST
