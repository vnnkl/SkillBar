import Foundation

extension SkillListViewModel {

    var currentDetailFilePath: String? {
        detailFileStack.last
    }

    var canNavigateBack: Bool {
        detailFileStack.count > 1
    }

    var detailBreadcrumbs: [String] {
        detailFileStack.map { URL(fileURLWithPath: $0).lastPathComponent }
    }

    func navigateToFile(_ absolutePath: String) {
        guard fileSystem.fileExists(atPath: absolutePath) else { return }
        detailFileStack.append(absolutePath)
    }

    func navigateBack() {
        guard detailFileStack.count > 1 else { return }
        detailFileStack.removeLast()
    }

    func navigateToBreadcrumb(at index: Int) {
        guard index >= 0, index < detailFileStack.count else { return }
        detailFileStack = Array(detailFileStack.prefix(index + 1))
    }

    func readCurrentDetailContent() -> String {
        guard let path = currentDetailFilePath else { return "" }
        do {
            return try fileSystem.contentsOfFile(atPath: path)
        } catch {
            return "Could not read file: \(error.localizedDescription)"
        }
    }
}
