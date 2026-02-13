cask "skillbar" do
  version "0.1.0"
  sha256 "b49cc6a99942dfdbd4e0d7273160ddc231e04a0099af3e52bbdda1cdffd03677"

  url "https://github.com/vnnkl/SkillBar/releases/download/v#{version}/SkillBar-#{version}.zip"
  name "SkillBar"
  desc "Menu bar app for browsing Claude Code skills"
  homepage "https://github.com/vnnkl/SkillBar"

  depends_on macos: ">= :sonoma"

  app "SkillBar.app"

  zap trash: "~/Library/Preferences/com.vnnkl.SkillBar.plist"
end
