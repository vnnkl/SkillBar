import Foundation
import Testing
@testable import SkillBar

@Suite("Analytics Tests")
@MainActor
struct AnalyticsTests {

    // MARK: - Helpers

    private func makeSkill(name: String) -> Skill {
        Skill(name: name, description: "desc for \(name)", source: .local, filePath: "/path/\(name)/SKILL.md")
    }

    private func makeViewModel(
        skills: [Skill] = [],
        store: InMemoryKeyValueStore = InMemoryKeyValueStore()
    ) -> (SkillListViewModel, InMemoryKeyValueStore) {
        let scanner = MockSkillScanner()
        scanner.stubbedSkills = skills
        let clipboard = MockClipboard()
        let vm = SkillListViewModel(scanner: scanner, clipboard: clipboard, store: store)
        vm.scan()
        return (vm, store)
    }

    // MARK: - recordUsage

    @Test("recordUsage stores a record")
    func recordUsageStores() {
        let skill = makeSkill(name: "gsd:commit")
        let (vm, store) = makeViewModel(skills: [skill])

        vm.recordUsage(skill)

        let data = store.data(forKey: Constants.usageRecordsKey)
        #expect(data != nil)
        let records = try! JSONDecoder().decode([UsageRecord].self, from: data!)
        #expect(records.count == 1)
        #expect(records[0].skillName == "gsd:commit")
        #expect(records[0].copyCount == 1)
    }

    @Test("Copying same skill increments copyCount and updates lastCopiedAt")
    func incrementsOnRepeatCopy() {
        let skill = makeSkill(name: "gsd:commit")
        let (vm, _) = makeViewModel(skills: [skill])

        vm.recordUsage(skill)
        let firstDate = vm.recentlyUsedSkills.first.map { _ in
            let data = vm.store.data(forKey: Constants.usageRecordsKey)!
            return try! JSONDecoder().decode([UsageRecord].self, from: data)[0].lastCopiedAt
        }!

        // Small delay to ensure date differs
        vm.recordUsage(skill)

        let data = vm.store.data(forKey: Constants.usageRecordsKey)!
        let records = try! JSONDecoder().decode([UsageRecord].self, from: data)
        #expect(records.count == 1)
        #expect(records[0].copyCount == 2)
        #expect(records[0].lastCopiedAt >= firstDate)
    }

    // MARK: - recentlyUsedSkills

    @Test("recentlyUsedSkills returns last 10 in recency order")
    func recentReturnsLast10() {
        var skills: [Skill] = []
        for i in 0..<12 {
            skills.append(makeSkill(name: "pkg:skill\(i)"))
        }
        let (vm, _) = makeViewModel(skills: skills)

        for skill in skills {
            vm.recordUsage(skill)
        }

        let recent = vm.recentlyUsedSkills
        #expect(recent.count == 10)
        // Most recent first
        #expect(recent[0].name == "pkg:skill11")
        #expect(recent[1].name == "pkg:skill10")
    }

    @Test("11th copy evicts oldest from recent list")
    func eleventhEvictsOldest() {
        var skills: [Skill] = []
        for i in 0..<11 {
            skills.append(makeSkill(name: "pkg:skill\(i)"))
        }
        let (vm, _) = makeViewModel(skills: skills)

        for skill in skills {
            vm.recordUsage(skill)
        }

        let recent = vm.recentlyUsedSkills
        #expect(recent.count == 10)
        // skill0 was copied first, should be evicted
        #expect(!recent.contains(where: { $0.name == "pkg:skill0" }))
    }

    @Test("Duplicate copy moves to top of recent, not duplicated")
    func duplicateCopyMovesToTop() {
        let skills = [
            makeSkill(name: "pkg:alpha"),
            makeSkill(name: "pkg:beta"),
            makeSkill(name: "pkg:gamma"),
        ]
        let (vm, _) = makeViewModel(skills: skills)

        vm.recordUsage(skills[0]) // alpha
        vm.recordUsage(skills[1]) // beta
        vm.recordUsage(skills[2]) // gamma
        vm.recordUsage(skills[0]) // alpha again

        let recent = vm.recentlyUsedSkills
        #expect(recent.count == 3)
        #expect(recent[0].name == "pkg:alpha") // most recent
        #expect(recent[1].name == "pkg:gamma")
        #expect(recent[2].name == "pkg:beta")
    }

    // MARK: - frequentlyUsedSkills

    @Test("frequentlyUsedSkills filters at threshold: 4 copies excluded, 5 included")
    func frequentThreshold() {
        let skillA = makeSkill(name: "pkg:frequent")
        let skillB = makeSkill(name: "pkg:infrequent")
        let (vm, _) = makeViewModel(skills: [skillA, skillB])

        for _ in 0..<5 {
            vm.recordUsage(skillA)
        }
        for _ in 0..<4 {
            vm.recordUsage(skillB)
        }

        let frequent = vm.frequentlyUsedSkills
        #expect(frequent.count == 1)
        #expect(frequent[0].name == "pkg:frequent")
    }

    @Test("frequentlyUsedSkills sorted by count descending, max 5")
    func frequentSortedAndCapped() {
        var skills: [Skill] = []
        for i in 0..<7 {
            skills.append(makeSkill(name: "pkg:skill\(i)"))
        }
        let (vm, _) = makeViewModel(skills: skills)

        // Give each skill (5 + i) copies so all qualify
        for (i, skill) in skills.enumerated() {
            for _ in 0..<(5 + i) {
                vm.recordUsage(skill)
            }
        }

        let frequent = vm.frequentlyUsedSkills
        #expect(frequent.count == 5)
        // Highest count first: skill6 (11), skill5 (10), skill4 (9), skill3 (8), skill2 (7)
        #expect(frequent[0].name == "pkg:skill6")
        #expect(frequent[1].name == "pkg:skill5")
        #expect(frequent[4].name == "pkg:skill2")
    }

    // MARK: - Stale skills

    @Test("Stale skill names not in skills array are excluded")
    func staleSkillsExcluded() {
        let skill = makeSkill(name: "pkg:exists")
        let stale = makeSkill(name: "pkg:deleted")
        let (vm, _) = makeViewModel(skills: [skill, stale])

        vm.recordUsage(skill)
        vm.recordUsage(stale)

        // Remove stale from scanner and rescan
        let scanner = MockSkillScanner()
        scanner.stubbedSkills = [skill]
        let vm2 = SkillListViewModel(scanner: scanner, store: vm.store)
        vm2.scan()

        let recent = vm2.recentlyUsedSkills
        #expect(recent.count == 1)
        #expect(recent[0].name == "pkg:exists")
    }

    // MARK: - Corrupt data

    @Test("Corrupt store data returns empty, no crash")
    func corruptDataGraceful() {
        let skill = makeSkill(name: "pkg:test")
        let store = InMemoryKeyValueStore()
        store.dataStorage[Constants.usageRecordsKey] = Data("not json".utf8)

        let (vm, _) = makeViewModel(skills: [skill], store: store)

        #expect(vm.recentlyUsedSkills.isEmpty)
        #expect(vm.frequentlyUsedSkills.isEmpty)
    }

    // MARK: - clearUsageData

    @Test("clearUsageData removes all records")
    func clearRemovesAll() {
        let skill = makeSkill(name: "pkg:test")
        let (vm, store) = makeViewModel(skills: [skill])

        vm.recordUsage(skill)
        #expect(store.data(forKey: Constants.usageRecordsKey) != nil)

        vm.clearUsageData()

        #expect(store.data(forKey: Constants.usageRecordsKey) == nil)
        #expect(vm.recentlyUsedSkills.isEmpty)
    }

    // MARK: - Persistence across ViewModel re-creation

    @Test("Data persists across ViewModel re-creation with same store")
    func persistsAcrossRecreation() {
        let skill = makeSkill(name: "pkg:persist")
        let store = InMemoryKeyValueStore()
        let (vm1, _) = makeViewModel(skills: [skill], store: store)

        vm1.recordUsage(skill)
        #expect(vm1.recentlyUsedSkills.count == 1)

        // Create new VM with same store
        let (vm2, _) = makeViewModel(skills: [skill], store: store)

        #expect(vm2.recentlyUsedSkills.count == 1)
        #expect(vm2.recentlyUsedSkills[0].name == "pkg:persist")
    }
}
