import Testing
@testable import SkillBar

@Suite("Launch Mode Tests")
@MainActor
struct LaunchTests {

    // MARK: - Helpers

    private func makeViewModel(
        store: InMemoryKeyValueStore = InMemoryKeyValueStore()
    ) -> SkillListViewModel {
        let scanner = MockSkillScanner()
        return SkillListViewModel(scanner: scanner, store: store)
    }

    // MARK: - Defaults

    @Test("launchMode defaults to .copyOnly when store is empty")
    func defaultsCopyOnly() {
        let vm = makeViewModel()

        #expect(vm.launchMode == .copyOnly)
    }

    // MARK: - Persistence

    @Test("launchMode loads from store on init")
    func loadsFromStore() {
        let store = InMemoryKeyValueStore()
        store.set(["paste"], forKey: Constants.launchModeKey)

        let vm = makeViewModel(store: store)

        #expect(vm.launchMode == .paste)
    }

    @Test("corrupt store data defaults to .copyOnly")
    func corruptDataDefaults() {
        let store = InMemoryKeyValueStore()
        store.set(["invalid"], forKey: Constants.launchModeKey)

        let vm = makeViewModel(store: store)

        #expect(vm.launchMode == .copyOnly)
    }
}
