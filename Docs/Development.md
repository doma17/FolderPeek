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

M0 decision: **PASS** via `qlmanage -p -c public.folder` and unified `FolderPeekEvidence` logs. Archive content types also invoke the same data-based provider for `public.zip-archive` and `public.tar-archive`; normal zip/tar fixtures now render bounded, flat archive listings in the sandboxed Quick Look extension through in-process metadata parsers. System archive tools remain fixture/oracle helpers only and are not part of the shipping archive preview path. Manual Finder Space-key smoke remains recommended before external release.

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

After admin license acceptance, conventional Xcode builds are verified. There are now two local manual bundle modes:

- **Release-candidate tester bundle**: `./Scripts/build_manual_app_bundle.sh` writes `.build/manual/FolderPeek.app` without `FOLDERPEEK_EVIDENCE`. This is the bundle to copy to `/Applications/FolderPeek.app` for local testing.
- **Runtime verifier bundle**: `FOLDERPEEK_EVIDENCE=1 FOLDERPEEK_MANUAL_BUILD_OUT=.build/manual-evidence ./Scripts/build_manual_app_bundle.sh` writes a separate evidence-enabled app for `Scripts/verify_quicklook_runtime.sh`.

Install or refresh the local RC tester bundle:

```sh
./Scripts/install_local_app.sh
```

The installer builds `.build/manual/FolderPeek.app`, replaces `/Applications/FolderPeek.app`, registers the copied app with LaunchServices, registers the bundled Quick Look extension, resets Quick Look, and prints the active PlugInKit registration. A healthy local install should show one `com.folderpeek.app.preview` entry pointing at `/Applications/FolderPeek.app/Contents/PlugIns/FolderPeekPreview.appex`. If stale duplicate entries appear from `~/Applications/FolderPeek.app` or `~/Applications/FolderPeekRuntimeVerification`, unregister those `.appex` paths and reset Quick Look again.

Manual equivalent:

```sh
./Scripts/build_manual_app_bundle.sh
rm -rf /Applications/FolderPeek.app
cp -R .build/manual/FolderPeek.app /Applications/FolderPeek.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/FolderPeek.app
pluginkit -r /Applications/FolderPeek.app || true
pluginkit -a /Applications/FolderPeek.app
pluginkit -a /Applications/FolderPeek.app/Contents/PlugIns/FolderPeekPreview.appex
qlmanage -r
qlmanage -r cache
pluginkit -mADv -p com.apple.quicklook.preview -i com.folderpeek.app.preview
```

Run verifier-only runtime evidence separately:

```sh
./Scripts/verify_release_candidate.sh
./Scripts/verify_quicklook_runtime.sh
```

Expected proof point: unified logs from the evidence build include `FolderPeekEvidence provided folder=<fixture> state=<state> ...` for every fixture covered by the verifier. These evidence logs are compiled only when `FOLDERPEEK_EVIDENCE=1`; do not enable them for the default RC bundle because folder names and paths are user data.

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

The host app installs a lightweight `NSStatusItem` menu bar surface on launch and uses accessory-style app posture so the status item is the primary management affordance. It is host-only: it does not replace Finder Quick Look, does not index folders, and does not retain Quick Look models. Expected menu actions are Open FolderPeek Guide…, Quick Look Setup Check…, Close Window, About FolderPeek, and Quit FolderPeek. Command-W closes the help window and Command-Q quits FolderPeek. No window is shown automatically on launch. The two help actions open one unified tabbed help window with the requested initial tab selected: Guide for first-use flow and Quick Look Check for troubleshooting/privacy/contact. The redesigned window follows `Docs/Design.md`: app-icon-led header, low-density parchment canvas, white utility cards, blue pill tabs/buttons, 17px body copy, and no decorative shadows. `MenuBarExtra` remains deferred while the deployment target is macOS 12.0.

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
