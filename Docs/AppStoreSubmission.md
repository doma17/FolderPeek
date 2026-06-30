# FolderPeek App Store Submission Checklist

This document tracks what can be prepared in the repository and what still needs the account holder in App Store Connect.

## Product position

FolderPeek is a macOS menu bar utility with a Quick Look extension. It lets users select a folder, zip archive, or tar archive in Finder and press Space to inspect contents before opening the item.

## Repository-ready items

- App icon asset exists at `Assets/AppIcon/FolderPeek.icns` and `Assets/AppIcon/FolderPeekAppIcon-1024.png`.
- Host app is menu-bar-primary (`LSUIElement`) and does not expose an empty Settings window.
- App Sandbox is enabled for the host app and Quick Look extension.
- Default release-candidate builds do not include local evidence logging.
- The app declares no Accessibility permission requirement and does not request extra macOS permissions.
- Privacy posture: no analytics, no tracking, no account system, no background indexing, no preview history, no archive extraction.
- Support contact: `rovin1273@gmail.com`.

## App Store Connect metadata draft

Use `Docs/AppStoreMetadataDraft.md` as the copy source for the product page, privacy answers, review notes, and screenshot plan.


## Local install versus App Store archive

`./Scripts/install_local_app.sh` is for local Finder/Quick Look validation only. It creates an ad-hoc signed tester bundle under `/Applications/FolderPeek.app` and refreshes PlugInKit/Quick Look state. Do not treat this as the App Store upload artifact.

For App Store submission, create a production archive in Xcode with App Store distribution signing, then upload that archive's build to App Store Connect. Re-run the local install script only to validate Finder behavior before or after the archive is created.

## Build and validation gates before upload

Run these locally before creating the App Store archive:

```sh
./Scripts/validate_m0_static.sh
./Scripts/test_core_smoke.sh
./Scripts/verify_release_candidate.sh
./Scripts/verify_app_store_readiness.sh
```

Then run the full Quick Look runtime verification on a signed local install:

```sh
./Scripts/verify_quicklook_runtime.sh
./Scripts/manual_finder_quicklook_checklist.sh
```

## App Store upload flow

Apple's submission flow requires an App Store Connect app record, complete metadata, a build uploaded from Xcode or equivalent tooling, and a selected build submitted for review. The current project still needs an account-holder-controlled App Store Connect record and production signing setup before upload.

Expected high-level flow:

1. Enroll or confirm active Apple Developer Program membership.
2. Create or select the Bundle ID for the app and extension.
3. Create the macOS app record in App Store Connect.
4. Configure App Sandbox and signing for App Store distribution in Xcode.
5. Archive the app in Xcode and upload the build to App Store Connect.
6. Complete pricing, availability, age rating, privacy, screenshots, support URL, and review notes.
7. Submit the selected build for App Review.

## User/account-holder inputs still required

- Apple Developer Program membership and App Store Connect access.
- Final Bundle ID, SKU, copyright holder, and seller/developer name.
- Final app price and country/region availability.
- Public support URL and privacy policy URL if Apple requires URLs for the listing. The app does not collect data, but App Store Connect metadata still needs completed privacy declarations.
- Final screenshots captured from the release build.
- App Review contact information and any required compliance/tax/banking forms.
- Final decision on whether v0.2 is App Store-only, direct-download-only, or both.

## Review notes draft

FolderPeek is tested through Finder Quick Look:

1. Launch FolderPeek. It appears as a folder icon in the macOS menu bar.
2. Open Finder and select a folder, `.zip`, or `.tar` file.
3. Press Space to open Quick Look.
4. FolderPeek displays a bounded contents preview. Archives are listed without extraction.

The app has no login, no server backend, no purchases, no analytics, no tracking, and no user-generated content.

## Apple references checked

- App Review pre-submission checklist: https://developer.apple.com/app-store/review/guidelines/
- Add a new app record: https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app
- Upload builds: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- Manage app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications


## App Store Connect action plan for 0.2

### Already prepared in this repository

- App version set to `0.2` for the host app and Quick Look extension.
- App icon resources are generated and bundled.
- App Sandbox entitlements are enabled for the host app and extension.
- Local release-candidate build and install scripts are available.
- App Store metadata draft is available in `Docs/AppStoreMetadataDraft.md`.
- Static readiness check is available at `Scripts/verify_app_store_readiness.sh`.

### Account-holder steps in App Store Connect

1. Sign the latest Apple Developer Program agreements in the Business section if App Store Connect requires it.
2. Create or confirm the Bundle ID for `com.folderpeek.app` and the Quick Look extension identifier `com.folderpeek.app.preview` in Certificates, Identifiers & Profiles.
3. Create a new macOS app record in App Store Connect:
   - Platform: macOS
   - Name: FolderPeek
   - Primary language: English unless localized copy is ready
   - Bundle ID: `com.folderpeek.app`
   - SKU: recommended `folderpeek-macos-001` or another stable internal identifier
4. Complete app information:
   - Category: Productivity or Utilities
   - Content rights: FolderPeek uses original app UI/assets unless third-party assets are later added
   - Age rating questionnaire
   - Pricing and availability
   - Support URL
   - Privacy policy URL if requested for the listing or account configuration
5. Complete App Privacy answers. Current product posture: no data collection, no tracking, no analytics, no account system, no ads, no remote service.
6. Capture and upload required Mac screenshots. Apple currently accepts required Mac screenshots at 16:10 sizes such as 1280×800, 1440×900, 2560×1600, or 2880×1800.
7. Archive the app in Xcode using App Store distribution signing and upload the build to App Store Connect.
8. Select the uploaded 0.2 build, fill review notes, and submit for App Review.

### Review notes for 0.2

FolderPeek is a macOS menu bar app with a Quick Look preview extension. To test it:

1. Launch FolderPeek. It appears as a folder icon in the menu bar and opens no window automatically.
2. In Finder, select a folder, `.zip`, or `.tar` file.
3. Press Space to open Quick Look.
4. FolderPeek shows a bounded contents preview. Archives are listed without extraction.
5. The menu bar item contains `Open FolderPeek Guide…` and `Quick Look Setup Check…` for manual help/troubleshooting.

No login, server, purchases, tracking, analytics, or user-generated content are used.

### Cannot be completed without account access

- Creating the App Store Connect app record.
- Configuring production signing certificates/profiles under the developer account.
- Uploading the App Store archive.
- Filling tax/banking/compliance if the account requires it.
- Providing final public Support URL and Privacy Policy URL.
- Final screenshot capture/approval from the production-signed build.
