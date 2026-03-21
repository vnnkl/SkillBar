import Foundation

extension SkillListViewModel {

    func launchSkill(_ skill: Skill) {
        copySkill(skill)
        guard launchMode != .copyOnly else { return }

        let command = skill.slashCommand
        let bundleID = capturedTerminalBundleID?()
        let mode = launchMode

        closePopover?()

        Task {
            try? await Task.sleep(for: .milliseconds(150))
            await terminalLauncher.launch(
                command: command,
                mode: mode,
                terminalBundleID: bundleID
            )
        }
    }

    func setLaunchMode(_ mode: LaunchMode) {
        launchMode = mode
        store.set([mode.rawValue], forKey: Constants.launchModeKey)
    }
}
