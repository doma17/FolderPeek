# FolderPeek MVP Release Gates

These gates convert the PRD/test-spec into concrete evidence requirements.

## Gate 0 — Planning Consensus

Status: complete.

Evidence:

- `.omx/plans/prd-folderpeek-mvp.md`
- `.omx/plans/test-spec-folderpeek-mvp.md`
- `.omx/plans/ralplan-folderpeek-mvp.md`
- `.omx/plans/ralplan-consensus-handoff-folderpeek-mvp.json`

## Gate 1 — Quick Look Runtime Feasibility

Status: complete for strict Quick Look runtime; manual Finder Space-key smoke remains recommended before external release.

Pass evidence:

- `.omx/evidence/m0/m0-feasibility-evidence-folderpeek.md`
- `FolderPeek/QuickLookExtension/Info.plist` registers `public.folder`, `public.directory`, `public.zip-archive`, and `public.tar-archive`.
- `FolderPeek/QuickLookExtension/PreviewProvider.swift` implements the only shipping MVP preview path: data-based `QLPreviewProvider`.
- `Scripts/build_manual_app_bundle.sh` produces a signed local host app and executable `.appex` for the logging-free RC tester bundle.
- `Scripts/install_local_app.sh` replaces `/Applications/FolderPeek.app`, registers the Quick Look extension, resets Quick Look, and verifies that the current local install is the active PlugInKit registration.
- `Scripts/verify_release_candidate.sh` proves the RC bundle lacks `FolderPeekEvidence` while the separate evidence verifier bundle includes it.
- `pluginkit -mADv -p com.apple.quicklook.preview -i com.folderpeek.app.preview` finds the extension.
- `qlmanage -p -c public.folder`, `public.zip-archive`, and `public.tar-archive` invoke `FolderPeekPreview` for selected fixtures and emit `FolderPeekEvidence` unified logs only in the local verifier-only `FOLDERPEEK_EVIDENCE` build.
- Archive listing is verified by in-process core parser tests and by sandboxed Quick Look runtime logs requiring normal zip/tar fixtures to emit `state=ready` with a positive `entries` count. Fixture scripts may use system tools only as external archive oracles.

Decision: PASS. Continue Quick Look extension-first MVP; no fallback pivot.

## Gate 2 — Local Core Correctness

Status: passing.

Commands:

```sh
./Scripts/validate_m0_static.sh
./Scripts/test_core_smoke.sh
swift build
```

Evidence:

- `.omx/evidence/core/g002-preview-core-evidence.md`
- `.omx/evidence/core/g003-enumeration-classification-evidence.md`
- `.omx/evidence/core/g004-thumbnail-pipeline-evidence.md`
- `.omx/evidence/ui/g005-preview-ui-evidence.md`

## Gate 3 — Fixture and Recognition Verification

Status: passing through automated Quick Look runtime verifier.

Commands:

```sh
./Scripts/create_test_fixtures.sh
./Scripts/verify_fixtures.sh
./Scripts/verify_release_candidate.sh
./Scripts/verify_quicklook_runtime.sh
```

Runtime recognition evidence:

- `.omx/evidence/core/g006-fixtures-verification-evidence.md`
- `.omx/evidence/core/quicklook-runtime-verification.log`
- `.omx/evidence/core/quicklook-runtime-unified.log`
- `.omx/evidence/core/qlmanage-runtime-*.log`

Expected product observations:

- Small mixed folder renders a useful recognition preview.
- Large mixed folder is bounded to a partial sample and explicitly marked partial.
- Empty/inaccessible states do not crash.
- Archive-containing folders list archive files as ordinary folder contents; selected zip/tar archive files render flat, read-only internal listings with no extraction. Development-looking folders remain ordinary folder previews with no project intelligence.

## Gate 4 — Final Quality Gate

Required before aggregate goal completion:

1. Targeted verification for all completed implementation stories.
2. Local install refresh with `./Scripts/install_local_app.sh` when validating Finder behavior on the current machine.
3. `ai-slop-cleaner` pass on changed files or no-op report.
4. Post-cleaner verification.
5. Independent code-review evidence with `code-reviewer` APPROVE and `architect` CLEAR.
6. All six ultragoal stories complete.
7. `update_goal({status: "complete"})` only after the final gate is clean.

Known local caveats:

- Conventional `xcodebuild` license blocker is resolved: `xcodebuild -list`, Debug, Release, and local signed Debug/Release builds pass after admin license acceptance.
- Fully automated Finder Space-key UI triggering may remain blocked by macOS Accessibility permission; `qlmanage` + PlugInKit + unified logs are the automated strict Quick Look evidence. The archived view-controller prototype is excluded from the shipping MVP build graph to keep one canonical runtime path. Evidence logging is verifier-only and must remain disabled in production builds. `MenuBarExtra` is intentionally not used while the deployment target remains macOS 12.0; the host menu bar surface uses `NSStatusItem`.
