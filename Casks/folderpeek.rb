cask "folderpeek" do
  version "0.3"
  sha256 "a7be42a9eadb137d0491a6b38b61e3daefa7124c7c47f02c13c11e54b4e6e0e3"

  url "https://github.com/doma17/FolderPeek/releases/download/v#{version}/FolderPeek-#{version}.zip"
  name "FolderPeek"
  desc "Quick Look extension for previewing folder, zip, and tar contents"
  homepage "https://github.com/doma17/FolderPeek"

  depends_on macos: :monterey

  app "FolderPeek.app"

  postflight do
    app_path = "#{appdir}/FolderPeek.app"
    appex_path = "#{app_path}/Contents/PlugIns/FolderPeekPreview.appex"

    system_command "/usr/bin/pluginkit", args: ["-r", app_path], must_succeed: false
    system_command "/usr/bin/pluginkit", args: ["-r", appex_path], must_succeed: false
    system_command "/usr/bin/pluginkit", args: ["-a", app_path], must_succeed: false
    system_command "/usr/bin/pluginkit", args: ["-a", appex_path], must_succeed: false
    sleep 1
    system_command "/usr/bin/qlmanage", args: ["-r"], must_succeed: false
    system_command "/usr/bin/qlmanage", args: ["-r", "cache"], must_succeed: false
    system_command "/usr/bin/pluginkit", args: ["-a", appex_path], must_succeed: false
  end

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
