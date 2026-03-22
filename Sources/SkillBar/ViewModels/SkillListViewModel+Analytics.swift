import Foundation

extension SkillListViewModel {

    // MARK: - Record Usage

    func recordUsage(_ skill: Skill) {
        var records = loadUsageRecords()
        if let index = records.firstIndex(where: { $0.skillName == skill.name }) {
            var record = records[index]
            record = UsageRecord(
                skillName: record.skillName,
                copyCount: record.copyCount + 1,
                lastCopiedAt: Date()
            )
            records[index] = record
        } else {
            records.append(UsageRecord(
                skillName: skill.name,
                copyCount: 1,
                lastCopiedAt: Date()
            ))
        }
        saveUsageRecords(records)

        // Record workflow transition
        if let previous = lastLaunchedSkillName, previous != skill.name {
            recordTransition(from: previous, to: skill.name)
        }
        lastLaunchedSkillName = skill.name
        store.set([skill.name], forKey: Constants.lastLaunchedSkillKey)
    }

    // MARK: - Recently Used

    var recentlyUsedSkills: [Skill] {
        let records = loadUsageRecords()
            .sorted { $0.lastCopiedAt > $1.lastCopiedAt }
            .prefix(Constants.recentLimit)
        let skillsByName = Dictionary(uniqueKeysWithValues: skills.map { ($0.name, $0) })
        return records.compactMap { skillsByName[$0.skillName] }
    }

    var filteredRecentlyUsedSkills: [Skill] {
        recentlyUsedSkills.filter { skill in
            matchesSourceFilter(skill) && matchesTagFilter(skill)
                && (searchText.isEmpty || SearchRanker.matches(skill, query: searchText))
        }
    }

    // MARK: - Frequently Used

    var frequentlyUsedSkills: [Skill] {
        let records = loadUsageRecords()
            .filter { $0.copyCount >= Constants.frequentThreshold }
            .sorted { $0.copyCount > $1.copyCount }
            .prefix(Constants.frequentLimit)
        let skillsByName = Dictionary(uniqueKeysWithValues: skills.map { ($0.name, $0) })
        return records.compactMap { skillsByName[$0.skillName] }
    }

    var filteredFrequentlyUsedSkills: [Skill] {
        frequentlyUsedSkills.filter { skill in
            matchesSourceFilter(skill) && matchesTagFilter(skill)
                && (searchText.isEmpty || SearchRanker.matches(skill, query: searchText))
        }
    }

    // MARK: - Clear

    var hasUsageData: Bool {
        !loadUsageRecords().isEmpty
            || store.data(forKey: Constants.transitionMatrixKey) != nil
            || lastLaunchedSkillName != nil
    }

    func clearUsageData() {
        store.removeObject(forKey: Constants.usageRecordsKey)
        clearWorkflowMemory()
    }

    // MARK: - Private

    private func loadUsageRecords() -> [UsageRecord] {
        guard let data = store.data(forKey: Constants.usageRecordsKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([UsageRecord].self, from: data)
        } catch {
            return []
        }
    }

    private func saveUsageRecords(_ records: [UsageRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        store.set(data, forKey: Constants.usageRecordsKey)
    }
}
