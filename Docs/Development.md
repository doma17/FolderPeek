# FolderPeek Development Notes

## Current Status

FolderPeek has a planning-approved MVP path and a verified strict Quick Look runtime proof:

- Presentation-agnostic core model and seams: `FolderPeek/Shared/PreviewCore.swift`.
- Bounded thumbnail pipeline: `FolderPeek/Shared/ThumbnailPipeline.swift`.
- Passing Quick Look path: data-based `QLPreviewProvider` in `FolderPeek/QuickLookExtension/PreviewProvider.swift`.
- Archived non-shipping AppKit prototype: `FolderPeek/QuickLookExtension/PreviewViewController.swift`. It is intentionally excluded from the manual extension build, Xcode source phase, and static M0 validation.
- Manual host app + `.appex` build: `Scripts/build_manual_app_bundle.sh`.
- Runtime fixture verifier: `Scripts/verify_quicklook_runtime.sh`.
- Archive preview core and shared HTML renderer: `FolderPeek/Shared/ArchiveCore.swift` and `FolderPeek/Shared/PreviewHTMLRenderer.swift`.
- Host menu bar management surface: `FolderPeek/Host/MenuBarController.swift` using macOS 12-compatible `NSStatusItem`.

M0 decision: **PASS** via `qlmanage -p -c public.folder` and unified `FolderPeekEvidence` logs. Archive content types also invoke the same data-based provider for `public.zip-archive` and `public.tar-archive`; in the sandboxed Quick Look extension, child `/usr/bin/bsdtar` execution is currently denied, so archive previews use the designed non-crashing error state while the shell-free command adapter remains covered by core tests and fixture logs. Manual Finder Space-key smoke remains recommended before external release.

## Requirements Source

- PRD: `.omx/plans/prd-folderpeek-mvp.md`
- Test spec: `.omx/plans/test-spec-folderpeek-mvp.md`
- Ralplan: `.omx/plans/ralplan-folderpeek-mvp.md`
- Ultragoal ledger: `.omx/ultragoal/ledger.jsonl`

## Local Verification

Run these before changing runtime behavior:

```sh
./Scripts/create_test_fixtures.sh
./Scripts/verify_fixtures.sh
./Scripts/validate_m0_static.sh
./Scripts/test_core_smoke.sh
swift build
```

What they prove:

- Plists and entitlements are syntactically valid.
- Shared core, thumbnail pipeline, Quick Look extension source, and host SwiftUI source typecheck.
- Core behavior is smoke-tested without XCTest dependency.
- Fixtures preserve the product-recognition scenarios.

## Strict Quick Look Runtime Verification

Prerequisite:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version
```

After admin license acceptance, conventional Xcode builds are verified. The direct Xcode `swiftc` path remains the local verifier build because it enables `FOLDERPEEK_EVIDENCE` for unified-log runtime assertions:

```sh
./Scripts/build_manual_app_bundle.sh
rm -rf ~/Applications/FolderPeek.app
cp -R .build/manual/FolderPeek.app ~/Applications/FolderPeek.app
pluginkit -r ~/Applications/FolderPeek.app
pluginkit -a ~/Applications/FolderPeek.app/Contents/PlugIns/FolderPeekPreview.appex
qlmanage -r
qlmanage -r cache
pluginkit -mADv -p com.apple.quicklook.preview -i com.folderpeek.app.preview
./Scripts/verify_quicklook_runtime.sh
```

Expected proof point: unified logs from `FolderPeekPreview` include `FolderPeekEvidence provided folder=<fixture> state=<state> ...` for every fixture covered by the verifier. These evidence logs are compiled only into the manual verifier build via `FOLDERPEEK_EVIDENCE`; do not enable them for production builds because folder names and paths are user data.

## Fixture Scripts

```sh
./Scripts/create_test_fixtures.sh
./Scripts/verify_fixtures.sh
```

Fixture groups:

- Empty folder
- Small mixed folder
- Large mixed folder
- Visual folder
- Archive-containing folder
- Dev-looking folder
- Permission-error folder where chmod is honored
- Thumbnail-failure folder
- Stale-refresh folder
- Small zip/tar archive files
- Nested/Unicode zip/tar archive files
- Large zip/tar archive files
- Corrupt zip/tar archive files

## Menu Bar Smoke

The host app installs a lightweight `NSStatusItem` menu bar surface on launch. It is host-only: it does not replace Finder Quick Look, does not index folders, and does not retain Quick Look preview models. Expected menu actions are Open FolderPeek, Quick Look Help, About FolderPeek, and Quit FolderPeek. `MenuBarExtra` remains deferred while the deployment target is macOS 12.0.

## Manual Finder Smoke

```sh
./Scripts/manual_finder_quicklook_checklist.sh
```

This is still useful because `qlmanage` proves the Quick Look runtime path, while a human Finder Space-key pass proves the end-user trigger in the local desktop environment.

## Non-goals to Preserve

- Do not expand archive files.
- Do not summarize development projects.
- Do not add cloud/AI/network analysis.
- Do not claim exact full inventory for partial samples.
- Do not mark a future external release ready without a human Finder Space-key smoke.

## Runtime and Release-Gate References

- M0 runtime runbook: `Docs/M0RuntimeRunbook.md`
- MVP release gates: `Docs/ReleaseGates.md`
- Manual Finder checklist: `Scripts/manual_finder_quicklook_checklist.sh`
