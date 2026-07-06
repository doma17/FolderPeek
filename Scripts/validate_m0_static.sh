#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
ARCH="${ARCH:-$(uname -m)}"
MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-12.0}"
mkdir -p .build/module-cache .build/clang-cache
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$root/.build/clang-cache}"
export SWIFT_MODULE_CACHE_PATH="${SWIFT_MODULE_CACHE_PATH:-$root/.build/module-cache}"
plutil -lint FolderPeek/Host/Info.plist FolderPeek/QuickLookExtension/Info.plist FolderPeek/Host/FolderPeek.entitlements FolderPeek/QuickLookExtension/FolderPeekPreview.entitlements
python3 - <<'PY'
import plistlib
from pathlib import Path

extension_info = plistlib.loads(Path("FolderPeek/QuickLookExtension/Info.plist").read_bytes())
types = set(extension_info["NSExtension"]["NSExtensionAttributes"]["QLSupportedContentTypes"])
required = {"public.folder", "public.directory", "public.zip-archive", "public.tar-archive"}
missing = sorted(required - types)
if missing:
    raise SystemExit(f"missing Quick Look content type(s): {', '.join(missing)}")

host_info = plistlib.loads(Path("FolderPeek/Host/Info.plist").read_bytes())
host_source_paths = sorted(Path("FolderPeek/Host").rglob("*.swift"))
host_sources = "\n".join(path.read_text() for path in host_source_paths)
if not host_info.get("LSUIElement") and "setActivationPolicy(.accessory)" not in host_sources:
    raise SystemExit("missing menu-bar-primary host posture: expected LSUIElement or accessory activation policy")

forbidden_host_terms = [
    "MenuBarExtra",
    "SMAppService",
    "LaunchAtLogin",
    "qlmanage",
    "pluginkit",
    "NSAppleEventsUsageDescription",
    "NSAccessibilityUsageDescription",
]
host_surface = host_sources + "\n" + Path("FolderPeek/Host/Info.plist").read_text()
found = [term for term in forbidden_host_terms if term in host_surface]
if found:
    raise SystemExit(f"forbidden host menu-bar term(s): {', '.join(found)}")

project_surface = Path("FolderPeek.xcodeproj/project.pbxproj").read_text()
archived_view_controller_name = "Preview" + "ViewController"
if archived_view_controller_name in project_surface:
    raise SystemExit("archived AppKit Quick Look view controller must not re-enter the active build/static validation graph")

shared_archive = Path("FolderPeek/Shared/ArchiveCore.swift").read_text()
extension_preview = Path("FolderPeek/QuickLookExtension/PreviewProvider.swift").read_text()
if "FolderPeekArchivePreviewModelBuilder()" not in extension_preview:
    raise SystemExit("Quick Look provider should use the default archive model builder boundary")
if "FolderPeekInProcessArchiveListingProvider()" not in shared_archive:
    raise SystemExit("archive model builder must default to the in-process archive listing provider")
forbidden_archive_terms = [
    "FolderPeekBsdtar",
    "FolderPeekProcessCommandRunner",
    "FolderPeekCommandRequest",
    "FolderPeekCommandResult",
    "/usr/bin/bsdtar",
    "Process()",
    "Archive listing tool",
    "unsupported by bsdtar",
]
archive_surface = shared_archive + "\n" + extension_preview
found_archive_terms = [term for term in forbidden_archive_terms if term in archive_surface]
if found_archive_terms:
    raise SystemExit(f"forbidden archive runtime term(s): {', '.join(found_archive_terms)}")
PY
swiftc -typecheck -target "$ARCH-apple-macosx$MACOSX_DEPLOYMENT_TARGET" -framework AppKit -framework QuickLookThumbnailing FolderPeek/Shared/ArchiveCore.swift FolderPeek/Shared/PreviewCore.swift FolderPeek/Shared/PreviewHTMLRenderer.swift FolderPeek/Shared/ThumbnailPipeline.swift
swiftc -typecheck -target "$ARCH-apple-macosx$MACOSX_DEPLOYMENT_TARGET" -framework Cocoa -framework QuickLookUI -framework QuickLookThumbnailing -framework UniformTypeIdentifiers FolderPeek/Shared/ArchiveCore.swift FolderPeek/Shared/PreviewCore.swift FolderPeek/Shared/PreviewHTMLRenderer.swift FolderPeek/Shared/ThumbnailPipeline.swift FolderPeek/QuickLookExtension/PreviewProvider.swift
swiftc -typecheck -target "$ARCH-apple-macosx$MACOSX_DEPLOYMENT_TARGET" -framework SwiftUI -framework AppKit FolderPeek/Host/FolderPeekApp.swift FolderPeek/Host/ContentView.swift FolderPeek/Host/MenuBarController.swift

# Release-candidate privacy/artifact boundary checks.
if ! grep -F 'FOLDERPEEK_EVIDENCE=1 FOLDERPEEK_MANUAL_BUILD_OUT="$evidence_build_out"' Scripts/verify_quicklook_runtime.sh >/dev/null; then
  echo "FAILED: Quick Look runtime verifier must build an evidence-only bundle in a separate output path" >&2
  exit 1
fi
if grep -F -- '-D FOLDERPEEK_EVIDENCE' Scripts/build_manual_app_bundle.sh | grep -v 'EVIDENCE_DEFINE' >/dev/null; then
  echo "FAILED: default manual bundle must not hard-code FOLDERPEEK_EVIDENCE" >&2
  exit 1
fi
if ! grep -F 'mailto:rovin1273@gmail.com' FolderPeek/Host/ContentView.swift >/dev/null; then
  echo "FAILED: Quick Look Setup Check must include contact mailto link" >&2
  exit 1
fi
if ! grep -F 'enum HelpTab' FolderPeek/Host/ContentView.swift >/dev/null || ! grep -F 'struct PillTabPicker' FolderPeek/Host/ContentView.swift >/dev/null; then
  echo "FAILED: FolderPeek help window must expose Guide and Quick Look Check as tabbed surfaces" >&2
  exit 1
fi
if ! grep -F 'struct GuidePanel' FolderPeek/Host/ContentView.swift >/dev/null || ! grep -F 'struct SetupCheckPanel' FolderPeek/Host/ContentView.swift >/dev/null; then
  echo "FAILED: FolderPeek help tabs must keep guide and setup-check content separated" >&2
  exit 1
fi
if grep -E 'Settings \{|WindowGroup|EmptyView\(\)' FolderPeek/Host/*.swift >/dev/null; then
  echo "FAILED: host app must not expose an empty Settings or WindowGroup scene" >&2
  exit 1
fi

if grep -F 'openSetupGuideOnFirstLaunch' FolderPeek/Host/MenuBarController.swift >/dev/null; then
  echo "FAILED: host app must not auto-open Setup Guide on launch" >&2
  exit 1
fi

for forbidden_text in 'Open Help & Status' 'Quick Look CheckList' 'FolderPeek Setting'; do
  if grep -R "$forbidden_text" FolderPeek/Host >/dev/null; then
    echo "FAILED: obsolete host UI text remains: $forbidden_text" >&2
    exit 1
  fi
done

if grep -R 'FolderPeek Setup Guide' FolderPeek/Host >/dev/null; then
  echo "FAILED: obsolete FolderPeek Setup Guide title remains" >&2
  exit 1
fi
if ! grep -F 'Bundle.main.url(forResource: "FolderPeek", withExtension: "icns")' FolderPeek/Host/ContentView.swift >/dev/null; then
  echo "FAILED: guide headers must load the bundled app icon resource directly" >&2
  exit 1
fi

if grep -F 'Button("Open System Settings")' FolderPeek/Host/ContentView.swift >/dev/null; then
  echo "FAILED: Quick Look Setup Check should expose one settings button, not duplicate settings buttons" >&2
  exit 1
fi
if ! grep -F 'Button("Open Extension Settings")' FolderPeek/Host/ContentView.swift >/dev/null; then
  echo "FAILED: Quick Look Setup Check must keep a single extension settings button" >&2
  exit 1
fi
if ! grep -F 'width: 760, height: 620' FolderPeek/Host/MenuBarController.swift >/dev/null; then
  echo "FAILED: FolderPeek help window should use the unified larger tabbed window size" >&2
  exit 1
fi
if ! grep -F 'ContentView(initialTab: .guide)' FolderPeek/Host/MenuBarController.swift >/dev/null || ! grep -F 'ContentView(initialTab: .setupCheck)' FolderPeek/Host/MenuBarController.swift >/dev/null; then
  echo "FAILED: menu actions should open the unified help window with the requested initial tab" >&2
  exit 1
fi

# Host keyboard shortcut checks.
if grep -F 'NSMenuItem(title: "Close Window"' FolderPeek/Host/MenuBarController.swift >/dev/null; then
  echo "FAILED: menu bar dropdown should not expose Close Window; Command-W belongs in the app/window menu only" >&2
  exit 1
fi
if ! grep -F 'keyEquivalent: "q"' FolderPeek/Host/MenuBarController.swift >/dev/null; then
  echo "FAILED: menu bar surface must expose Command-Q quit equivalent" >&2
  exit 1
fi
if ! grep -F 'FolderPeekMainMenu.make()' FolderPeek/Host/FolderPeekApp.swift >/dev/null || ! grep -F 'keyEquivalent: "w"' FolderPeek/Host/FolderPeekApp.swift >/dev/null || ! grep -F 'keyEquivalent: "q"' FolderPeek/Host/FolderPeekApp.swift >/dev/null; then
  echo "FAILED: host app must install an app/window menu so Command-W and Command-Q work from windows" >&2
  exit 1
fi

# Typography and icon design checks.
if ! grep -F 'private enum DesignTypography' FolderPeek/Host/ContentView.swift >/dev/null; then
  echo "FAILED: SwiftUI host text must use centralized San Francisco typography tokens" >&2
  exit 1
fi
if ! grep -F 'private enum PreviewTypography' FolderPeek/QuickLookExtension/PreviewViewController.swift >/dev/null; then
  echo "FAILED: AppKit Quick Look preview text must use centralized San Francisco typography tokens" >&2
  exit 1
fi
if ! grep -F '"SF Pro Display"' FolderPeek/Shared/PreviewHTMLRenderer.swift >/dev/null || ! grep -F '"SF Pro Text"' FolderPeek/Shared/PreviewHTMLRenderer.swift >/dev/null; then
  echo "FAILED: HTML Quick Look renderer must declare SF Pro Display/Text font stacks" >&2
  exit 1
fi
if ! grep -F 'systemSymbolName: "folder"' FolderPeek/Host/MenuBarController.swift >/dev/null; then
  echo "FAILED: menu bar status icon must stay SF Symbols-based" >&2
  exit 1
fi
if ! grep -F 'LiquidGlass-Lens' Assets/AppIcon/FolderPeekAppIcon.svg >/dev/null || ! grep -F 'SFSymbolsStyle-Folder' Assets/AppIcon/FolderPeekAppIcon.svg >/dev/null; then
  echo "FAILED: app icon SVG must preserve Liquid Glass and SF Symbols-style folder layers" >&2
  exit 1
fi
if ! test -s Assets/AppIcon/IconComposer.md; then
  echo "FAILED: app icon must include Icon Composer source notes" >&2
  exit 1
fi

echo "FolderPeek M0 static checks passed"
