# M0 Runtime Runbook — FolderPeek Quick Look Feasibility

This runbook records the strict Quick Look path for FolderPeek's MVP: a macOS Quick Look Preview Extension registered for folders, invoked by Quick Look, and rendering a static folder-contents recognition preview without opening Finder folders.

## Purpose

Prove or fail the product-critical question:

> Can FolderPeek provide a custom Quick Look preview for user-browsable folders using `public.folder` / `public.directory`, and can selected zip/tar archives reach the same data-based provider?

A failed run is useful evidence. Do not silently pivot to a Finder-adjacent companion app; the fallback requires explicit user approval per the PRD.

## Current M0 Decision

**PASS — strict Quick Look path is viable via a data-based `QLPreviewProvider`.**

Passing runtime mechanism:

- Extension point: `com.apple.quicklook.preview`
- Principal class: `$(PRODUCT_MODULE_NAME).PreviewProvider`
- Data-based preview flag: `QLIsDataBasedPreview = true`
- Supported content types:
  - `public.folder`
  - `public.directory`
  - `public.zip-archive`
  - `public.tar-archive`
- Runtime proof: `qlmanage -p -c public.folder <fixture-folder>` launches `FolderPeekPreview` and invokes `providePreview`; `qlmanage -p -c public.zip-archive` and `qlmanage -p -c public.tar-archive` also reach `PreviewProvider`.

The earlier view-controller prototype is retained as archived source only; it is **not** compiled into the passing MVP extension build and is **not** the passing M0 path in this environment. Archive listing is handled by in-process zip/tar metadata parsers in the data-based Quick Look provider, so normal archive fixtures must render ready flat listings inside the sandbox. System archive tools are used only by fixture creation/oracle scripts outside the shipping preview path.

## Prerequisites

- Full Xcode installed in `/Applications/Xcode.app`.
- Active developer directory points to Xcode:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version
```

Current status after admin license acceptance: conventional `xcodebuild` now works. Verified commands include `xcodebuild -list`, Debug build, Release build, and signed Debug/Release local builds. The manual `swiftc` path remains useful as a deterministic verifier-only packaging path.

## Project Layout

### Host App Target

- Target name: `FolderPeek`
- Bundle id: `com.folderpeek.app`
- Sources:
  - `FolderPeek/Host/FolderPeekApp.swift`
  - `FolderPeek/Host/ContentView.swift`
  - `FolderPeek/Host/MenuBarController.swift`
- Info plist: `FolderPeek/Host/Info.plist`
- Entitlements: `FolderPeek/Host/FolderPeek.entitlements`

### Quick Look Preview Extension Target

- Target name: `FolderPeekPreview`
- Bundle id: `com.folderpeek.app.preview`
- Passing provider source:
  - `FolderPeek/QuickLookExtension/PreviewProvider.swift`
- Archived non-shipping prototype source:
  - `FolderPeek/QuickLookExtension/PreviewViewController.swift`
- Shared sources:
  - `FolderPeek/Shared/ArchiveCore.swift`
  - `FolderPeek/Shared/PreviewCore.swift`
  - `FolderPeek/Shared/PreviewHTMLRenderer.swift`
  - `FolderPeek/Shared/ThumbnailPipeline.swift`
- Info plist: `FolderPeek/QuickLookExtension/Info.plist`
- Entitlements: `FolderPeek/QuickLookExtension/FolderPeekPreview.entitlements`

## Local Preflight

```sh
./Scripts/create_test_fixtures.sh
./Scripts/verify_fixtures.sh
./Scripts/validate_m0_static.sh
./Scripts/test_core_smoke.sh
swift build
```

These prove plist validity, Swift typechecking, shared-core behavior, fixture shape, and SwiftPM library health.

## Manual Bundle Runtime Path

Build the host app and extension with the Xcode toolchain, expand plists, and sign ad-hoc:

```sh
./Scripts/build_manual_app_bundle.sh
```

This produces the logging-free local RC tester app at `.build/manual/FolderPeek.app`.

Install or refresh the built app:

```sh
./Scripts/install_local_app.sh
```

A healthy local install should print exactly one `com.folderpeek.app.preview` registration pointing at `/Applications/FolderPeek.app/Contents/PlugIns/FolderPeekPreview.appex`. If old verification or `/Applications` copies remain registered, unregister their `.appex` paths and reset Quick Look before testing Finder again.

Manual equivalent:

```sh
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

The `.appex` binary must be a Mach-O executable with `_NSExtensionMain`, not a dylib; the build script enforces this. The default `.build/manual/FolderPeek.app` release-candidate bundle does **not** define `FOLDERPEEK_EVIDENCE`. `Scripts/verify_quicklook_runtime.sh` builds a separate `.build/manual-evidence/FolderPeek.app` with `FOLDERPEEK_EVIDENCE=1` so folder names/paths are emitted only for local evidence collection.

## Automated Runtime Verification

```sh
./Scripts/verify_release_candidate.sh
./Scripts/verify_quicklook_runtime.sh
```

`verify_release_candidate.sh` proves the default RC bundle has no `FolderPeekEvidence` marker while the separate evidence bundle does. `verify_quicklook_runtime.sh` invokes `qlmanage -p -c public.folder` for folder fixtures plus `qlmanage -p -c public.zip-archive` and `qlmanage -p -c public.tar-archive` for selected archive fixtures, captures unified logs, and requires these `FolderPeekEvidence` outcomes:

- `small-mixed-folder`: `state=ready`
- `large-mixed-folder`: `state=partial items=30 partial=true`
- `empty-folder`: `state=empty`
- `visual-folder`: `state=ready`
- `archive-containing-folder`: `state=ready`
- `dev-looking-folder`: `state=ready`
- `thumbnail-failure-folder`: `state=ready`
- `stale-refresh-folder`: `state=ready` before and after mutation
- `permission-error-folder`: inaccessible when chmod denial is honored; otherwise the script records the volume/runtime access behavior.
- `small-archive.zip` / `small-archive.tar`: `state=ready` with a positive `entries` count; archive previews are flat, read-only metadata listings with no extraction.

Evidence files:

- `.omx/evidence/m0/m0-feasibility-evidence-folderpeek.md`
- `.omx/evidence/core/quicklook-runtime-verification.log`
- `.omx/evidence/core/quicklook-runtime-unified.log`
- `.omx/evidence/core/qlmanage-runtime-*.log`

## Finder Space-key Smoke

`qlmanage` proves the Quick Look extension runtime path and folder UTI registration. Before external release, still run a human Finder smoke because synthetic Space-key automation can be blocked by local Accessibility permissions:

1. Open `Fixtures/Verification` in Finder.
2. Select `small-mixed-folder` and press Space.
3. Select `large-mixed-folder` and press Space.
4. Confirm the preview shows FolderPeek folder contents, not only default folder metadata.
5. Record the observation in the M0 evidence file.

## M0 Pass Criteria

All must be true:

1. Quick Look invokes FolderPeek custom preview for folder content through `public.folder` and/or `public.directory`.
2. The extension reads enough top-level entries to show a useful recognition sample.
3. `small-mixed-folder` produces a useful preview.
4. `large-mixed-folder` shows bounded/partial disclosure.
5. Empty, unsupported, or access-error cases do not crash.
6. Freshness/caching behavior is acceptable or clearly mitigated with snapshot-on-open messaging.

## M0 Fail Criteria

Any fails the Quick Look path:

1. Quick Look does not invoke the custom preview reliably.
2. Folder/directory type registration is rejected or overridden by system behavior.
3. Extension sandbox/access prevents useful top-level enumeration for ordinary folders.
4. Caching/lifecycle behavior makes the preview misleading with no acceptable mitigation.

## After Runtime Decision

- If PASS: continue Quick Look extension-first MVP.
- If FAIL: stop implementation and ask for explicit approval to switch to a Finder-adjacent companion fallback.
