import Foundation

extension SkillListViewModel {

    var navigationList: [Skill] {
        filteredSkills
    }

    func moveDown() {
        let list = navigationList
        guard !list.isEmpty else { return }
        guard let current = selectedIndex else {
            selectedIndex = 0
            return
        }
        selectedIndex = (current + 1) % list.count
    }

    func moveUp() {
        let list = navigationList
        guard !list.isEmpty else { return }
        guard let current = selectedIndex else {
            selectedIndex = list.count - 1
            return
        }
        selectedIndex = (current - 1 + list.count) % list.count
    }

    func confirmSelection() {
        let list = navigationList
        guard let index = selectedIndex, index < list.count else { return }
        launchSkill(list[index])
    }

    func clearSelection() {
        selectedIndex = nil
    }
}
