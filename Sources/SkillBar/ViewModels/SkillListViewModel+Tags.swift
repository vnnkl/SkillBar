import Foundation

extension SkillListViewModel {

    func tags(for skill: Skill) -> [String] {
        skillTags[skill.name] ?? []
    }

    func addTag(_ tag: String, to skill: Skill) {
        let trimmed = tag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let truncated = String(trimmed.prefix(Constants.maxTagLength))

        let existing = tags(for: skill)
        guard existing.count < Constants.maxTagsPerSkill else { return }

        let isDuplicate = existing.contains { $0.caseInsensitiveCompare(truncated) == .orderedSame }
        guard !isDuplicate else { return }

        var tags = skillTags
        var skillTagList = tags[skill.name] ?? []
        skillTagList.append(truncated)
        tags[skill.name] = skillTagList
        skillTags = tags
        persistTags()
    }

    func removeTag(_ tag: String, from skill: Skill) {
        var tags = skillTags
        guard var skillTagList = tags[skill.name] else { return }
        skillTagList.removeAll { $0 == tag }
        if skillTagList.isEmpty {
            tags.removeValue(forKey: skill.name)
        } else {
            tags[skill.name] = skillTagList
        }
        skillTags = tags
        persistTags()
    }

    var allTags: [String] {
        let all = skillTags.values.flatMap { $0 }
        let unique = Set(all)
        return unique.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func toggleTagFilter(_ tag: String) {
        var filters = activeTagFilters
        if filters.contains(tag) {
            filters.remove(tag)
        } else {
            filters.insert(tag)
        }
        activeTagFilters = filters
    }

    func clearTagFilters() {
        activeTagFilters = []
    }

    func deleteTagGlobally(_ tag: String) {
        var tags = skillTags
        for (skillName, tagList) in tags {
            let filtered = tagList.filter { $0 != tag }
            if filtered.isEmpty {
                tags.removeValue(forKey: skillName)
            } else {
                tags[skillName] = filtered
            }
        }
        skillTags = tags
        persistTags()
    }

    func clearAllTags() {
        skillTags = [:]
        store.removeObject(forKey: Constants.skillTagsKey)
    }

    // MARK: - Private

    private func persistTags() {
        guard let data = try? JSONEncoder().encode(skillTags) else { return }
        store.set(data, forKey: Constants.skillTagsKey)
    }
}
