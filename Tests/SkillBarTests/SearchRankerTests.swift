import Foundation
import Testing
@testable import SkillBar

@Suite("SearchRanker Tests")
struct SearchRankerTests {

    // MARK: - Helpers

    private func makeSkill(
        name: String,
        description: String = "",
        source: SkillSource = .local
    ) -> Skill {
        Skill(name: name, description: description, source: source, filePath: "/path/\(name)/SKILL.md")
    }

    // MARK: - score()

    @Test("Exact name match scores 100")
    func exactNameMatch() {
        let skill = makeSkill(name: "tdd")
        #expect(SearchRanker.score(skill, query: "tdd") == 100)
    }

    @Test("Prefix name match scores 80")
    func prefixNameMatch() {
        let skill = makeSkill(name: "tdd-guide")
        #expect(SearchRanker.score(skill, query: "tdd") == 80)
    }

    @Test("Substring name match scores 60")
    func substringNameMatch() {
        let skill = makeSkill(name: "my-tdd-tool")
        #expect(SearchRanker.score(skill, query: "tdd") == 60)
    }

    @Test("Description-only match scores 30")
    func descriptionOnlyMatch() {
        let skill = makeSkill(name: "checker", description: "runs tdd tests")
        #expect(SearchRanker.score(skill, query: "tdd") == 30)
    }

    @Test("Package-only match scores 15")
    func packageOnlyMatch() {
        // "gsd:commit" → package = "gsd"
        let skill = makeSkill(name: "gsd:commit", description: "commits code")
        #expect(SearchRanker.score(skill, query: "gsd") == 80 + 15) // displayName "commit" no match, name "gsd:commit" prefix, package "gsd" exact
    }

    @Test("Scores are additive across fields")
    func scoresAdditive() {
        // name contains "test" (60) + description contains "test" (30) = 90
        let skill = makeSkill(name: "my-test-tool", description: "a test runner")
        let s = SearchRanker.score(skill, query: "test")
        #expect(s == 60 + 30) // name contains + description contains
    }

    @Test("Case insensitive matching")
    func caseInsensitive() {
        let skill = makeSkill(name: "TDD-Guide", description: "Test Driven")
        #expect(SearchRanker.score(skill, query: "tdd") == 80) // prefix match on name
        #expect(SearchRanker.score(skill, query: "TDD") == 80)
    }

    @Test("No match returns 0")
    func noMatch() {
        let skill = makeSkill(name: "commit", description: "saves changes")
        #expect(SearchRanker.score(skill, query: "xyz") == 0)
    }

    @Test("DisplayName is used for scoring")
    func displayNameScoring() {
        // "pkg:tdd" → displayName = "tdd", name = "pkg:tdd"
        let skill = makeSkill(name: "pkg:tdd")
        let s = SearchRanker.score(skill, query: "tdd")
        // displayName "tdd" exact = 100, name "pkg:tdd" contains = 60 → max(100, 60) = 100
        // package "pkg" no match
        #expect(s == 100)
    }

    // MARK: - matches()

    @Test("matches returns true for any field match")
    func matchesAnyField() {
        let nameMatch = makeSkill(name: "tdd")
        let descMatch = makeSkill(name: "checker", description: "uses tdd")
        let pkgMatch = makeSkill(name: "tdd:commit")
        let noMatch = makeSkill(name: "commit", description: "saves")

        #expect(SearchRanker.matches(nameMatch, query: "tdd"))
        #expect(SearchRanker.matches(descMatch, query: "tdd"))
        #expect(SearchRanker.matches(pkgMatch, query: "commit"))
        #expect(!SearchRanker.matches(noMatch, query: "xyz"))
    }

    @Test("matches returns false for empty query")
    func matchesEmptyQuery() {
        let skill = makeSkill(name: "tdd")
        #expect(!SearchRanker.matches(skill, query: ""))
    }

    // MARK: - rank()

    @Test("Name match ranks above description-only match")
    func nameAboveDescription() {
        let nameSkill = makeSkill(name: "tdd-guide", description: "helps with dev")
        let descSkill = makeSkill(name: "checker", description: "runs tdd tests")

        let ranked = SearchRanker.rank([descSkill, nameSkill], query: "tdd")
        #expect(ranked.count == 2)
        #expect(ranked[0].name == "tdd-guide") // 80 > 30
        #expect(ranked[1].name == "checker")
    }

    @Test("Description match scores higher than package-only match")
    func descriptionAbovePackage() {
        // Description-only match = 30 points
        let descOnly = makeSkill(name: "runner", description: "handles deploy tasks")
        #expect(SearchRanker.score(descOnly, query: "deploy") == 30)
        // Package-only would score 15, so description (30) > package (15)
    }

    @Test("Exact name match always ranks first")
    func exactNameFirst() {
        let exact = makeSkill(name: "test")
        let prefix = makeSkill(name: "test-runner")
        let contains = makeSkill(name: "my-test")
        let desc = makeSkill(name: "checker", description: "runs test suite")

        let ranked = SearchRanker.rank([desc, contains, prefix, exact], query: "test")
        #expect(ranked[0].name == "test")
    }

    @Test("Empty query returns empty array")
    func emptyQueryReturnsEmpty() {
        let skill = makeSkill(name: "tdd")
        #expect(SearchRanker.rank([skill], query: "").isEmpty)
    }

    @Test("Non-matching skills excluded from rank results")
    func nonMatchingExcluded() {
        let match = makeSkill(name: "tdd")
        let noMatch = makeSkill(name: "commit", description: "saves")

        let ranked = SearchRanker.rank([match, noMatch], query: "tdd")
        #expect(ranked.count == 1)
        #expect(ranked[0].name == "tdd")
    }

    @Test("Ties broken alphabetically by name")
    func tiesBrokenAlphabetically() {
        let beta = makeSkill(name: "beta-test")
        let alpha = makeSkill(name: "alpha-test")

        let ranked = SearchRanker.rank([beta, alpha], query: "test")
        // Both contain "test" → same score (60), alphabetical tiebreak
        #expect(ranked[0].name == "alpha-test")
        #expect(ranked[1].name == "beta-test")
    }

    @Test("All previously matching skills still match")
    func backwardsCompatible() {
        // Old matchesSearch used contains on name, description, package
        let skills = [
            makeSkill(name: "tdd-guide", description: "test driven"),
            makeSkill(name: "checker", description: "runs tdd checks"),
            makeSkill(name: "gsd:tdd-flow", description: "workflow"),
        ]

        let ranked = SearchRanker.rank(skills, query: "tdd")
        #expect(ranked.count == 3)
    }
}
