cask "folderpeek" do
  version "0.3"
  sha256 "a7be42a9eadb137d0491a6b38b61e3daefa7124c7c47f02c13c11e54b4e6e0e3"

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
    FolderPeek 0.3 is an early-tester direct-distribution build.
    Until Developer ID signing and notarization are available, macOS Gatekeeper may require manual approval on first launch.
  EOS
end
