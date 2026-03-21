import Testing
import Foundation
@testable import SkillBar

@Suite("Tag Tests")
@MainActor
struct TagTests {

    // MARK: - Helpers

    private func makeSkill(
        name: String,
        description: String = "",
        source: SkillSource = .local
    ) -> Skill {
        Skill(name: name, description: description, source: source, filePath: "/path/\(name)/SKILL.md")
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

    // MARK: - Add Tag

    @Test("addTag adds tag to skill")
    func addTagAddsToSkill() {
        let skill = makeSkill(name: "gsd:commit")
        let (vm, _) = makeViewModel(skills: [skill])

        vm.addTag("testing", to: skill)

        #expect(vm.tags(for: skill) == ["testing"])
    }

    @Test("removeTag removes tag from skill")
    func removeTagRemovesFromSkill() {
        let skill = makeSkill(name: "gsd:commit")
        let (vm, _) = makeViewModel(skills: [skill])

        vm.addTag("testing", to: skill)
        vm.addTag("deploy", to: skill)
        vm.removeTag("testing", from: skill)

        #expect(vm.tags(for: skill) == ["deploy"])
    }

    // MARK: - Persistence

    @Test("Tags persist to store")
    func tagsPersistToStore() {
        let store = InMemoryKeyValueStore()
        let skill = makeSkill(name: "gsd:commit")
        let (vm, _) = makeViewModel(skills: [skill], store: store)

        vm.addTag("testing", to: skill)

        let data = store.data(forKey: Constants.skillTagsKey)
        #expect(data != nil)
        let decoded = try? JSONDecoder().decode([String: [String]].self, from: data!)
        #expect(decoded?["gsd:commit"] == ["testing"])
    }

    @Test("Tags load from store on init")
    func tagsLoadOnInit() {
        let store = InMemoryKeyValueStore()
        let tagData: [String: [String]] = ["gsd:commit": ["testing", "deploy"]]
        let data = try! JSONEncoder().encode(tagData)
        store.set(data, forKey: Constants.skillTagsKey)

        let skill = makeSkill(name: "gsd:commit")
        let (vm, _) = makeViewModel(skills: [skill], store: store)

        #expect(vm.tags(for: skill) == ["testing", "deploy"])
    }

    @Test("Tags persist across re-created VM with same store")
    func tagsPersistAcrossVMRecreation() {
        let store = InMemoryKeyValueStore()
        let skill = makeSkill(name: "gsd:commit")

        let (vm1, _) = makeViewModel(skills: [skill], store: store)
        vm1.addTag("testing", to: skill)

        let (vm2, _) = makeViewModel(skills: [skill], store: store)
        #expect(vm2.tags(for: skill) == ["testing"])
    }

    // MARK: - Validation

    @Test("Empty tag is rejected")
    func emptyTagRejected() {
        let skill = makeSkill(name: "gsd:commit")
        let (vm, _) = makeViewModel(skills: [skill])

        vm.addTag("", to: skill)

        #expect(vm.tags(for: skill).isEmpty)
    }

    @Test("Whitespace-only tag is rejected")
    func whitespaceOnlyTagRejected() {
        let skill = makeSkill(name: "gsd:commit")
        let (vm, _) = makeViewModel(skills: [skill])

        vm.addTag("   ", to: skill)

        #expect(vm.tags(for: skill).isEmpty)
    }

    @Test("Tag exceeding max length is truncated to 30 chars")
    func tagTruncatedToMaxLength() {
        let skill = makeSkill(name: "gsd:commit")
        let (vm, _) = makeViewModel(skills: [skill])

        let longTag = String(repeating: "a", count: 50)
        vm.addTag(longTag, to: skill)

        let result = vm.tags(for: skill).first
        #expect(result?.count == Constants.maxTagLength)
    }

    @Test("Max 5 tags per skill enforced")
    func maxTagsPerSkillEnforced() {
        let skill = makeSkill(name: "gsd:commit")
        let (vm, _) = makeViewModel(skills: [skill])

        for i in 0..<7 {
            vm.addTag("tag\(i)", to: skill)
        }

        #expect(vm.tags(for: skill).count == Constants.maxTagsPerSkill)
    }

    @Test("Case-insensitive dedup: adding Swift when swift exists is no-op")
    func caseInsensitiveDedupPreventsAdd() {
        let skill = makeSkill(name: "gsd:commit")
        let (vm, _) = makeViewModel(skills: [skill])

        vm.addTag("swift", to: skill)
        vm.addTag("Swift", to: skill)
        vm.addTag("SWIFT", to: skill)

        #expect(vm.tags(for: skill) == ["swift"])
    }

    // MARK: - allTags

    @Test("allTags returns sorted unique tags across all skills")
    func allTagsSortedUnique() {
        let skills = [
            makeSkill(name: "gsd:commit"),
            makeSkill(name: "gsd:review"),
        ]
        let (vm, _) = makeViewModel(skills: skills)

        vm.addTag("deploy", to: skills[0])
        vm.addTag("testing", to: skills[0])
        vm.addTag("testing", to: skills[1])
        vm.addTag("alpha", to: skills[1])

        #expect(vm.allTags == ["alpha", "deploy", "testing"])
    }

    // MARK: - Tag Filters

    @Test("toggleTagFilter adds and removes from activeTagFilters")
    func toggleTagFilterAddRemove() {
        let (vm, _) = makeViewModel()

        vm.toggleTagFilter("testing")
        #expect(vm.activeTagFilters == Set(["testing"]))

        vm.toggleTagFilter("testing")
        #expect(vm.activeTagFilters.isEmpty)
    }

    @Test("AND filter logic: skill must have ALL active tags")
    func andFilterLogic() {
        let skills = [
            makeSkill(name: "gsd:commit"),
            makeSkill(name: "gsd:review"),
        ]
        let (vm, _) = makeViewModel(skills: skills)

        vm.addTag("testing", to: skills[0])
        vm.addTag("deploy", to: skills[0])
        vm.addTag("testing", to: skills[1])

        vm.toggleTagFilter("testing")
        vm.toggleTagFilter("deploy")

        let filtered = vm.filteredSkills
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "gsd:commit")
    }

    @Test("No active tags = all skills pass filter")
    func noActiveTagsPassesAll() {
        let skills = [
            makeSkill(name: "gsd:commit"),
            makeSkill(name: "gsd:review"),
        ]
        let (vm, _) = makeViewModel(skills: skills)

        vm.addTag("testing", to: skills[0])

        #expect(vm.filteredSkills.count == 2)
    }

    @Test("Tag filter composes with search and source filter")
    func tagFilterComposesWithSearchAndSource() {
        let skills = [
            makeSkill(name: "gsd:commit", description: "Git operations"),
            makeSkill(name: "gsd:review", description: "Code review"),
            makeSkill(name: "tdd", description: "Testing workflow"),
        ]
        let (vm, _) = makeViewModel(skills: skills)

        vm.addTag("workflow", to: skills[0])
        vm.addTag("workflow", to: skills[1])
        vm.addTag("workflow", to: skills[2])

        // Tag filter + search
        vm.toggleTagFilter("workflow")
        vm.searchText = "git"

        let filtered = vm.filteredSkills
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "gsd:commit")
    }

    // MARK: - Delete Tag Globally

    @Test("deleteTagGlobally removes tag from all skills")
    func deleteTagGloballyRemovesFromAll() {
        let skills = [
            makeSkill(name: "gsd:commit"),
            makeSkill(name: "gsd:review"),
        ]
        let (vm, _) = makeViewModel(skills: skills)

        vm.addTag("testing", to: skills[0])
        vm.addTag("testing", to: skills[1])
        vm.addTag("deploy", to: skills[0])

        vm.deleteTagGlobally("testing")

        #expect(vm.tags(for: skills[0]) == ["deploy"])
        #expect(vm.tags(for: skills[1]).isEmpty)
    }

    // MARK: - Clear All Tags

    @Test("clearAllTags removes all tag data")
    func clearAllTagsRemovesAll() {
        let skills = [
            makeSkill(name: "gsd:commit"),
            makeSkill(name: "gsd:review"),
        ]
        let (vm, store) = makeViewModel(skills: skills)

        vm.addTag("testing", to: skills[0])
        vm.addTag("deploy", to: skills[1])

        vm.clearAllTags()

        #expect(vm.tags(for: skills[0]).isEmpty)
        #expect(vm.tags(for: skills[1]).isEmpty)
        #expect(store.data(forKey: Constants.skillTagsKey) == nil)
    }

    // MARK: - Corrupt Data

    @Test("Corrupt tag data defaults to empty dict")
    func corruptDataDefaultsToEmpty() {
        let store = InMemoryKeyValueStore()
        store.set(Data("not valid json".utf8), forKey: Constants.skillTagsKey)

        let skill = makeSkill(name: "gsd:commit")
        let (vm, _) = makeViewModel(skills: [skill], store: store)

        #expect(vm.tags(for: skill).isEmpty)
        #expect(vm.skillTags.isEmpty)
    }
}
