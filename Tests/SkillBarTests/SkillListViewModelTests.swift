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
}
