# FolderPeek 0.3 Release Notes

Release date: 2026-07-06

FolderPeek 0.3 is the current early-tester direct-distribution build. It is intended for users who are comfortable installing a macOS app outside the App Store while Developer ID signing and notarization are still pending.

## Highlights

- Finder Quick Look previews for folders.
- Flat, read-only previews for zip and tar archives without extracting them.
- Menu bar helper with a folder-only status icon.
- FolderPeek Guide and Quick Look Setup Check windows for first-use help and troubleshooting.
- Liquid Glass app icon refresh with Spotlight-safe small ICNS slots.
- App icon and menu bar icon polish based on the project design guide.
- San Francisco typography alignment across the host UI and Quick Look preview surfaces.
- Release packaging script with zip structure, version, extension, and checksum validation.
- Repo-local Homebrew cask template for a future personal tap.

## Install

Download these two files from the GitHub Release:

- `FolderPeek-0.3.zip`
- `SHA256SUMS.txt`

Then verify the download if desired:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

Unzip `FolderPeek-0.3.zip`, move `FolderPeek.app` to `/Applications`, launch it once, then enable the Quick Look extension in macOS System Settings if needed.

## Known limitations

- This build may trigger Gatekeeper friction because Developer ID signing and notarization are not complete yet.
- Spotlight may briefly show a stale icon after replacing an older local build until macOS icon caches refresh.
- Homebrew installation is not live until the cask is copied into a personal tap and audited there.
- Sparkle automatic updates are intentionally not included yet.

## Verification

Local release gates passed before tagging:

- `./Scripts/package_release.sh`
- `./Scripts/validate_m0_static.sh`
- `./Scripts/test_core_smoke.sh`
- `./Scripts/verify_app_store_readiness.sh`
- `./Scripts/verify_release_candidate.sh`
- `ruby -c Casks/folderpeek.rb`
- `brew style Casks/folderpeek.rb`
- `git diff --check`
