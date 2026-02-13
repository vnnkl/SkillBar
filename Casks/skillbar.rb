cask "skillbar" do
  version "0.1.0"
  sha256 "PLACEHOLDER"

  url "https://github.com/vnnkl/SkillBar/releases/download/v#{version}/SkillBar-#{version}.zip"
  name "SkillBar"
  desc "Menu bar app for browsing Claude Code skills"
  homepage "https://github.com/vnnkl/SkillBar"

  depends_on macos: ">= :sonoma"

  app "SkillBar.app"

  zap trash: "~/Library/Preferences/com.vnnkl.SkillBar.plist"
end
