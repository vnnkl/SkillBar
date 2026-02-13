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
            let skills = source == .pluginCache
                ? scanPluginDirectory(directory, source: source)
                : scanDirectory(directory, source: source)

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

    // MARK: - Local Scanning (flat, 1-level)

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

    // MARK: - Plugin Scanning (recursive)

    private func scanPluginDirectory(_ path: String, source: SkillSource) -> [Skill] {
        let skillFiles = findAllSkillFiles(in: path, currentDepth: 0, maxDepth: 6)

        return skillFiles.compactMap { skillFilePath in
            guard let contents = try? fileSystem.contentsOfFile(atPath: skillFilePath) else {
                return nil
            }

            let result = FrontmatterParser.parse(contents)
            guard let baseName = result.name else { return nil }

            let packageName = extractPackageFromSkillPath(skillFilePath)
            let prefixedName = packageName.map { "\($0):\(baseName)" } ?? baseName

            let entryPath = (skillFilePath as NSString).deletingLastPathComponent
            let actualSource = detectSource(entryPath: entryPath, fallback: source)

            return Skill(
                name: prefixedName,
                description: result.description ?? "",
                source: actualSource,
                filePath: skillFilePath
            )
        }
    }

    private func findAllSkillFiles(
        in directory: String,
        currentDepth: Int,
        maxDepth: Int
    ) -> [String] {
        guard currentDepth < maxDepth else { return [] }
        guard let entries = try? fileSystem.contentsOfDirectory(atPath: directory) else {
            return []
        }

        var results: [String] = []

        for entry in entries {
            if entry.hasPrefix("temp_git_") || entry.hasPrefix(".") {
                continue
            }

            let entryPath = "\(directory)/\(entry)"
            let skillFilePath = "\(entryPath)/\(Constants.skillFileName)"

            if fileSystem.fileExists(atPath: skillFilePath) {
                results.append(skillFilePath)
            } else {
                results += findAllSkillFiles(
                    in: entryPath,
                    currentDepth: currentDepth + 1,
                    maxDepth: maxDepth
                )
            }
        }

        return results
    }

    // MARK: - Package Extraction

    func extractPackageFromSkillPath(_ path: String) -> String? {
        let components = path.components(separatedBy: "/")

        guard let skillsIndex = components.lastIndex(of: "skills"),
              skillsIndex > 0 else {
            return nil
        }

        let candidate = components[skillsIndex - 1]

        if isVersionLike(candidate), skillsIndex >= 2 {
            let pkg = components[skillsIndex - 2]
            return pkg.isEmpty ? nil : pkg
        }

        return candidate.isEmpty ? nil : candidate
    }

    func isVersionLike(_ string: String) -> Bool {
        // Semver: 1.0.0, 2.3.1-beta, etc.
        if string.range(of: #"^\d+\.\d+\.\d+"#, options: .regularExpression) != nil {
            return true
        }
        // Hex hash: 8+ lowercase hex characters
        if string.count >= 8,
           string.range(of: #"^[0-9a-f]+$"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    // MARK: - Source Detection

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
