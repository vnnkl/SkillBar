cask "skillbar" do
  version "0.3.0"
  sha256 "cdcbc20ccebe3e6331a8942a88b462b96a8816282aba4b4c345d1325cc73b77d"

  url "https://github.com/vnnkl/SkillBar/releases/download/v#{version}/SkillBar-v#{version}.zip"
  name "SkillBar"
  desc "Menu bar app for browsing Claude Code skills"
  homepage "https://github.com/vnnkl/SkillBar"

  depends_on macos: ">= :sonoma"

  app "SkillBar.app"

  zap trash: "~/Library/Preferences/com.vnnkl.SkillBar.plist"
end
