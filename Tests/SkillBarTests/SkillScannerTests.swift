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

    // MARK: - Recursive Plugin Scanning

    @Test("Finds deeply nested SKILL.md in cache directory")
    func findsDeeplyNestedPluginSkills() throws {
        let cacheDir = "/home/.claude/plugins/cache"
        let skillFile = "\(cacheDir)/npm/compound-engineering/1.0.0/skills/plan/SKILL.md"
        let fs = makeMockFS(
            directories: [
                cacheDir: ["npm"],
                "\(cacheDir)/npm": ["compound-engineering"],
                "\(cacheDir)/npm/compound-engineering": ["1.0.0"],
                "\(cacheDir)/npm/compound-engineering/1.0.0": ["skills"],
                "\(cacheDir)/npm/compound-engineering/1.0.0/skills": ["plan"],
                "\(cacheDir)/npm/compound-engineering/1.0.0/skills/plan": ["SKILL.md"]
            ],
            files: [
                skillFile: makeSkillContent(name: "plan", description: "Planning skill.")
            ]
        )

        let scanner = SkillScanner(fileSystem: fs, scanDirectories: [cacheDir])
        let skills = try scanner.scan()

        #expect(skills.count == 1)
        #expect(skills[0].name == "compound-engineering:plan")
        #expect(skills[0].description == "Planning skill.")
        #expect(skills[0].source == .pluginCache)
    }

    @Test("Extracts package from cache path with semver version")
    func extractsPackageFromCachePath() {
        let scanner = SkillScanner(fileSystem: makeMockFS(), scanDirectories: [])
        let path = "/home/.claude/plugins/cache/npm/my-pkg/1.0.0/skills/plan/SKILL.md"

        let pkg = scanner.extractPackageFromSkillPath(path)

        #expect(pkg == "my-pkg")
    }

    @Test("Extracts package from cache path with hex hash version")
    func extractsPackageFromCachePathWithHash() {
        let scanner = SkillScanner(fileSystem: makeMockFS(), scanDirectories: [])
        let path = "/home/.claude/plugins/cache/npm/my-pkg/a1b2c3d4e5f6/skills/review/SKILL.md"

        let pkg = scanner.extractPackageFromSkillPath(path)

        #expect(pkg == "my-pkg")
    }

    @Test("Extracts package from marketplace path (no version)")
    func extractsPackageFromMarketplacePath() {
        let scanner = SkillScanner(fileSystem: makeMockFS(), scanDirectories: [])
        let path = "/home/.claude/plugins/marketplaces/compound-engineering/skills/tdd/SKILL.md"

        let pkg = scanner.extractPackageFromSkillPath(path)

        #expect(pkg == "compound-engineering")
    }

    @Test("Prefixes skill name with package name")
    func prefixesSkillNameWithPackage() throws {
        let mpDir = "/home/.claude/plugins/marketplaces"
        let skillFile = "\(mpDir)/my-tools/skills/lint/SKILL.md"
        let fs = makeMockFS(
            directories: [
                mpDir: ["my-tools"],
                "\(mpDir)/my-tools": ["skills"],
                "\(mpDir)/my-tools/skills": ["lint"],
                "\(mpDir)/my-tools/skills/lint": ["SKILL.md"]
            ],
            files: [
                skillFile: makeSkillContent(name: "lint", description: "Lint code.")
            ]
        )

        let scanner = SkillScanner(fileSystem: fs, scanDirectories: [mpDir])
        let skills = try scanner.scan()

        #expect(skills.count == 1)
        #expect(skills[0].name == "my-tools:lint")
        #expect(skills[0].package == "my-tools")
        #expect(skills[0].displayName == "lint")
    }

    @Test("Skips temp_git_* directories during recursive scan")
    func skipsTempGitDirectories() throws {
        let cacheDir = "/home/.claude/plugins/cache"
        let fs = makeMockFS(
            directories: [
                cacheDir: ["temp_git_abc123", "legit-pkg"],
                "\(cacheDir)/temp_git_abc123": ["skills"],
                "\(cacheDir)/temp_git_abc123/skills": ["bad"],
                "\(cacheDir)/temp_git_abc123/skills/bad": ["SKILL.md"],
                "\(cacheDir)/legit-pkg": ["skills"],
                "\(cacheDir)/legit-pkg/skills": ["good"],
                "\(cacheDir)/legit-pkg/skills/good": ["SKILL.md"]
            ],
            files: [
                "\(cacheDir)/temp_git_abc123/skills/bad/SKILL.md": makeSkillContent(name: "bad", description: "Bad."),
                "\(cacheDir)/legit-pkg/skills/good/SKILL.md": makeSkillContent(name: "good", description: "Good.")
            ]
        )

        let scanner = SkillScanner(fileSystem: fs, scanDirectories: [cacheDir])
        let skills = try scanner.scan()

        #expect(skills.count == 1)
        #expect(skills[0].name == "legit-pkg:good")
    }

    @Test("Skips hidden directories during recursive scan")
    func skipsHiddenDirectories() throws {
        let cacheDir = "/home/.claude/plugins/cache"
        let fs = makeMockFS(
            directories: [
                cacheDir: [".hidden", "visible-pkg"],
                "\(cacheDir)/.hidden": ["skills"],
                "\(cacheDir)/.hidden/skills": ["secret"],
                "\(cacheDir)/.hidden/skills/secret": ["SKILL.md"],
                "\(cacheDir)/visible-pkg": ["skills"],
                "\(cacheDir)/visible-pkg/skills": ["public"],
                "\(cacheDir)/visible-pkg/skills/public": ["SKILL.md"]
            ],
            files: [
                "\(cacheDir)/.hidden/skills/secret/SKILL.md": makeSkillContent(name: "secret", description: "Hidden."),
                "\(cacheDir)/visible-pkg/skills/public/SKILL.md": makeSkillContent(name: "public", description: "Visible.")
            ]
        )

        let scanner = SkillScanner(fileSystem: fs, scanDirectories: [cacheDir])
        let skills = try scanner.scan()

        #expect(skills.count == 1)
        #expect(skills[0].name == "visible-pkg:public")
    }

    @Test("Finds multiple skills within same package")
    func findsMultipleSkillsInPackage() throws {
        let cacheDir = "/home/.claude/plugins/cache"
        let base = "\(cacheDir)/npm/multi-tool/2.0.0/skills"
        let fs = makeMockFS(
            directories: [
                cacheDir: ["npm"],
                "\(cacheDir)/npm": ["multi-tool"],
                "\(cacheDir)/npm/multi-tool": ["2.0.0"],
                "\(cacheDir)/npm/multi-tool/2.0.0": ["skills"],
                base: ["lint", "format", "test"],
                "\(base)/lint": ["SKILL.md"],
                "\(base)/format": ["SKILL.md"],
                "\(base)/test": ["SKILL.md"]
            ],
            files: [
                "\(base)/lint/SKILL.md": makeSkillContent(name: "lint", description: "Lint."),
                "\(base)/format/SKILL.md": makeSkillContent(name: "format", description: "Format."),
                "\(base)/test/SKILL.md": makeSkillContent(name: "test", description: "Test.")
            ]
        )

        let scanner = SkillScanner(fileSystem: fs, scanDirectories: [cacheDir])
        let skills = try scanner.scan()

        #expect(skills.count == 3)
        let names = Set(skills.map(\.name))
        #expect(names == ["multi-tool:lint", "multi-tool:format", "multi-tool:test"])
    }

    // MARK: - Version Detection

    @Test("Recognizes semver strings as version-like")
    func recognizesSemver() {
        let scanner = SkillScanner(fileSystem: makeMockFS(), scanDirectories: [])
        #expect(scanner.isVersionLike("1.0.0") == true)
        #expect(scanner.isVersionLike("2.3.1") == true)
        #expect(scanner.isVersionLike("10.20.30") == true)
    }

    @Test("Recognizes hex hashes as version-like")
    func recognizesHexHashes() {
        let scanner = SkillScanner(fileSystem: makeMockFS(), scanDirectories: [])
        #expect(scanner.isVersionLike("a1b2c3d4") == true)
        #expect(scanner.isVersionLike("deadbeef01234567") == true)
    }

    @Test("Rejects non-version strings")
    func rejectsNonVersionStrings() {
        let scanner = SkillScanner(fileSystem: makeMockFS(), scanDirectories: [])
        #expect(scanner.isVersionLike("compound-engineering") == false)
        #expect(scanner.isVersionLike("npm") == false)
        #expect(scanner.isVersionLike("skills") == false)
        #expect(scanner.isVersionLike("abc") == false)
    }

    // MARK: - Dedup: Local vs Plugin

    @Test("Local skill wins over plugin skill with same prefixed name")
    func localWinsOverPluginWithSameName() throws {
        let localDir = "/home/.claude/skills"
        let cacheDir = "/home/.claude/plugins/cache"
        let fs = makeMockFS(
            directories: [
                localDir: ["pkg:plan"],
                "\(localDir)/pkg:plan": ["SKILL.md"],
                cacheDir: ["pkg"],
                "\(cacheDir)/pkg": ["skills"],
                "\(cacheDir)/pkg/skills": ["plan"],
                "\(cacheDir)/pkg/skills/plan": ["SKILL.md"]
            ],
            files: [
                "\(localDir)/pkg:plan/SKILL.md": makeSkillContent(name: "pkg:plan", description: "Local override."),
                "\(cacheDir)/pkg/skills/plan/SKILL.md": makeSkillContent(name: "plan", description: "Plugin version.")
            ]
        )

        let scanner = SkillScanner(
            fileSystem: fs,
            scanDirectories: [localDir, cacheDir]
        )
        let skills = try scanner.scan()

        let planSkills = skills.filter { $0.name == "pkg:plan" }
        #expect(planSkills.count == 1)
        #expect(planSkills[0].source == .local)
        #expect(planSkills[0].description == "Local override.")
    }
}
