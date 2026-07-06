cask "folderpeek" do
  version "0.2"
  sha256 "f3dea655e9d21cc238018249bf5c03adbada76f92bef51c392c51c8a9a93c910"

  url "https://github.com/doma17/FolderPeek/releases/download/v#{version}/FolderPeek-#{version}.zip",
      verified: "github.com/doma17/FolderPeek/"
  name "FolderPeek"
  desc "Quick Look extension for previewing folder, zip, and tar contents"
  homepage "https://github.com/doma17/FolderPeek"

  depends_on macos: :monterey

  app "FolderPeek.app"

  uninstall quit: "com.folderpeek.app"

  zap trash: [
    "~/Library/Preferences/com.folderpeek.app.plist",
    "~/Library/Saved Application State/com.folderpeek.app.savedState",
  ]

  caveats <<~EOS
    FolderPeek 0.2 is an early-tester direct-distribution build.
    Until Developer ID signing and notarization are available, macOS Gatekeeper may require manual approval on first launch.
  EOS
end
