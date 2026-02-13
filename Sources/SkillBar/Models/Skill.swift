import Foundation

struct Skill: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let source: SkillSource
    let slashCommand: String
    let filePath: String

    init(name: String, description: String, source: SkillSource, filePath: String) {
        self.id = "\(source.rawValue):\(name)"
        self.name = name
        self.description = description
        self.source = source
        self.slashCommand = "/\(name)"
        self.filePath = filePath
    }

    /// Extract package name from skill name (before `:`) or from plugin cache path
    var package: String? {
        // Name-based: "compound-engineering:plan" → "compound-engineering"
        if let colonIndex = name.firstIndex(of: ":") {
            let pkg = String(name[name.startIndex..<colonIndex])
            return pkg.isEmpty ? nil : pkg
        }

        // Path-based: .../cache/<marketplace>/<package>/<version>/...
        if source == .pluginCache {
            return extractPackageFromPath(filePath)
        }

        return nil
    }

    /// Portion after `:`, or full name if no colon
    var displayName: String {
        if let colonIndex = name.firstIndex(of: ":") {
            let after = String(name[name.index(after: colonIndex)...])
            return after.isEmpty ? name : after
        }
        return name
    }

    private func extractPackageFromPath(_ path: String) -> String? {
        // Pattern: .../plugins/cache/<marketplace>/<package>/<version>/...
        let components = path.components(separatedBy: "/")
        guard let cacheIndex = components.firstIndex(of: "cache"),
              cacheIndex + 2 < components.count else {
            return nil
        }
        let pkg = components[cacheIndex + 2]
        return pkg.isEmpty ? nil : pkg
    }
}
