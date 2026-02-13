import Foundation

extension SkillListViewModel {

    var filteredSkills: [Skill] {
        skills.filter { matchesSearch($0) && matchesSourceFilter($0) }
    }

    var filteredCount: Int { filteredSkills.count }

    var filteredGroupedSkills: [SkillSource: [Skill]] {
        var groups: [SkillSource: [Skill]] = [:]
        for skill in filteredSkills {
            var group = groups[skill.source, default: []]
            group.append(skill)
            groups[skill.source] = group
        }
        for (source, items) in groups {
            groups[source] = items.sorted { $0.name < $1.name }
        }
        return groups
    }

    var filteredOrderedSources: [SkillSource] {
        let filtered = filteredGroupedSkills
        return SkillSource.allCases.filter { filtered[$0] != nil }
    }

    // MARK: - Private

    private func matchesSearch(_ skill: Skill) -> Bool {
        guard !searchText.isEmpty else { return true }
        let query = searchText.lowercased()
        return skill.name.lowercased().contains(query)
            || skill.description.lowercased().contains(query)
    }

    private func matchesSourceFilter(_ skill: Skill) -> Bool {
        guard let filter = activeSourceFilter else { return true }
        return skill.source == filter
    }
}
