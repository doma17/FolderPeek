# FolderPeek

FolderPeek is a macOS Quick Look extension for previewing the contents of folders and archives before opening them.

It is built for the Finder workflow: select a folder, `.zip`, or `.tar` file, press Space, and inspect a bounded contents preview instead of opening the item first.

## Current scope

- Folder and directory previews
- Zip and tar archive listings without extraction
- File names, sizes, modified dates, type grouping, and thumbnails when available
- Lightweight menu bar helper with guide and Quick Look troubleshooting tabs
- No background indexing, preview history, analytics, or network service

## Requirements

- macOS 12 or later
- Xcode installed at `/Applications/Xcode.app`
- Xcode command line tools selected:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Build

Run the local app bundle builder:

```sh
./Scripts/build_manual_app_bundle.sh
```

The built app is written to:

```text
.build/manual/FolderPeek.app
```

## Install locally

For local Finder/Quick Look testing:

```sh
./Scripts/install_local_app.sh
```

This installs FolderPeek to:

```text
/Applications/FolderPeek.app
```

and refreshes PlugInKit/Quick Look registration.

## Verify

Useful local checks:

```sh
./Scripts/validate_m0_static.sh
./Scripts/test_core_smoke.sh
./Scripts/verify_app_store_readiness.sh
./Scripts/verify_release_candidate.sh
```

For manual Finder testing:

```sh
./Scripts/manual_finder_quicklook_checklist.sh
```

## App Store preparation

Release notes and submission prep live in:

```text
Docs/AppStoreSubmission.md
Docs/AppStoreMetadataDraft.md
```

An App Store release still requires Apple Developer Program membership, production signing, App Store Connect setup, screenshots, support URL, privacy answers, and App Review submission.
