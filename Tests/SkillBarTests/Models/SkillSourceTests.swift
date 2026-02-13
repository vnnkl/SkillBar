import Testing
@testable import SkillBar

@Suite("SkillSource Tests")
struct SkillSourceTests {

    @Test("Display names are human-readable")
    func displayNames() {
        #expect(SkillSource.local.displayName == "Local")
        #expect(SkillSource.symlink.displayName == "Symlink")
        #expect(SkillSource.pluginCache.displayName == "Plugin")
    }

    @Test("Priority ordering: local < symlink < pluginCache")
    func priorityOrdering() {
        #expect(SkillSource.local.priority < SkillSource.symlink.priority)
        #expect(SkillSource.symlink.priority < SkillSource.pluginCache.priority)
    }

    @Test("All cases are enumerable")
    func allCases() {
        #expect(SkillSource.allCases.count == 3)
    }
}
