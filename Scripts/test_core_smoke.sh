#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
ARCH="${ARCH:-$(uname -m)}"
MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-12.0}"
mkdir -p .build .build/module-cache .build/clang-cache .omx/evidence/core
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$root/.build/clang-cache}"
export SWIFT_MODULE_CACHE_PATH="${SWIFT_MODULE_CACHE_PATH:-$root/.build/module-cache}"
swiftc -target "$ARCH-apple-macosx$MACOSX_DEPLOYMENT_TARGET" -framework AppKit -framework QuickLookThumbnailing FolderPeek/Shared/ArchiveCore.swift FolderPeek/Shared/PreviewCore.swift FolderPeek/Shared/PreviewHTMLRenderer.swift FolderPeek/Shared/ThumbnailPipeline.swift Tests/CoreSmoke/main.swift -o .build/folderpeek-core-smoke
.build/folderpeek-core-smoke | tee .omx/evidence/core/smoke-test.log
