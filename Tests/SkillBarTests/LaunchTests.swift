import Testing
@testable import SkillBar

@Suite("Launch Tests")
@MainActor
struct LaunchTests {

    // MARK: - Helpers

    private func makeSkill(name: String = "test-skill") -> Skill {
        Skill(name: name, description: "A test skill", source: .local, filePath: "/path/\(name)/SKILL.md")
    }

    private func makeViewModel(
        store: InMemoryKeyValueStore = InMemoryKeyValueStore(),
        clipboard: MockClipboard = MockClipboard(),
        launcher: MockTerminalLauncher = MockTerminalLauncher()
    ) -> (SkillListViewModel, MockClipboard, MockTerminalLauncher) {
        let scanner = MockSkillScanner()
        let vm = SkillListViewModel(
            scanner: scanner,
            clipboard: clipboard,
            store: store,
            terminalLauncher: launcher
        )
        return (vm, clipboard, launcher)
    }

    // MARK: - LaunchMode Defaults

    @Test("launchMode defaults to .copyOnly when store is empty")
    func defaultsCopyOnly() {
        let (vm, _, _) = makeViewModel()

        #expect(vm.launchMode == .copyOnly)
    }

    @Test("launchMode loads from store on init")
    func loadsFromStore() {
        let store = InMemoryKeyValueStore()
        store.set(["paste"], forKey: Constants.launchModeKey)

        let (vm, _, _) = makeViewModel(store: store)

        #expect(vm.launchMode == .paste)
    }

    @Test("corrupt store data defaults to .copyOnly")
    func corruptDataDefaults() {
        let store = InMemoryKeyValueStore()
        store.set(["invalid"], forKey: Constants.launchModeKey)

        let (vm, _, _) = makeViewModel(store: store)

        #expect(vm.launchMode == .copyOnly)
    }

    // MARK: - launchSkill clipboard

    @Test("launchSkill always copies to clipboard regardless of mode")
    func alwaysCopies() {
        let (vm, clipboard, _) = makeViewModel()
        vm.launchMode = .paste

        vm.launchSkill(makeSkill())

        #expect(clipboard.copyCallCount == 1)
        #expect(clipboard.lastCopiedString == "/test-skill")
    }

    @Test("launchSkill always records usage")
    func recordsUsage() {
        let (vm, _, _) = makeViewModel()

        vm.launchSkill(makeSkill(name: "my-skill"))

        #expect(vm.recentlyCopiedSkillId == "local:my-skill")
    }

    // MARK: - launchSkill terminal launcher

    @Test("launchSkill in copyOnly mode does NOT call terminalLauncher")
    func copyOnlySkipsLauncher() async throws {
        let (vm, _, launcher) = makeViewModel()
        vm.launchMode = .copyOnly

        vm.launchSkill(makeSkill())

        try await Task.sleep(for: .milliseconds(300))

        #expect(launcher.launchCallCount == 0)
    }

    @Test("launchSkill in paste mode calls terminalLauncher")
    func pasteModeCallsLauncher() async throws {
        let (vm, _, launcher) = makeViewModel()
        vm.launchMode = .paste

        vm.launchSkill(makeSkill())

        try await Task.sleep(for: .milliseconds(300))

        #expect(launcher.launchCallCount == 1)
        #expect(launcher.lastMode == .paste)
    }

    @Test("launchSkill in pasteAndExecute mode calls terminalLauncher")
    func pasteAndExecuteModeCallsLauncher() async throws {
        let (vm, _, launcher) = makeViewModel()
        vm.launchMode = .pasteAndExecute

        vm.launchSkill(makeSkill())

        try await Task.sleep(for: .milliseconds(300))

        #expect(launcher.launchCallCount == 1)
        #expect(launcher.lastMode == .pasteAndExecute)
    }

    @Test("launchSkill passes capturedTerminalBundleID to launcher")
    func passesBundleID() async throws {
        let (vm, _, launcher) = makeViewModel()
        vm.launchMode = .paste
        vm.capturedTerminalBundleID = { "com.googlecode.iterm2" }

        vm.launchSkill(makeSkill())

        try await Task.sleep(for: .milliseconds(300))

        #expect(launcher.lastBundleID == "com.googlecode.iterm2")
    }

    // MARK: - closePopover

    @Test("launchSkill calls closePopover when mode != copyOnly")
    func callsClosePopover() {
        let (vm, _, _) = makeViewModel()
        vm.launchMode = .paste
        var popoverClosed = false
        vm.closePopover = { popoverClosed = true }

        vm.launchSkill(makeSkill())

        #expect(popoverClosed)
    }

    @Test("launchSkill does NOT call closePopover in copyOnly mode")
    func doesNotCallClosePopoverInCopyOnly() {
        let (vm, _, _) = makeViewModel()
        vm.launchMode = .copyOnly
        var popoverClosed = false
        vm.closePopover = { popoverClosed = true }

        vm.launchSkill(makeSkill())

        #expect(!popoverClosed)
    }

    // MARK: - setLaunchMode

    @Test("setLaunchMode persists to store")
    func setLaunchModePersists() {
        let store = InMemoryKeyValueStore()
        let (vm, _, _) = makeViewModel(store: store)

        vm.setLaunchMode(.paste)

        #expect(vm.launchMode == .paste)
        #expect(store.array(forKey: Constants.launchModeKey) == ["paste"])
    }

    // MARK: - confirmSelection

    @Test("confirmSelection calls launchSkill (via terminalLauncher)")
    func confirmSelectionCallsLaunch() async throws {
        let (_, _, launcher) = makeViewModel()
        let scanner = MockSkillScanner()
        scanner.stubbedSkills = [makeSkill()]
        let vm2 = SkillListViewModel(
            scanner: scanner,
            clipboard: MockClipboard(),
            store: InMemoryKeyValueStore(),
            terminalLauncher: launcher
        )
        vm2.launchMode = .paste
        vm2.scan()
        vm2.selectedIndex = 0

        vm2.confirmSelection()

        try await Task.sleep(for: .milliseconds(300))

        #expect(launcher.launchCallCount == 1)
    }
}
