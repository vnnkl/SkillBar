import Foundation

extension SkillListViewModel {

    var filteredSkills: [Skill] {
        let base = skills.filter { matchesSourceFilter($0) }
        guard !searchText.isEmpty else { return base }
        return SearchRanker.rank(base, query: searchText)
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

    var filteredPackageGroupedSkills: [String: [Skill]] {
        var groups: [String: [Skill]] = [:]
        for skill in filteredSkills {
            let key = skill.package ?? Constants.standalonePackageKey
            var group = groups[key, default: []]
            group.append(skill)
            groups[key] = group
        }
        for (key, items) in groups {
            groups[key] = items.sorted { $0.displayName < $1.displayName }
        }
        return groups
    }

    var filteredOrderedPackages: [String] {
        filteredPackageGroupedSkills.keys.sorted()
    }

    // MARK: - Internal

    func matchesSourceFilter(_ skill: Skill) -> Bool {
        guard let filter = activeSourceFilter else { return true }
        return skill.source == filter
    }
}
