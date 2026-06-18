# FolderPeek Xcode Project

This project contains a macOS host app (`FolderPeek`) and a data-based Quick Look Preview Extension (`FolderPeekPreview`).

## Current target layout

- Host target sources:
  - `FolderPeek/Host/FolderPeekApp.swift`
  - `FolderPeek/Host/ContentView.swift`
  - `FolderPeek/Host/MenuBarController.swift`
- Quick Look extension sources:
  - `FolderPeek/QuickLookExtension/PreviewProvider.swift`
  - `FolderPeek/Shared/ArchiveCore.swift`
  - `FolderPeek/Shared/PreviewCore.swift`
  - `FolderPeek/Shared/PreviewHTMLRenderer.swift`
  - `FolderPeek/Shared/ThumbnailPipeline.swift`
- Extension Info.plist:
  - `FolderPeek/QuickLookExtension/Info.plist`
- Supported content types:
  - `public.folder`
  - `public.directory`
  - `public.zip-archive`
  - `public.tar-archive`

The canonical Quick Look path is the data-based `PreviewProvider`. The old AppKit `PreviewViewController.swift` prototype is intentionally not part of the active Xcode project or build graph.

## Build / verification

Use full Xcode when available:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project FolderPeek.xcodeproj \
  -scheme FolderPeek \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Useful local checks:

```sh
./Scripts/validate_m0_static.sh
./Scripts/test_core_smoke.sh
./Scripts/verify_quicklook_runtime.sh
```
