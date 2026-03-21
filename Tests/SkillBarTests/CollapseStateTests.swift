import Testing
@testable import SkillBar

@Suite("Collapse State Tests")
@MainActor
struct CollapseStateTests {

    // MARK: - Helpers

    private func makeSkill(name: String) -> Skill {
        Skill(name: name, description: "", source: .local, filePath: "/path/\(name)/SKILL.md")
    }

    private func makeViewModel(
        skills: [Skill] = [],
        store: InMemoryKeyValueStore = InMemoryKeyValueStore()
    ) -> (SkillListViewModel, InMemoryKeyValueStore) {
        let scanner = MockSkillScanner()
        scanner.stubbedSkills = skills
        let vm = SkillListViewModel(scanner: scanner, store: store)
        vm.scan()
        return (vm, store)
    }

    // MARK: - Toggle

    @Test("togglePackageCollapse adds package to collapsed set")
    func toggleAdds() {
        let (vm, _) = makeViewModel()

        vm.togglePackageCollapse("gsd")

        #expect(vm.isPackageCollapsed("gsd"))
    }

    @Test("togglePackageCollapse removes package when already collapsed")
    func toggleRemoves() {
        let (vm, _) = makeViewModel()

        vm.togglePackageCollapse("gsd")
        #expect(vm.isPackageCollapsed("gsd"))

        vm.togglePackageCollapse("gsd")
        #expect(!vm.isPackageCollapsed("gsd"))
    }

    // MARK: - Persistence

    @Test("Collapse state persists to store")
    func persistsToStore() {
        let store = InMemoryKeyValueStore()
        let (vm, _) = makeViewModel(store: store)

        vm.togglePackageCollapse("gsd")

        let stored = store.array(forKey: Constants.collapsedPackagesKey)
        #expect(stored != nil)
        #expect(stored!.contains("gsd"))
    }

    @Test("Collapse state loads from store on init")
    func loadsFromStore() {
        let store = InMemoryKeyValueStore()
        store.set(["gsd", "superpowers"], forKey: Constants.collapsedPackagesKey)

        let (vm, _) = makeViewModel(store: store)

        #expect(vm.isPackageCollapsed("gsd"))
        #expect(vm.isPackageCollapsed("superpowers"))
    }

    // MARK: - Expand All

    @Test("expandAllPackages clears collapsed set")
    func expandAllClears() {
        let (vm, store) = makeViewModel()

        vm.togglePackageCollapse("gsd")
        vm.togglePackageCollapse("superpowers")
        #expect(vm.isPackageCollapsed("gsd"))

        vm.expandAllPackages()

        #expect(!vm.isPackageCollapsed("gsd"))
        #expect(!vm.isPackageCollapsed("superpowers"))
        #expect(store.array(forKey: Constants.collapsedPackagesKey) == nil)
    }

    // MARK: - Collapse All

    @Test("setAllPackagesCollapsed collapses provided packages")
    func collapseAllSets() {
        let packages = ["gsd", "superpowers", "compound"]
        let (vm, store) = makeViewModel()

        vm.setAllPackagesCollapsed(true, packages: packages)

        for pkg in packages {
            #expect(vm.isPackageCollapsed(pkg))
        }
        let stored = Set(store.array(forKey: Constants.collapsedPackagesKey) ?? [])
        #expect(stored == Set(packages))
    }

    @Test("setAllPackagesCollapsed(false) expands provided packages")
    func collapseAllFalseExpands() {
        let (vm, _) = makeViewModel()

        vm.togglePackageCollapse("gsd")
        vm.togglePackageCollapse("superpowers")

        vm.setAllPackagesCollapsed(false, packages: ["gsd", "superpowers"])

        #expect(!vm.isPackageCollapsed("gsd"))
        #expect(!vm.isPackageCollapsed("superpowers"))
    }

    // MARK: - Defaults

    @Test("New packages default to expanded")
    func newPackagesExpanded() {
        let (vm, _) = makeViewModel()

        #expect(!vm.isPackageCollapsed("never-seen-before"))
    }

    // MARK: - Independence from Favorites

    @Test("clearFavorites does not affect collapse state")
    func clearFavoritesIndependent() {
        let skill = makeSkill(name: "gsd:commit")
        let (vm, _) = makeViewModel(skills: [skill])

        vm.toggleFavorite(skill)
        vm.togglePackageCollapse("gsd")
        #expect(vm.isPackageCollapsed("gsd"))

        vm.clearFavorites()

        #expect(vm.isPackageCollapsed("gsd"))
    }
}
