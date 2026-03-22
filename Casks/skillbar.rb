cask "skillbar" do
  version "0.2.0"
  sha256 "515ed1315968a4ea9bd88c8eb2ed247ec30c467d3ed66a1226feceffa007026d"

  url "https://github.com/vnnkl/SkillBar/releases/download/v#{version}/SkillBar-v#{version}.zip"
  name "SkillBar"
  desc "Menu bar app for browsing Claude Code skills"
  homepage "https://github.com/vnnkl/SkillBar"

  depends_on macos: ">= :sonoma"

  app "SkillBar.app"

  zap trash: "~/Library/Preferences/com.vnnkl.SkillBar.plist"
end
