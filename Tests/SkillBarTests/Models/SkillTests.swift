import Testing
@testable import SkillBar

@Suite("Skill Model Tests")
struct SkillTests {

    @Test("Skill is identifiable with source-prefixed ID")
    func identifiableId() {
        let skill = Skill(
            name: "commit",
            description: "Write commits.",
            source: .local,
            filePath: "/path/to/SKILL.md"
        )
        #expect(skill.id == "local:commit")
    }

    @Test("Skill slash command includes leading slash")
    func slashCommand() {
        let skill = Skill(
            name: "commit",
            description: "Write commits.",
            source: .local,
            filePath: "/path/to/SKILL.md"
        )
        #expect(skill.slashCommand == "/commit")
    }

    @Test("Skills with same name but different source have different IDs")
    func uniqueIdAcrossSources() {
        let local = Skill(name: "skill", description: "", source: .local, filePath: "/a")
        let plugin = Skill(name: "skill", description: "", source: .pluginCache, filePath: "/b")
        #expect(local.id != plugin.id)
    }

    @Test("Skill conforms to Hashable")
    func hashable() {
        let skill1 = Skill(name: "a", description: "d", source: .local, filePath: "/p")
        let skill2 = Skill(name: "a", description: "d", source: .local, filePath: "/p")
        #expect(skill1 == skill2)

        var set = Set<Skill>()
        set.insert(skill1)
        set.insert(skill2)
        #expect(set.count == 1)
    }
}
