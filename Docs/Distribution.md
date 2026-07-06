# Distribution

FolderPeek 0.2 is prepared for App Store-free distribution through GitHub Releases first, with a personal Homebrew tap as the power-user install path.

This channel is intentionally early-tester oriented until Developer ID signing and notarization are in place.

## Current status

The repository currently contains the local packaging script, distribution documentation, and a repo-local Homebrew cask template. It is not an operationally proven public channel until all of these external checks pass for an actual GitHub Release:

1. The `v0.2` release exists on GitHub with `FolderPeek-0.2.zip` and `SHA256SUMS.txt` uploaded.
2. The release asset can be downloaded into a clean temporary directory.
3. `shasum -a 256 -c SHA256SUMS.txt` passes against the downloaded asset.
4. The personal tap contains the cask and `brew audit --cask --new folderpeek` passes from that tap context.
5. A fresh install through the tap launches and the Quick Look extension can be enabled.

Until those checks pass, treat the Homebrew cask as a template and the direct-download instructions as the intended release procedure, not as a completed public distribution channel.

## Release identity

- Version: 0.2
- Git tag: v0.2
- Artifact: FolderPeek-0.2.zip
- Checksum file: SHA256SUMS.txt
- Current SHA-256: `f3dea655e9d21cc238018249bf5c03adbada76f92bef51c392c51c8a9a93c910`

The host app and Quick Look extension must both use:

- `CFBundleShortVersionString=0.2`
- `CFBundleVersion=1`

## Build the release artifact

From the repository root:

```sh
./Scripts/package_release.sh
```

The script writes:

```text
.build/release/FolderPeek-0.2.zip
.build/release/SHA256SUMS.txt
```

The script fails if the app version/build do not match 0.2/1, if the archive has anything other than `FolderPeek.app` at the top level, if the Quick Look extension is missing after unzip, if evidence-only markers are present, or if code signing verification fails.

## GitHub Release flow

1. Run the local verification set.
2. Run `./Scripts/package_release.sh`.
3. Create tag `v0.2` from the release commit.
4. Create a GitHub Release for `v0.2`.
5. Upload:
   - `FolderPeek-0.2.zip`
   - `SHA256SUMS.txt`
6. Download both files from the release page into a clean temporary directory.
7. Verify the checksum:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

External release creation and upload are intentionally manual until credentials and signing are settled. Passing the local packaging script alone does not prove the published download path; the clean download and checksum verification above are required after the GitHub Release exists.

## Direct install instructions

1. Download `FolderPeek-0.2.zip` from the GitHub Release.
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

This file is a template until it is copied into a personal tap and audited there. After the GitHub Release exists, create or update a personal tap repository such as:

```text
doma17/homebrew-folderpeek
```

Homebrew drops the `homebrew-` prefix in the tap command, so the expected install command after the tap exists is:

```sh
brew tap doma17/folderpeek
brew install --cask folderpeek
```

Validate the repo-local cask style before copying it into the tap:

```sh
brew style Casks/folderpeek.rb
```

After the cask is in the personal tap, validate it by cask name from the tap context:

```sh
brew audit --cask --new folderpeek
```

Do not submit FolderPeek to the official Homebrew Cask repository until notability, signing, and Gatekeeper expectations are addressed.

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
