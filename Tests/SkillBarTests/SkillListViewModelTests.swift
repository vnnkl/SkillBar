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

    // MARK: - File Watcher

    @Test("startWatching starts the file watcher")
    func startWatchingStartsWatcher() {
        let scanner = makeMockScanner()
        let watcher = MockFileWatcher()
        let vm = SkillListViewModel(scanner: scanner)

        vm.startWatching(watcher)

        #expect(watcher.startCallCount == 1)
    }

    @Test("stopWatching stops the file watcher")
    func stopWatchingStopsWatcher() {
        let scanner = makeMockScanner()
        let watcher = MockFileWatcher()
        let vm = SkillListViewModel(scanner: scanner)

        vm.startWatching(watcher)
        vm.stopWatching()

        #expect(watcher.stopCallCount == 1)
    }

    @Test("File watcher onChange triggers rescan")
    func fileWatcherOnChangeTriggersScan() async throws {
        let scanner = makeMockScanner(skills: [makeSkill(name: "a")])
        let watcher = MockFileWatcher()
        let vm = SkillListViewModel(scanner: scanner)

        vm.startWatching(watcher)
        #expect(scanner.scanCallCount == 0)

        watcher.simulateChange()

        // Yield to allow the MainActor task to execute
        try await Task.sleep(for: .milliseconds(10))

        #expect(scanner.scanCallCount == 1)
        #expect(vm.skills.count == 1)
    }

    @Test("Starting a new watcher stops the previous one")
    func startWatchingStopsPreviousWatcher() {
        let scanner = makeMockScanner()
        let watcher1 = MockFileWatcher()
        let watcher2 = MockFileWatcher()
        let vm = SkillListViewModel(scanner: scanner)

        vm.startWatching(watcher1)
        vm.startWatching(watcher2)

        #expect(watcher1.stopCallCount == 1)
        #expect(watcher2.startCallCount == 1)
    }

    // MARK: - Detail View

    @Test("selectedSkill is nil by default")
    func selectedSkillDefaultsToNil() {
        let vm = SkillListViewModel(scanner: makeMockScanner())
        #expect(vm.selectedSkill == nil)
    }

    @Test("selectSkillForDetail sets selectedSkill")
    func selectSkillForDetailSetsSkill() {
        let skill = makeSkill(name: "commit")
        let vm = SkillListViewModel(scanner: makeMockScanner(skills: [skill]))
        vm.scan()

        vm.selectSkillForDetail(skill)

        #expect(vm.selectedSkill == skill)
    }

    @Test("dismissDetail clears selectedSkill")
    func dismissDetailClearsSkill() {
        let skill = makeSkill(name: "commit")
        let vm = SkillListViewModel(scanner: makeMockScanner(skills: [skill]))
        vm.scan()

        vm.selectSkillForDetail(skill)
        #expect(vm.selectedSkill != nil)

        vm.dismissDetail()
        #expect(vm.selectedSkill == nil)
    }

    @Test("readSkillContent returns file content for valid path")
    func readSkillContentReturnsContent() {
        let fs = MockFileSystemProvider()
        fs.files["/path/commit/SKILL.md"] = "# Commit Skill\nDoes things"
        let scanner = MockSkillScanner()
        let vm = SkillListViewModel(scanner: scanner, fileSystem: fs)
        let skill = makeSkill(name: "commit")

        let content = vm.readSkillContent(skill)

        #expect(content == "# Commit Skill\nDoes things")
    }

    @Test("readSkillContent returns error message when file missing")
    func readSkillContentReturnsErrorForMissingFile() {
        let fs = MockFileSystemProvider()
        let scanner = MockSkillScanner()
        let vm = SkillListViewModel(scanner: scanner, fileSystem: fs)
        let skill = makeSkill(name: "gone")

        let content = vm.readSkillContent(skill)

        #expect(content.contains("Could not read"))
    }

    // MARK: - Keyboard Navigation

    @Test("selectedIndex is nil by default")
    func selectedIndexDefaultsToNil() {
        let vm = SkillListViewModel(scanner: makeMockScanner())
        #expect(vm.selectedIndex == nil)
    }

    @Test("moveDown selects first item when no selection")
    func moveDownSelectsFirstItem() {
        let skills = [makeSkill(name: "a"), makeSkill(name: "b"), makeSkill(name: "c")]
        let vm = SkillListViewModel(scanner: makeMockScanner(skills: skills))
        vm.scan()

        vm.moveDown()

        #expect(vm.selectedIndex == 0)
    }

    @Test("moveDown advances to next item")
    func moveDownAdvancesToNext() {
        let skills = [makeSkill(name: "a"), makeSkill(name: "b"), makeSkill(name: "c")]
        let vm = SkillListViewModel(scanner: makeMockScanner(skills: skills))
        vm.scan()

        vm.moveDown()
        vm.moveDown()

        #expect(vm.selectedIndex == 1)
    }

    @Test("moveDown wraps to first item at end of list")
    func moveDownWrapsAtEnd() {
        let skills = [makeSkill(name: "a"), makeSkill(name: "b")]
        let vm = SkillListViewModel(scanner: makeMockScanner(skills: skills))
        vm.scan()

        vm.moveDown()  // 0
        vm.moveDown()  // 1
        vm.moveDown()  // wraps to 0

        #expect(vm.selectedIndex == 0)
    }

    @Test("moveUp selects last item when no selection")
    func moveUpSelectsLastItem() {
        let skills = [makeSkill(name: "a"), makeSkill(name: "b"), makeSkill(name: "c")]
        let vm = SkillListViewModel(scanner: makeMockScanner(skills: skills))
        vm.scan()

        vm.moveUp()

        #expect(vm.selectedIndex == 2)
    }

    @Test("moveUp moves to previous item")
    func moveUpMovesToPrevious() {
        let skills = [makeSkill(name: "a"), makeSkill(name: "b"), makeSkill(name: "c")]
        let vm = SkillListViewModel(scanner: makeMockScanner(skills: skills))
        vm.scan()

        vm.moveDown()  // 0
        vm.moveDown()  // 1
        vm.moveUp()    // 0

        #expect(vm.selectedIndex == 0)
    }

    @Test("moveUp wraps to last item at beginning of list")
    func moveUpWrapsAtBeginning() {
        let skills = [makeSkill(name: "a"), makeSkill(name: "b"), makeSkill(name: "c")]
        let vm = SkillListViewModel(scanner: makeMockScanner(skills: skills))
        vm.scan()

        vm.moveDown()  // 0
        vm.moveUp()    // wraps to 2

        #expect(vm.selectedIndex == 2)
    }

    @Test("confirmSelection copies selected skill")
    func confirmSelectionCopiesSkill() {
        let mockClipboard = MockClipboard()
        let skills = [makeSkill(name: "commit"), makeSkill(name: "tdd")]
        let vm = SkillListViewModel(scanner: makeMockScanner(skills: skills), clipboard: mockClipboard)
        vm.scan()

        vm.moveDown()  // select index 0
        vm.confirmSelection()

        #expect(mockClipboard.copyCallCount == 1)
    }

    @Test("confirmSelection does nothing with no selection")
    func confirmSelectionDoesNothingWithNoSelection() {
        let mockClipboard = MockClipboard()
        let skills = [makeSkill(name: "commit")]
        let vm = SkillListViewModel(scanner: makeMockScanner(skills: skills), clipboard: mockClipboard)
        vm.scan()

        vm.confirmSelection()

        #expect(mockClipboard.copyCallCount == 0)
    }

    @Test("moveDown does nothing with empty list")
    func moveDownDoesNothingWhenEmpty() {
        let vm = SkillListViewModel(scanner: makeMockScanner())
        vm.scan()

        vm.moveDown()

        #expect(vm.selectedIndex == nil)
    }

    @Test("moveUp does nothing with empty list")
    func moveUpDoesNothingWhenEmpty() {
        let vm = SkillListViewModel(scanner: makeMockScanner())
        vm.scan()

        vm.moveUp()

        #expect(vm.selectedIndex == nil)
    }

    @Test("Navigation uses filteredSkills order")
    func navigationUsesFilteredSkills() {
        let mockClipboard = MockClipboard()
        let skills = [
            makeSkill(name: "commit", description: "git"),
            makeSkill(name: "tdd", description: "testing"),
            makeSkill(name: "review", description: "code review")
        ]
        let vm = SkillListViewModel(scanner: makeMockScanner(skills: skills), clipboard: mockClipboard)
        vm.scan()

        vm.searchText = "commit"
        vm.moveDown()  // select first filtered item
        vm.confirmSelection()

        #expect(mockClipboard.lastCopiedString == "/commit")
    }

    @Test("Selection resets when search text changes")
    func selectionResetsOnSearchChange() {
        let skills = [makeSkill(name: "a"), makeSkill(name: "b")]
        let vm = SkillListViewModel(scanner: makeMockScanner(skills: skills))
        vm.scan()

        vm.moveDown()
        #expect(vm.selectedIndex == 0)

        vm.searchText = "b"
        #expect(vm.selectedIndex == nil)
    }
}
