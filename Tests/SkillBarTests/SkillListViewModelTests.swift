import Testing
@testable import SkillBar

@Suite("SkillListViewModel Tests")
@MainActor
struct SkillListViewModelTests {

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

    // MARK: - Scan

    @Test("Scan populates skills from scanner")
    func scanPopulatesSkills() {
        let skills = [
            makeSkill(name: "commit", source: .local),
            makeSkill(name: "tdd", source: .local)
        ]
        let scanner = makeMockScanner(skills: skills)
        let vm = SkillListViewModel(scanner: scanner)

        vm.scan()

        #expect(vm.skills.count == 2)
        #expect(scanner.scanCallCount == 1)
    }

    @Test("Scan groups skills by source")
    func scanGroupsBySource() {
        let skills = [
            makeSkill(name: "local-skill", source: .local),
            makeSkill(name: "plugin-skill", source: .pluginCache),
            makeSkill(name: "linked-skill", source: .symlink)
        ]
        let scanner = makeMockScanner(skills: skills)
        let vm = SkillListViewModel(scanner: scanner)

        vm.scan()

        #expect(vm.groupedSkills.count == 3)
        #expect(vm.groupedSkills[.local]?.count == 1)
        #expect(vm.groupedSkills[.symlink]?.count == 1)
        #expect(vm.groupedSkills[.pluginCache]?.count == 1)
    }

    @Test("Scan sorts skills alphabetically within groups")
    func scanSortsAlphabetically() {
        let skills = [
            makeSkill(name: "zebra", source: .local),
            makeSkill(name: "alpha", source: .local),
            makeSkill(name: "mango", source: .local)
        ]
        let scanner = makeMockScanner(skills: skills)
        let vm = SkillListViewModel(scanner: scanner)

        vm.scan()

        let localSkills = vm.groupedSkills[.local] ?? []
        #expect(localSkills.map(\.name) == ["alpha", "mango", "zebra"])
    }

    @Test("Scan handles scanner failure gracefully")
    func scanHandlesFailure() {
        let scanner = MockSkillScanner()
        scanner.shouldThrow = true
        let vm = SkillListViewModel(scanner: scanner)

        vm.scan()

        #expect(vm.skills.isEmpty)
        #expect(vm.groupedSkills.isEmpty)
    }

    @Test("Scan replaces previous skills on re-scan")
    func reScanReplacesSkills() {
        let scanner = MockSkillScanner()
        scanner.stubbedSkills = [makeSkill(name: "first")]
        let vm = SkillListViewModel(scanner: scanner)

        vm.scan()
        #expect(vm.skills.count == 1)

        scanner.stubbedSkills = [makeSkill(name: "second"), makeSkill(name: "third")]
        vm.scan()
        #expect(vm.skills.count == 2)
        #expect(vm.skills.map(\.name).contains("second"))
    }

    // MARK: - Skill Count

    @Test("Total count reflects all skills")
    func totalCount() {
        let skills = [
            makeSkill(name: "a", source: .local),
            makeSkill(name: "b", source: .pluginCache)
        ]
        let scanner = makeMockScanner(skills: skills)
        let vm = SkillListViewModel(scanner: scanner)

        vm.scan()

        #expect(vm.totalCount == 2)
    }

    // MARK: - Source Order

    @Test("Grouped skills maintain source display order: local, symlink, pluginCache")
    func sourceDisplayOrder() {
        let skills = [
            makeSkill(name: "c", source: .pluginCache),
            makeSkill(name: "a", source: .local),
            makeSkill(name: "b", source: .symlink)
        ]
        let scanner = makeMockScanner(skills: skills)
        let vm = SkillListViewModel(scanner: scanner)

        vm.scan()

        let orderedSources = vm.orderedSources
        #expect(orderedSources == [.local, .symlink, .pluginCache])
    }

    // MARK: - Copy Skill

    @Test("copySkill copies slash command to clipboard")
    func copySkillCopiesToClipboard() {
        let mockClipboard = MockClipboard()
        let skill = makeSkill(name: "commit")
        let scanner = makeMockScanner(skills: [skill])
        let vm = SkillListViewModel(scanner: scanner, clipboard: mockClipboard)

        vm.copySkill(skill)

        #expect(mockClipboard.lastCopiedString == "/commit")
        #expect(mockClipboard.copyCallCount == 1)
    }

    @Test("copySkill sets recentlyCopiedSkillId")
    func copySkillSetsRecentId() {
        let mockClipboard = MockClipboard()
        let skill = makeSkill(name: "tdd")
        let scanner = makeMockScanner()
        let vm = SkillListViewModel(scanner: scanner, clipboard: mockClipboard)

        #expect(vm.recentlyCopiedSkillId == nil)
        vm.copySkill(skill)
        #expect(vm.recentlyCopiedSkillId == skill.id)
    }

    @Test("copySkill updates recentlyCopiedSkillId when copying different skill")
    func copySkillUpdatesId() {
        let mockClipboard = MockClipboard()
        let skill1 = makeSkill(name: "commit")
        let skill2 = makeSkill(name: "tdd")
        let scanner = makeMockScanner()
        let vm = SkillListViewModel(scanner: scanner, clipboard: mockClipboard)

        vm.copySkill(skill1)
        #expect(vm.recentlyCopiedSkillId == skill1.id)

        vm.copySkill(skill2)
        #expect(vm.recentlyCopiedSkillId == skill2.id)
        #expect(mockClipboard.lastCopiedString == "/tdd")
    }

    @Test("copySkill includes leading slash")
    func copySkillIncludesSlash() {
        let mockClipboard = MockClipboard()
        let skill = makeSkill(name: "review-pr")
        let scanner = makeMockScanner()
        let vm = SkillListViewModel(scanner: scanner, clipboard: mockClipboard)

        vm.copySkill(skill)

        #expect(mockClipboard.lastCopiedString?.hasPrefix("/") == true)
    }

    // MARK: - Search

    @Test("Search filters skills by name")
    func searchFiltersByName() {
        let skills = [
            makeSkill(name: "commit"),
            makeSkill(name: "tdd"),
            makeSkill(name: "review-pr")
        ]
        let scanner = makeMockScanner(skills: skills)
        let vm = SkillListViewModel(scanner: scanner)
        vm.scan()

        vm.searchText = "commit"

        #expect(vm.filteredSkills.count == 1)
        #expect(vm.filteredSkills.first?.name == "commit")
    }

    @Test("Search filters skills by description")
    func searchFiltersByDescription() {
        let skills = [
            makeSkill(name: "commit", description: "Git commit helper"),
            makeSkill(name: "tdd", description: "Test-driven development"),
            makeSkill(name: "review", description: "Code review tool")
        ]
        let scanner = makeMockScanner(skills: skills)
        let vm = SkillListViewModel(scanner: scanner)
        vm.scan()

        vm.searchText = "test"

        #expect(vm.filteredSkills.count == 1)
        #expect(vm.filteredSkills.first?.name == "tdd")
    }

    @Test("Search is case-insensitive")
    func searchIsCaseInsensitive() {
        let skills = [
            makeSkill(name: "Commit"),
            makeSkill(name: "tdd")
        ]
        let scanner = makeMockScanner(skills: skills)
        let vm = SkillListViewModel(scanner: scanner)
        vm.scan()

        vm.searchText = "commit"

        #expect(vm.filteredSkills.count == 1)
    }

    @Test("Empty search shows all skills")
    func emptySearchShowsAll() {
        let skills = [
            makeSkill(name: "commit"),
            makeSkill(name: "tdd")
        ]
        let scanner = makeMockScanner(skills: skills)
        let vm = SkillListViewModel(scanner: scanner)
        vm.scan()

        vm.searchText = ""

        #expect(vm.filteredSkills.count == 2)
    }

    // MARK: - Source Filter

    @Test("Source filter shows only matching source")
    func sourceFilterShowsMatchingSource() {
        let skills = [
            makeSkill(name: "local-skill", source: .local),
            makeSkill(name: "plugin-skill", source: .pluginCache),
            makeSkill(name: "linked-skill", source: .symlink)
        ]
        let scanner = makeMockScanner(skills: skills)
        let vm = SkillListViewModel(scanner: scanner)
        vm.scan()

        vm.activeSourceFilter = .local

        #expect(vm.filteredSkills.count == 1)
        #expect(vm.filteredSkills.first?.source == .local)
    }

    @Test("Nil source filter shows all skills")
    func nilSourceFilterShowsAll() {
        let skills = [
            makeSkill(name: "a", source: .local),
            makeSkill(name: "b", source: .pluginCache)
        ]
        let scanner = makeMockScanner(skills: skills)
        let vm = SkillListViewModel(scanner: scanner)
        vm.scan()

        vm.activeSourceFilter = nil

        #expect(vm.filteredSkills.count == 2)
    }

    // MARK: - Composed Filters

    @Test("Search and source filter compose together")
    func searchAndSourceFilterCompose() {
        let skills = [
            makeSkill(name: "commit", description: "Git helper", source: .local),
            makeSkill(name: "tdd", description: "Testing", source: .local),
            makeSkill(name: "commit-plugin", description: "Plugin commit", source: .pluginCache)
        ]
        let scanner = makeMockScanner(skills: skills)
        let vm = SkillListViewModel(scanner: scanner)
        vm.scan()

        vm.searchText = "commit"
        vm.activeSourceFilter = .local

        #expect(vm.filteredSkills.count == 1)
        #expect(vm.filteredSkills.first?.name == "commit")
    }

    // MARK: - Filtered Count

    @Test("filteredCount reflects filtered skills count")
    func filteredCountReflectsFilter() {
        let skills = [
            makeSkill(name: "a"),
            makeSkill(name: "b"),
            makeSkill(name: "c")
        ]
        let scanner = makeMockScanner(skills: skills)
        let vm = SkillListViewModel(scanner: scanner)
        vm.scan()

        vm.searchText = "a"

        #expect(vm.filteredCount == 1)
        #expect(vm.totalCount == 3)
    }

    // MARK: - Filtered Grouped Skills

    @Test("filteredGroupedSkills respects both search and source filter")
    func filteredGroupedSkillsRespectsBothFilters() {
        let skills = [
            makeSkill(name: "commit", source: .local),
            makeSkill(name: "tdd", source: .local),
            makeSkill(name: "deploy", source: .pluginCache)
        ]
        let scanner = makeMockScanner(skills: skills)
        let vm = SkillListViewModel(scanner: scanner)
        vm.scan()

        vm.searchText = ""
        vm.activeSourceFilter = .local

        let filtered = vm.filteredGroupedSkills
        #expect(filtered[.local]?.count == 2)
        #expect(filtered[.pluginCache] == nil)
    }

    @Test("filteredOrderedSources only includes sources with matching skills")
    func filteredOrderedSourcesRespectsFilter() {
        let skills = [
            makeSkill(name: "a", source: .local),
            makeSkill(name: "b", source: .pluginCache)
        ]
        let scanner = makeMockScanner(skills: skills)
        let vm = SkillListViewModel(scanner: scanner)
        vm.scan()

        vm.activeSourceFilter = .local

        #expect(vm.filteredOrderedSources == [.local])
    }
}
