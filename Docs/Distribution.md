# Distribution

FolderPeek 0.3 is prepared for App Store-free distribution through GitHub Releases, GitHub Pages, and a personal Homebrew tap.

This channel is intentionally early-tester oriented until Developer ID signing and notarization are in place.

## Current status

The 0.3 direct-distribution channel is live for early testers:

1. The `v0.3` GitHub Release exists with `FolderPeek-0.3.zip` and `SHA256SUMS.txt` uploaded.
2. The release asset has been downloaded into a clean temporary directory.
3. `shasum -a 256 -c SHA256SUMS.txt` passes against the downloaded asset.
4. The GitHub Pages product page is published from this repository.
5. The personal Homebrew tap exists and `brew fetch --cask folderpeek` succeeds after `brew tap` and `brew trust`.

Remaining mainstream-distribution blockers are Developer ID signing/notarization, Gatekeeper verification from a freshly downloaded artifact, and official Homebrew notability/signature eligibility.

## Public pages

The GitHub Pages product page is served from the repository root:

```text
https://doma17.github.io/FolderPeek/
```

The page links to the latest GitHub Release and documents the Homebrew tap install path.

## Release identity

- Version: 0.3
- Git tag: v0.3
- Artifact: FolderPeek-0.3.zip
- Checksum file: SHA256SUMS.txt
- Current SHA-256: `a7be42a9eadb137d0491a6b38b61e3daefa7124c7c47f02c13c11e54b4e6e0e3`

The host app and Quick Look extension must both use:

- `CFBundleShortVersionString=0.3`
- `CFBundleVersion=1`

## Build the release artifact

From the repository root:

```sh
./Scripts/package_release.sh
```

The script writes:

```text
.build/release/FolderPeek-0.3.zip
.build/release/SHA256SUMS.txt
```

The script fails if the app version/build do not match 0.3/1, if the archive has anything other than `FolderPeek.app` at the top level, if the Quick Look extension is missing after unzip, if evidence-only markers are present, or if code signing verification fails.

## GitHub Release flow

1. Run the local verification set.
2. Run `./Scripts/package_release.sh`.
3. Create tag `v0.3` from the release commit.
4. Create a GitHub Release for `v0.3`.
5. Upload:
   - `FolderPeek-0.3.zip`
   - `SHA256SUMS.txt`
6. Download both files from the release page into a clean temporary directory.
7. Verify the checksum:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

Passing the local packaging script alone does not prove the published download path; the clean download and checksum verification above are required after each GitHub Release upload.

## Direct install instructions

1. Download `FolderPeek-0.3.zip` from the GitHub Release.
2. Unzip it.
3. Move `FolderPeek.app` to `/Applications`.
4. Launch FolderPeek once.
5. In macOS System Settings, enable the FolderPeek Quick Look extension if needed.
6. In Finder, select a folder, zip, or tar file and press Space.

## Gatekeeper caveat

The first direct-distribution build may be ad-hoc signed rather than Developer ID signed and notarized. macOS Gatekeeper may warn or block first launch, especially for users who download the zip through a browser.

Do not present this release as a frictionless mainstream download until Developer ID signing and notarization are implemented and tested.

## Homebrew personal tap

A repo-local cask template lives at:

```text
Casks/folderpeek.rb
```

The published personal tap repository is:

```text
https://github.com/doma17/homebrew-folderpeek
```

Homebrew drops the `homebrew-` prefix in the tap command, so the install command is:

```sh
brew tap doma17/folderpeek
brew trust doma17/folderpeek
brew install --cask folderpeek
```

Validate the repo-local cask style before updating the tap:

```sh
brew style Casks/folderpeek.rb
```

Validate the personal tap with style and fetch checks:

```sh
brew style Casks/folderpeek.rb
brew fetch --cask folderpeek
```

`brew audit --cask --new folderpeek` is expected to fail until Developer ID signing/notarization is complete and the GitHub repository meets Homebrew's notability requirements. Do not submit FolderPeek to the official Homebrew Cask repository until notability, signing, and Gatekeeper expectations are addressed.

## Developer ID and notarization path

For a mainstream non-App-Store release, add:

1. Apple Developer Program membership.
2. Developer ID Application signing.
3. Notarization with Apple's notary service.
4. Stapling where applicable.
5. Gatekeeper testing from a freshly downloaded artifact.
6. Updated docs that remove the early-tester warning only after verification.

## Sparkle readiness gate

Do not add Sparkle to the app yet. Add it only after the direct release pipeline is proven and the update-security obligations are accepted.

Required before Sparkle implementation:

- Stable HTTPS appcast location.
- Version policy with monotonically increasing `CFBundleVersion`.
- EdDSA key generation and private-key storage decision.
- Archive signing and appcast generation script.
- Developer ID/notarization decision.
- Sandboxed Sparkle integration and entitlement review.
- Old-version to new-version update test plan.
