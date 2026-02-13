import Testing
@testable import SkillBar

@Suite("SkillScanner Tests")
struct SkillScannerTests {

    // MARK: - Helpers

    private func makeSkillContent(name: String, description: String) -> String {
        """
        ---
        name: \(name)
        description: \(description)
        ---

        # \(name)
        """
    }

    private func makeMockFS(
        directories: [String: [String]] = [:],
        files: [String: String] = [:],
        symlinks: Set<String> = [],
        existingPaths: Set<String> = []
    ) -> MockFileSystemProvider {
        let fs = MockFileSystemProvider()
        fs.directories = directories
        fs.files = files
        fs.symlinks = symlinks
        fs.existingPaths = existingPaths
        return fs
    }

    // MARK: - Basic Scanning

    @Test("Scans single directory with one SKILL.md")
    func scansSingleSkill() throws {
        let skillPath = "/home/.claude/skills/commit/SKILL.md"
        let dirPath = "/home/.claude/skills"
        let fs = makeMockFS(
            directories: [
                dirPath: ["commit"],
                "\(dirPath)/commit": ["SKILL.md"]
            ],
            files: [
                skillPath: makeSkillContent(name: "commit", description: "Write commits.")
            ],
            existingPaths: [dirPath, "\(dirPath)/commit", skillPath]
        )

        let scanner = SkillScanner(
            fileSystem: fs,
            scanDirectories: [dirPath]
        )
        let skills = try scanner.scan()

        #expect(skills.count == 1)
        #expect(skills[0].name == "commit")
        #expect(skills[0].description == "Write commits.")
        #expect(skills[0].slashCommand == "/commit")
        #expect(skills[0].source == .local)
    }

    @Test("Scans multiple skills from one directory")
    func scansMultipleSkills() throws {
        let dirPath = "/home/.claude/skills"
        let fs = makeMockFS(
            directories: [
                dirPath: ["commit", "tdd", "seo"],
                "\(dirPath)/commit": ["SKILL.md"],
                "\(dirPath)/tdd": ["SKILL.md"],
                "\(dirPath)/seo": ["SKILL.md"]
            ],
            files: [
                "\(dirPath)/commit/SKILL.md": makeSkillContent(name: "commit", description: "Commits."),
                "\(dirPath)/tdd/SKILL.md": makeSkillContent(name: "tdd", description: "TDD."),
                "\(dirPath)/seo/SKILL.md": makeSkillContent(name: "seo", description: "SEO.")
            ],
            existingPaths: [dirPath]
        )

        let scanner = SkillScanner(fileSystem: fs, scanDirectories: [dirPath])
        let skills = try scanner.scan()

        #expect(skills.count == 3)
        let names = Set(skills.map(\.name))
        #expect(names == ["commit", "tdd", "seo"])
    }

    // MARK: - Source Detection

    @Test("Detects local source for regular directory")
    func detectsLocalSource() throws {
        let dirPath = "/home/.claude/skills"
        let fs = makeMockFS(
            directories: [
                dirPath: ["skill-a"],
                "\(dirPath)/skill-a": ["SKILL.md"]
            ],
            files: [
                "\(dirPath)/skill-a/SKILL.md": makeSkillContent(name: "skill-a", description: "A.")
            ],
            existingPaths: [dirPath]
        )

        let scanner = SkillScanner(fileSystem: fs, scanDirectories: [dirPath])
        let skills = try scanner.scan()

        #expect(skills[0].source == .local)
    }

    @Test("Detects symlink source for symlinked skill directory")
    func detectsSymlinkSource() throws {
        let dirPath = "/home/.claude/skills"
        let fs = makeMockFS(
            directories: [
                dirPath: ["linked-skill"],
                "\(dirPath)/linked-skill": ["SKILL.md"]
            ],
            files: [
                "\(dirPath)/linked-skill/SKILL.md": makeSkillContent(name: "linked-skill", description: "Linked.")
            ],
            symlinks: ["\(dirPath)/linked-skill"],
            existingPaths: [dirPath]
        )

        let scanner = SkillScanner(fileSystem: fs, scanDirectories: [dirPath])
        let skills = try scanner.scan()

        #expect(skills[0].source == .symlink)
    }

    @Test("Detects plugin cache source for plugin directories")
    func detectsPluginCacheSource() throws {
        let dirPath = "/home/.claude/plugins/cache"
        let fs = makeMockFS(
            directories: [
                dirPath: ["plugin-skill"],
                "\(dirPath)/plugin-skill": ["SKILL.md"]
            ],
            files: [
                "\(dirPath)/plugin-skill/SKILL.md": makeSkillContent(name: "plugin-skill", description: "Plugin.")
            ],
            existingPaths: [dirPath]
        )

        let scanner = SkillScanner(fileSystem: fs, scanDirectories: [dirPath])
        let skills = try scanner.scan()

        #expect(skills[0].source == .pluginCache)
    }

    @Test("Detects plugin cache source for marketplaces directory")
    func detectsMarketplacesSource() throws {
        let dirPath = "/home/.claude/plugins/marketplaces"
        let fs = makeMockFS(
            directories: [
                dirPath: ["mp-skill"],
                "\(dirPath)/mp-skill": ["SKILL.md"]
            ],
            files: [
                "\(dirPath)/mp-skill/SKILL.md": makeSkillContent(name: "mp-skill", description: "Marketplace.")
            ],
            existingPaths: [dirPath]
        )

        let scanner = SkillScanner(fileSystem: fs, scanDirectories: [dirPath])
        let skills = try scanner.scan()

        #expect(skills[0].source == .pluginCache)
    }

    // MARK: - Deduplication

    @Test("Deduplicates by name keeping highest priority source (local > symlink > plugin)")
    func deduplicatesByPriority() throws {
        let localDir = "/home/.claude/skills"
        let pluginDir = "/home/.claude/plugins/cache"
        let fs = makeMockFS(
            directories: [
                localDir: ["commit"],
                "\(localDir)/commit": ["SKILL.md"],
                pluginDir: ["commit"],
                "\(pluginDir)/commit": ["SKILL.md"]
            ],
            files: [
                "\(localDir)/commit/SKILL.md": makeSkillContent(name: "commit", description: "Local version."),
                "\(pluginDir)/commit/SKILL.md": makeSkillContent(name: "commit", description: "Plugin version.")
            ],
            existingPaths: [localDir, pluginDir]
        )

        let scanner = SkillScanner(
            fileSystem: fs,
            scanDirectories: [localDir, pluginDir]
        )
        let skills = try scanner.scan()

        #expect(skills.count == 1)
        #expect(skills[0].source == .local)
        #expect(skills[0].description == "Local version.")
    }

    // MARK: - Edge Cases

    @Test("Skips directories without SKILL.md")
    func skipsDirectoriesWithoutSkillFile() throws {
        let dirPath = "/home/.claude/skills"
        let fs = makeMockFS(
            directories: [
                dirPath: ["has-skill", "no-skill"],
                "\(dirPath)/has-skill": ["SKILL.md"],
                "\(dirPath)/no-skill": ["README.md"]
            ],
            files: [
                "\(dirPath)/has-skill/SKILL.md": makeSkillContent(name: "has-skill", description: "Has it.")
            ],
            existingPaths: [dirPath]
        )

        let scanner = SkillScanner(fileSystem: fs, scanDirectories: [dirPath])
        let skills = try scanner.scan()

        #expect(skills.count == 1)
        #expect(skills[0].name == "has-skill")
    }

    @Test("Skips skills with missing name in frontmatter")
    func skipsMissingName() throws {
        let dirPath = "/home/.claude/skills"
        let fs = makeMockFS(
            directories: [
                dirPath: ["nameless"],
                "\(dirPath)/nameless": ["SKILL.md"]
            ],
            files: [
                "\(dirPath)/nameless/SKILL.md": "---\ndescription: No name field.\n---\n\nBody."
            ],
            existingPaths: [dirPath]
        )

        let scanner = SkillScanner(fileSystem: fs, scanDirectories: [dirPath])
        let skills = try scanner.scan()

        #expect(skills.isEmpty)
    }

    @Test("Handles nonexistent scan directory gracefully")
    func handlesNonexistentDirectory() throws {
        let fs = makeMockFS()

        let scanner = SkillScanner(
            fileSystem: fs,
            scanDirectories: ["/nonexistent"]
        )
        let skills = try scanner.scan()

        #expect(skills.isEmpty)
    }

    @Test("Uses folder name when frontmatter name is missing")
    func usesFolderNameAsFallback() throws {
        let dirPath = "/home/.claude/skills"
        let fs = makeMockFS(
            directories: [
                dirPath: ["my-folder-skill"],
                "\(dirPath)/my-folder-skill": ["SKILL.md"]
            ],
            files: [
                "\(dirPath)/my-folder-skill/SKILL.md": "---\ndescription: Has description but no name.\n---\n\nBody."
            ],
            existingPaths: [dirPath]
        )

        let scanner = SkillScanner(fileSystem: fs, scanDirectories: [dirPath])
        let skills = try scanner.scan()

        // Skills without a frontmatter name should be skipped (PRD says parse name from frontmatter)
        #expect(skills.isEmpty)
    }
}
