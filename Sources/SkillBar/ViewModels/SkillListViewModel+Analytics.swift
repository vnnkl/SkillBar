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
        let allowed = Set(filteredSkills.map(\.id))
        return recentlyUsedSkills.filter { allowed.contains($0.id) }
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
        let allowed = Set(filteredSkills.map(\.id))
        return frequentlyUsedSkills.filter { allowed.contains($0.id) }
    }

    // MARK: - Clear

    var hasUsageData: Bool {
        !loadUsageRecords().isEmpty
    }

    func clearUsageData() {
        store.removeObject(forKey: Constants.usageRecordsKey)
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
