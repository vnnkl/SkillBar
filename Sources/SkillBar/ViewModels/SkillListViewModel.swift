import Foundation

@MainActor
@Observable
final class SkillListViewModel {
    private(set) var skills: [Skill] = []
    private(set) var groupedSkills: [SkillSource: [Skill]] = [:]
    private(set) var recentlyCopiedSkillId: Skill.ID?
    private(set) var selectedSkill: Skill?
    var showSettings: Bool = false
    var favoriteNames: Set<String> = []
    var selectedIndex: Int? = nil
    var activeSourceFilter: SkillSource? = nil

    var searchText: String = "" {
        didSet {
            if searchText != oldValue {
                selectedIndex = nil
            }
        }
    }

    private let scanner: SkillScanning
    private let clipboard: ClipboardProvider
    private let fileSystem: FileSystemProvider
    let store: KeyValueStore
    private var clearCopyTask: Task<Void, Never>?
    private var fileWatcher: FileWatching?

    var totalCount: Int { skills.count }

    var orderedSources: [SkillSource] {
        SkillSource.allCases.filter { groupedSkills[$0] != nil }
    }

    init(
        scanner: SkillScanning,
        clipboard: ClipboardProvider = Clipboard(),
        fileSystem: FileSystemProvider = DefaultFileSystemProvider(),
        store: KeyValueStore = UserDefaultsStore()
    ) {
        self.scanner = scanner
        self.clipboard = clipboard
        self.fileSystem = fileSystem
        self.store = store
        if let stored = store.array(forKey: Constants.favoritesKey) {
            self.favoriteNames = Set(stored)
        }
    }

    // MARK: - Detail View

    func selectSkillForDetail(_ skill: Skill) {
        selectedSkill = skill
    }

    func dismissDetail() {
        selectedSkill = nil
    }

    func readSkillContent(_ skill: Skill) -> String {
        do {
            return try fileSystem.contentsOfFile(atPath: skill.filePath)
        } catch {
            return "Could not read skill file: \(error.localizedDescription)"
        }
    }

    func copySkill(_ skill: Skill) {
        clipboard.copy(skill.slashCommand)
        recentlyCopiedSkillId = skill.id
        clearCopyTask?.cancel()
        clearCopyTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            recentlyCopiedSkillId = nil
        }
    }

    func startWatching(_ watcher: FileWatching) {
        fileWatcher?.stop()
        fileWatcher = watcher
        watcher.start(onChange: { [weak self] in
            Task { @MainActor in
                self?.scan()
            }
        })
    }

    func stopWatching() {
        fileWatcher?.stop()
        fileWatcher = nil
    }

    func scan() {
        guard let scanned = try? scanner.scan() else {
            skills = []
            groupedSkills = [:]
            return
        }

        skills = scanned
        groupedSkills = buildGroupedSkills(from: scanned)
    }

    // MARK: - Private

    private func buildGroupedSkills(from skills: [Skill]) -> [SkillSource: [Skill]] {
        var groups: [SkillSource: [Skill]] = [:]
        for skill in skills {
            var group = groups[skill.source, default: []]
            group.append(skill)
            groups[skill.source] = group
        }
        for (source, items) in groups {
            groups[source] = items.sorted { $0.name < $1.name }
        }
        return groups
    }
}
