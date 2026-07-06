# FolderPeek Icon Composer Source Notes

FolderPeek's generated icon is designed as an Icon Composer-friendly layered source:

- `FolderPeekAppIcon.svg` contains named layers:
  - `AppIcon-Background`
  - `LiquidGlass-Lens`
  - `LiquidGlass-SpecularTop`
  - `LiquidGlass-SpecularFine`
  - `InteriorGlow`
  - `SFSymbolsStyle-Folder`
- `FolderPeekAppIcon-1024.png` is the rendered 1024px master.
- `FolderPeek.icns` is the shipping macOS app icon.

The silhouette intentionally follows the simple SF Symbols `folder` grammar while keeping the app-icon artwork as project-owned vector/raster output. Icon Composer is installed with Xcode and can open/import the SVG/PNG master for manual Liquid Glass layer tuning when a GUI design pass is desired.
