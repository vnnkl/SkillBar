import Foundation

extension SkillListViewModel {

    func isPackageCollapsed(_ pkg: String) -> Bool {
        collapsedPackageNames.contains(pkg)
    }

    func togglePackageCollapse(_ pkg: String) {
        var names = collapsedPackageNames
        if names.contains(pkg) {
            names.remove(pkg)
        } else {
            names.insert(pkg)
        }
        collapsedPackageNames = names
        persistCollapseState()
    }

    func setAllPackagesCollapsed(_ collapsed: Bool, packages: [String]) {
        var names = collapsedPackageNames
        if collapsed {
            names.formUnion(packages)
        } else {
            names.subtract(packages)
        }
        collapsedPackageNames = names
        persistCollapseState()
    }

    func expandAllPackages() {
        collapsedPackageNames = []
        store.removeObject(forKey: Constants.collapsedPackagesKey)
    }

    // MARK: - Private

    private func persistCollapseState() {
        if collapsedPackageNames.isEmpty {
            store.removeObject(forKey: Constants.collapsedPackagesKey)
        } else {
            store.set(Array(collapsedPackageNames), forKey: Constants.collapsedPackagesKey)
        }
    }
}
