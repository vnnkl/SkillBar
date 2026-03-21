import Foundation

extension SkillListViewModel {

    var favoritedSkills: [Skill] {
        let names = favoriteNames
        return skills
            .filter { names.contains($0.name) }
            .sorted { $0.name < $1.name }
    }

    var filteredFavoritedSkills: [Skill] {
        let names = favoriteNames
        return skills
            .filter { names.contains($0.name) && matchesSourceFilter($0) }
            .filter { searchText.isEmpty || SearchRanker.matches($0, query: searchText) }
            .sorted { $0.name < $1.name }
    }

    var hasFavorites: Bool {
        !favoritedSkills.isEmpty
    }

    func isFavorite(_ skill: Skill) -> Bool {
        favoriteNames.contains(skill.name)
    }

    func toggleFavorite(_ skill: Skill) {
        var names = favoriteNames
        if names.contains(skill.name) {
            names.remove(skill.name)
        } else {
            names.insert(skill.name)
        }
        favoriteNames = names
        store.set(Array(names), forKey: Constants.favoritesKey)
    }

    func clearFavorites() {
        favoriteNames = []
        store.removeObject(forKey: Constants.favoritesKey)
    }
}
