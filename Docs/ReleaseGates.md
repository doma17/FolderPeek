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
- `Scripts/build_manual_app_bundle.sh` produces a signed local host app and executable `.appex`.
- `pluginkit -mADv -p com.apple.quicklook.preview -i com.folderpeek.app.preview` finds the extension.
- `qlmanage -p -c public.folder`, `public.zip-archive`, and `public.tar-archive` invoke `FolderPeekPreview` for selected fixtures and emit `FolderPeekEvidence` unified logs in the local verifier-only `FOLDERPEEK_EVIDENCE` build.
- Archive child-process listing is verified by core tests and fixture command logs; sandboxed Quick Look currently returns a designed safe error state when child `bsdtar` execution is denied.

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
- Archive and development-looking folders are listed as ordinary folder contents; no out-of-scope expansion or project intelligence is introduced.

## Gate 4 — Final Quality Gate

Required before aggregate goal completion:

1. Targeted verification for all completed implementation stories.
2. `ai-slop-cleaner` pass on changed files or no-op report.
3. Post-cleaner verification.
4. Independent code-review evidence with `code-reviewer` APPROVE and `architect` CLEAR.
5. All six ultragoal stories complete.
6. `update_goal({status: "complete"})` only after the final gate is clean.

Known local caveats:

- Conventional `xcodebuild` license blocker is resolved: `xcodebuild -list`, Debug, Release, and local signed Debug/Release builds pass after admin license acceptance.
- Fully automated Finder Space-key UI triggering may remain blocked by macOS Accessibility permission; `qlmanage` + PlugInKit + unified logs are the automated strict Quick Look evidence. The archived view-controller prototype is excluded from the shipping MVP build graph to keep one canonical runtime path. Evidence logging is verifier-only and must remain disabled in production builds. `MenuBarExtra` is intentionally not used while the deployment target remains macOS 12.0; the host menu bar surface uses `NSStatusItem`.
