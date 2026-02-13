import Testing
@testable import SkillBar

@Suite("Favorites Tests")
@MainActor
struct FavoritesTests {

    // MARK: - Helpers

    private func makeSkill(
        name: String,
        description: String = "",
        source: SkillSource = .local
    ) -> Skill {
        Skill(name: name, description: description, source: source, filePath: "/path/\(name)/SKILL.md")
    }

    private func makeMockScanner(skills: [Skill] = []) -> MockSkillScanner {
        let scanner = MockSkillScanner()
        scanner.stubbedSkills = skills
        return scanner
    }

    private func makeViewModel(
        skills: [Skill] = [],
        store: InMemoryKeyValueStore = InMemoryKeyValueStore()
    ) -> (SkillListViewModel, InMemoryKeyValueStore) {
        let scanner = makeMockScanner(skills: skills)
        let vm = SkillListViewModel(scanner: scanner, store: store)
        vm.scan()
        return (vm, store)
    }

    // MARK: - Toggle Favorite

    @Test("toggleFavorite adds skill name to favorites")
    func toggleFavoriteAdds() {
        let skill = makeSkill(name: "commit")
        let (vm, _) = makeViewModel(skills: [skill])

        vm.toggleFavorite(skill)

        #expect(vm.isFavorite(skill))
    }

    @Test("toggleFavorite removes skill name when already favorited")
    func toggleFavoriteRemoves() {
        let skill = makeSkill(name: "commit")
        let (vm, _) = makeViewModel(skills: [skill])

        vm.toggleFavorite(skill)
        #expect(vm.isFavorite(skill))

        vm.toggleFavorite(skill)
        #expect(!vm.isFavorite(skill))
    }

    // MARK: - Persistence

    @Test("Favorites are persisted to KeyValueStore")
    func favoritesPersistToStore() {
        let store = InMemoryKeyValueStore()
        let skill = makeSkill(name: "commit")
        let (vm, _) = makeViewModel(skills: [skill], store: store)

        vm.toggleFavorite(skill)

        let stored = store.array(forKey: Constants.favoritesKey)
        #expect(stored == ["commit"])
    }

    @Test("Favorites are loaded from KeyValueStore on init")
    func favoritesLoadedOnInit() {
        let store = InMemoryKeyValueStore()
        store.set(["commit", "tdd"], forKey: Constants.favoritesKey)
        let skill = makeSkill(name: "commit")
        let (vm, _) = makeViewModel(skills: [skill], store: store)

        #expect(vm.isFavorite(skill))
    }

    // MARK: - Favorites Section

    @Test("Favorited skills appear in favoritedSkills")
    func favoritedSkillsAppear() {
        let skills = [
            makeSkill(name: "commit"),
            makeSkill(name: "tdd"),
            makeSkill(name: "review")
        ]
        let (vm, _) = makeViewModel(skills: skills)

        vm.toggleFavorite(skills[0])
        vm.toggleFavorite(skills[2])

        let favs = vm.favoritedSkills
        #expect(favs.count == 2)
        #expect(favs.map(\.name).contains("commit"))
        #expect(favs.map(\.name).contains("review"))
    }

    @Test("Unfavoriting removes skill from favoritedSkills")
    func unfavoritingRemovesFromSection() {
        let skills = [
            makeSkill(name: "commit"),
            makeSkill(name: "tdd")
        ]
        let (vm, _) = makeViewModel(skills: skills)

        vm.toggleFavorite(skills[0])
        vm.toggleFavorite(skills[1])
        #expect(vm.favoritedSkills.count == 2)

        vm.toggleFavorite(skills[0])
        #expect(vm.favoritedSkills.count == 1)
        #expect(vm.favoritedSkills.first?.name == "tdd")
    }

    // MARK: - Stale Favorites

    @Test("Stale favorites (deleted from filesystem) are filtered out")
    func staleFavoritesFiltered() {
        let store = InMemoryKeyValueStore()
        store.set(["commit", "deleted-skill"], forKey: Constants.favoritesKey)
        let skill = makeSkill(name: "commit")
        let (vm, _) = makeViewModel(skills: [skill], store: store)

        let favs = vm.favoritedSkills
        #expect(favs.count == 1)
        #expect(favs.first?.name == "commit")
    }

    // MARK: - Clear Favorites

    @Test("clearFavorites removes all favorites")
    func clearFavoritesRemovesAll() {
        let skills = [
            makeSkill(name: "commit"),
            makeSkill(name: "tdd")
        ]
        let (vm, store) = makeViewModel(skills: skills)

        vm.toggleFavorite(skills[0])
        vm.toggleFavorite(skills[1])
        #expect(vm.favoritedSkills.count == 2)

        vm.clearFavorites()

        #expect(vm.favoritedSkills.isEmpty)
        #expect(store.array(forKey: Constants.favoritesKey) == nil)
    }

    // MARK: - Favorites with Filtering

    @Test("Favorites are included in filtered results when matching search")
    func favoritesRespectSearch() {
        let skills = [
            makeSkill(name: "commit", description: "Git helper"),
            makeSkill(name: "tdd", description: "Testing")
        ]
        let (vm, _) = makeViewModel(skills: skills)

        vm.toggleFavorite(skills[0])
        vm.toggleFavorite(skills[1])
        vm.searchText = "git"

        let favs = vm.filteredFavoritedSkills
        #expect(favs.count == 1)
        #expect(favs.first?.name == "commit")
    }
}
