cask "skillbar" do
  version "0.2.1"
  sha256 "c4c696d1bf32e3a07b13553f151f237288ae1caf84334d90b36b1d25e474a08d"

  url "https://github.com/vnnkl/SkillBar/releases/download/v#{version}/SkillBar-v#{version}.zip"
  name "SkillBar"
  desc "Menu bar app for browsing Claude Code skills"
  homepage "https://github.com/vnnkl/SkillBar"

  depends_on macos: ">= :sonoma"

  app "SkillBar.app"

  zap trash: "~/Library/Preferences/com.vnnkl.SkillBar.plist"
end
