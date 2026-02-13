import Foundation

struct SkillScanner: SkillScanning, Sendable {
    private let fileSystem: FileSystemProvider
    private let scanDirectories: [String]

    init(fileSystem: FileSystemProvider, scanDirectories: [String]) {
        self.fileSystem = fileSystem
        self.scanDirectories = scanDirectories
    }

    func scan() throws -> [Skill] {
        var skillsByName: [String: Skill] = [:]

        for directory in scanDirectories {
            let source = sourceForDirectory(directory)
            let skills = scanDirectory(directory, source: source)

            for skill in skills {
                if let existing = skillsByName[skill.name] {
                    if skill.source.priority < existing.source.priority {
                        skillsByName[skill.name] = skill
                    }
                } else {
                    skillsByName[skill.name] = skill
                }
            }
        }

        return Array(skillsByName.values)
    }

    // MARK: - Private

    private func scanDirectory(_ path: String, source: SkillSource) -> [Skill] {
        guard let entries = try? fileSystem.contentsOfDirectory(atPath: path) else {
            return []
        }

        return entries.compactMap { entry in
            let entryPath = "\(path)/\(entry)"
            let skillFilePath = "\(entryPath)/\(Constants.skillFileName)"

            guard let contents = try? fileSystem.contentsOfFile(atPath: skillFilePath) else {
                return nil
            }

            let result = FrontmatterParser.parse(contents)
            guard let name = result.name else { return nil }

            let actualSource = detectSource(entryPath: entryPath, fallback: source)

            return Skill(
                name: name,
                description: result.description ?? "",
                source: actualSource,
                filePath: skillFilePath
            )
        }
    }

    private func detectSource(entryPath: String, fallback: SkillSource) -> SkillSource {
        if fileSystem.isSymlink(atPath: entryPath) {
            return .symlink
        }
        return fallback
    }

    private func sourceForDirectory(_ path: String) -> SkillSource {
        if path.contains("plugins/cache") || path.contains("plugins/marketplaces") {
            return .pluginCache
        }
        return .local
    }
}
