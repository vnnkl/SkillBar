import Foundation

@MainActor
@Observable
final class SkillListViewModel {
    private(set) var skills: [Skill] = []
    private(set) var groupedSkills: [SkillSource: [Skill]] = [:]
    private(set) var recentlyCopiedSkillId: Skill.ID?
    var searchText: String = ""
    var activeSourceFilter: SkillSource? = nil

    private let scanner: SkillScanning
    private let clipboard: ClipboardProvider
    private var clearCopyTask: Task<Void, Never>?

    var totalCount: Int { skills.count }

    var orderedSources: [SkillSource] {
        SkillSource.allCases.filter { groupedSkills[$0] != nil }
    }

    init(scanner: SkillScanning, clipboard: ClipboardProvider = Clipboard()) {
        self.scanner = scanner
        self.clipboard = clipboard
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
