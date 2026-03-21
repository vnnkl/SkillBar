import Foundation

enum SearchRanker {

    /// Return only matching skills, sorted by score descending, then alphabetically by name for ties.
    static func rank(_ skills: [Skill], query: String) -> [Skill] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        return skills
            .map { (skill: $0, score: score($0, lowercasedQuery: q)) }
            .filter { $0.score > 0 }
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.skill.name < $1.skill.name
            }
            .map(\.skill)
    }

    /// Does this skill match the query at all?
    static func matches(_ skill: Skill, query: String) -> Bool {
        guard !query.isEmpty else { return false }
        return score(skill, lowercasedQuery: query.lowercased()) > 0
    }

    /// Score a single skill. Additive across fields.
    static func score(_ skill: Skill, query: String) -> Int {
        score(skill, lowercasedQuery: query.lowercased())
    }

    // MARK: - Private

    private static func score(_ skill: Skill, lowercasedQuery q: String) -> Int {
        var total = 0
        let name = skill.name.lowercased()
        let displayName = skill.displayName.lowercased()

        // Name / displayName scoring (take best of name or displayName)
        let nameScore = fieldScore(field: name, query: q)
        let displayNameScore = fieldScore(field: displayName, query: q)
        total += max(nameScore, displayNameScore)

        // Description
        if skill.description.lowercased().contains(q) {
            total += 30
        }

        // Package
        if let pkg = skill.package, pkg.lowercased().contains(q) {
            total += 15
        }

        return total
    }

    private static func fieldScore(field: String, query: String) -> Int {
        if field == query { return 100 }
        if field.hasPrefix(query) { return 80 }
        if field.contains(query) { return 60 }
        return 0
    }
}
