import Foundation
import Testing
@testable import SkillBar

@Suite("WorkflowMemory Tests")
@MainActor
struct WorkflowMemoryTests {

    // MARK: - Helpers

    private func makeSkill(name: String) -> Skill {
        Skill(name: name, description: "desc", source: .local, filePath: "/path/\(name)/SKILL.md")
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

    private func decodeMatrix(from store: InMemoryKeyValueStore) -> [String: [String: Int]] {
        guard let data = store.data(forKey: Constants.transitionMatrixKey) else { return [:] }
        return (try? JSONDecoder().decode([String: [String: Int]].self, from: data)) ?? [:]
    }

    // MARK: - Transition Recording

    @Test("First copy sets lastLaunchedSkillName, no transition recorded")
    func firstCopyNoTransition() {
        let skill = makeSkill(name: "alpha")
        let (vm, store) = makeViewModel(skills: [skill])

        vm.recordUsage(skill)

        #expect(vm.lastLaunchedSkillName == "alpha")
        let matrix = decodeMatrix(from: store)
        #expect(matrix.isEmpty)
    }

    @Test("A then B records matrix[A][B] == 1")
    func aThenBRecordsTransition() {
        let a = makeSkill(name: "A")
        let b = makeSkill(name: "B")
        let (vm, store) = makeViewModel(skills: [a, b])

        vm.recordUsage(a)
        vm.recordUsage(b)

        let matrix = decodeMatrix(from: store)
        #expect(matrix["A"]?["B"] == 1)
    }

    @Test("A→B repeated 5 times yields count 5")
    func repeatedTransitionAccumulates() {
        let a = makeSkill(name: "A")
        let b = makeSkill(name: "B")
        let (vm, store) = makeViewModel(skills: [a, b])

        for _ in 0..<5 {
            vm.recordUsage(a)
            vm.recordUsage(b)
        }

        let matrix = decodeMatrix(from: store)
        #expect(matrix["A"]?["B"] == 5)
    }

    @Test("Self-transition A→A not recorded in matrix")
    func selfTransitionNotRecorded() {
        let a = makeSkill(name: "A")
        let (vm, store) = makeViewModel(skills: [a])

        vm.recordUsage(a)
        vm.recordUsage(a)

        let matrix = decodeMatrix(from: store)
        #expect(matrix["A"]?["A"] == nil)
    }

    @Test("A→B then B→A records both directions independently")
    func bidirectionalTransitions() {
        let a = makeSkill(name: "A")
        let b = makeSkill(name: "B")
        let (vm, store) = makeViewModel(skills: [a, b])

        vm.recordUsage(a)
        vm.recordUsage(b)
        vm.recordUsage(a)

        let matrix = decodeMatrix(from: store)
        #expect(matrix["A"]?["B"] == 1)
        #expect(matrix["B"]?["A"] == 1)
    }

    // MARK: - Suggestions

    @Test("suggestedNextSkills empty when lastLaunchedSkillName is nil")
    func suggestionsEmptyWhenNoLast() {
        let skill = makeSkill(name: "A")
        let (vm, _) = makeViewModel(skills: [skill])

        #expect(vm.suggestedNextSkills.isEmpty)
    }

    @Test("Empty when no transitions exist for last skill")
    func suggestionsEmptyNoTransitions() {
        let a = makeSkill(name: "A")
        let (vm, _) = makeViewModel(skills: [a])

        vm.recordUsage(a)

        #expect(vm.suggestedNextSkills.isEmpty)
    }

    @Test("Empty when all transitions below threshold")
    func suggestionsBelowThreshold() {
        let a = makeSkill(name: "A")
        let b = makeSkill(name: "B")
        let (vm, _) = makeViewModel(skills: [a, b])

        // Only 2 transitions (below threshold of 3)
        vm.recordUsage(a)
        vm.recordUsage(b)
        vm.recordUsage(a)
        vm.recordUsage(b)

        // lastLaunched is now B, but we want to check A→B
        vm.recordUsage(a) // set last to A
        #expect(vm.suggestedNextSkills.isEmpty)
    }

    @Test("Returns skill when count >= threshold")
    func suggestionsAboveThreshold() {
        let a = makeSkill(name: "A")
        let b = makeSkill(name: "B")
        let (vm, _) = makeViewModel(skills: [a, b])

        for _ in 0..<3 {
            vm.recordUsage(a)
            vm.recordUsage(b)
        }
        // lastLaunched is B, set back to A
        vm.recordUsage(a)

        let suggestions = vm.suggestedNextSkills
        #expect(suggestions.count == 1)
        #expect(suggestions[0].name == "B")
    }

    @Test("Returns max 2 skills sorted by count descending")
    func suggestionsMaxTwoSortedDesc() {
        let a = makeSkill(name: "A")
        let b = makeSkill(name: "B")
        let c = makeSkill(name: "C")
        let d = makeSkill(name: "D")
        let (vm, _) = makeViewModel(skills: [a, b, c, d])

        // A→B: 5 times
        for _ in 0..<5 {
            vm.recordUsage(a)
            vm.recordUsage(b)
        }
        // A→C: 4 times
        for _ in 0..<4 {
            vm.recordUsage(a)
            vm.recordUsage(c)
        }
        // A→D: 3 times
        for _ in 0..<3 {
            vm.recordUsage(a)
            vm.recordUsage(d)
        }
        // Set last to A
        vm.recordUsage(a)

        let suggestions = vm.suggestedNextSkills
        #expect(suggestions.count == 2)
        #expect(suggestions[0].name == "B")
        #expect(suggestions[1].name == "C")
    }

    @Test("Stale skill name not in skills array excluded from suggestions")
    func staleSkillExcluded() {
        let a = makeSkill(name: "A")
        let b = makeSkill(name: "B")
        let (vm, store) = makeViewModel(skills: [a, b])

        for _ in 0..<3 {
            vm.recordUsage(a)
            vm.recordUsage(b)
        }

        // Recreate VM without B
        let scanner = MockSkillScanner()
        scanner.stubbedSkills = [a]
        let vm2 = SkillListViewModel(scanner: scanner, clipboard: MockClipboard(), store: store)
        vm2.scan()
        // lastLaunched loaded from store; set to A
        vm2.recordUsage(a)

        #expect(vm2.suggestedNextSkills.isEmpty)
    }

    @Test("Respects search filter")
    func suggestionsRespectSearchFilter() {
        let a = makeSkill(name: "A")
        let b = makeSkill(name: "B")
        let (vm, _) = makeViewModel(skills: [a, b])

        for _ in 0..<3 {
            vm.recordUsage(a)
            vm.recordUsage(b)
        }
        vm.recordUsage(a)
        vm.searchText = "zzz-no-match"

        #expect(vm.suggestedNextSkills.isEmpty)
    }

    @Test("Respects source filter")
    func suggestionsRespectSourceFilter() {
        let a = makeSkill(name: "A")
        let b = makeSkill(name: "B")
        let (vm, _) = makeViewModel(skills: [a, b])

        for _ in 0..<3 {
            vm.recordUsage(a)
            vm.recordUsage(b)
        }
        vm.recordUsage(a)
        vm.activeSourceFilter = .pluginCache // B is .local, won't match

        #expect(vm.suggestedNextSkills.isEmpty)
    }

    @Test("Respects tag filter")
    func suggestionsRespectTagFilter() {
        let a = makeSkill(name: "A")
        let b = makeSkill(name: "B")
        let (vm, _) = makeViewModel(skills: [a, b])

        for _ in 0..<3 {
            vm.recordUsage(a)
            vm.recordUsage(b)
        }
        vm.recordUsage(a)
        vm.activeTagFilters = Set(["nonexistent-tag"])

        #expect(vm.suggestedNextSkills.isEmpty)
    }

    // MARK: - Persistence

    @Test("lastLaunchedSkillName survives VM re-creation")
    func lastLaunchedPersists() {
        let a = makeSkill(name: "A")
        let store = InMemoryKeyValueStore()
        let (vm1, _) = makeViewModel(skills: [a], store: store)

        vm1.recordUsage(a)
        #expect(vm1.lastLaunchedSkillName == "A")

        let (vm2, _) = makeViewModel(skills: [a], store: store)
        #expect(vm2.lastLaunchedSkillName == "A")
    }

    @Test("Transition matrix survives VM re-creation")
    func matrixPersists() {
        let a = makeSkill(name: "A")
        let b = makeSkill(name: "B")
        let store = InMemoryKeyValueStore()
        let (vm1, _) = makeViewModel(skills: [a, b], store: store)

        for _ in 0..<3 {
            vm1.recordUsage(a)
            vm1.recordUsage(b)
        }

        let (vm2, _) = makeViewModel(skills: [a, b], store: store)
        vm2.recordUsage(a) // set last to A

        let suggestions = vm2.suggestedNextSkills
        #expect(suggestions.count == 1)
        #expect(suggestions[0].name == "B")
    }

    // MARK: - Clear

    @Test("clearUsageData removes matrix, lastLaunched, and usage records")
    func clearRemovesAll() {
        let a = makeSkill(name: "A")
        let b = makeSkill(name: "B")
        let (vm, store) = makeViewModel(skills: [a, b])

        for _ in 0..<3 {
            vm.recordUsage(a)
            vm.recordUsage(b)
        }

        #expect(store.data(forKey: Constants.usageRecordsKey) != nil)
        #expect(store.data(forKey: Constants.transitionMatrixKey) != nil)
        #expect(store.storage[Constants.lastLaunchedSkillKey] != nil)

        vm.clearUsageData()

        #expect(store.data(forKey: Constants.usageRecordsKey) == nil)
        #expect(store.data(forKey: Constants.transitionMatrixKey) == nil)
        #expect(store.storage[Constants.lastLaunchedSkillKey] == nil)
        #expect(vm.lastLaunchedSkillName == nil)
    }

    // MARK: - Corrupt Data

    @Test("Corrupt matrix JSON returns empty suggestions, no crash")
    func corruptMatrixGraceful() {
        let a = makeSkill(name: "A")
        let store = InMemoryKeyValueStore()
        store.dataStorage[Constants.transitionMatrixKey] = Data("not json".utf8)
        store.storage[Constants.lastLaunchedSkillKey] = ["A"]

        let (vm, _) = makeViewModel(skills: [a], store: store)

        #expect(vm.suggestedNextSkills.isEmpty)
    }
}
