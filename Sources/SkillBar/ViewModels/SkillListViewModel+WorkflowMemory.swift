import Foundation

extension SkillListViewModel {

    // MARK: - Record Transition

    func recordTransition(from source: String, to target: String) {
        guard source != target else { return }
        var matrix = loadTransitionMatrix()
        var targets = matrix[source] ?? [:]
        targets[target] = (targets[target] ?? 0) + 1
        matrix[source] = targets
        saveTransitionMatrix(matrix)
    }

    // MARK: - Suggestions

    var suggestedNextSkills: [Skill] {
        guard let last = lastLaunchedSkillName else { return [] }
        let matrix = loadTransitionMatrix()
        guard let transitions = matrix[last] else { return [] }
        let skillsByName = Dictionary(uniqueKeysWithValues: skills.map { ($0.name, $0) })
        return transitions
            .filter { $0.value >= Constants.transitionThreshold }
            .sorted { $0.value > $1.value }
            .prefix(Constants.nextUpLimit + 2)
            .compactMap { skillsByName[$0.key] }
            .filter { matchesSourceFilter($0) && matchesTagFilter($0) }
            .filter { searchText.isEmpty || SearchRanker.matches($0, query: searchText) }
            .prefix(Constants.nextUpLimit)
            .map { $0 }
    }

    // MARK: - Clear

    func clearWorkflowMemory() {
        store.removeObject(forKey: Constants.transitionMatrixKey)
        store.removeObject(forKey: Constants.lastLaunchedSkillKey)
        lastLaunchedSkillName = nil
    }

    // MARK: - Private

    private func loadTransitionMatrix() -> [String: [String: Int]] {
        guard let data = store.data(forKey: Constants.transitionMatrixKey) else { return [:] }
        return (try? JSONDecoder().decode([String: [String: Int]].self, from: data)) ?? [:]
    }

    private func saveTransitionMatrix(_ matrix: [String: [String: Int]]) {
        guard let data = try? JSONEncoder().encode(matrix) else { return }
        store.set(data, forKey: Constants.transitionMatrixKey)
    }
}
