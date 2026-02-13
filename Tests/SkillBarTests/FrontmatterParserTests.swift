import Testing
@testable import SkillBar

@Suite("FrontmatterParser Tests")
struct FrontmatterParserTests {

    // MARK: - Basic Parsing

    @Test("Parses standard frontmatter with name and description")
    func standardFrontmatter() {
        let content = """
        ---
        name: commit
        description: Write conventional commit messages.
        ---

        # Git Commit
        """
        let result = FrontmatterParser.parse(content)
        #expect(result.name == "commit")
        #expect(result.description == "Write conventional commit messages.")
    }

    @Test("Parses frontmatter with double-quoted description")
    func doubleQuotedDescription() {
        let content = """
        ---
        name: prd
        description: "Generate a PRD as JSON for Ralph."
        ---

        # PRD Generator
        """
        let result = FrontmatterParser.parse(content)
        #expect(result.name == "prd")
        #expect(result.description == "Generate a PRD as JSON for Ralph.")
    }

    @Test("Parses frontmatter with single-quoted values")
    func singleQuotedValues() {
        let content = """
        ---
        name: 'my-skill'
        description: 'A skill with single quotes.'
        ---

        Body text.
        """
        let result = FrontmatterParser.parse(content)
        #expect(result.name == "my-skill")
        #expect(result.description == "A skill with single quotes.")
    }

    // MARK: - Multiline Description

    @Test("Parses multiline folded description with > indicator")
    func multilineFoldedDescription() {
        let content = """
        ---
        name: seo
        description: >
          Comprehensive SEO analysis for any website or business type. Performs full site
          audits, single-page deep analysis, technical SEO checks.
        ---

        # SEO Skill
        """
        let result = FrontmatterParser.parse(content)
        #expect(result.name == "seo")
        #expect(result.description == "Comprehensive SEO analysis for any website or business type. Performs full site audits, single-page deep analysis, technical SEO checks.")
    }

    @Test("Parses multiline folded description stopping at next key")
    func multilineFoldedStopsAtNextKey() {
        let content = """
        ---
        name: seo
        description: >
          Comprehensive SEO analysis for any website.
          Performs audits and checks.
        allowed-tools:
          - Read
          - Grep
        ---

        Body.
        """
        let result = FrontmatterParser.parse(content)
        #expect(result.name == "seo")
        #expect(result.description == "Comprehensive SEO analysis for any website. Performs audits and checks.")
    }

    // MARK: - Edge Cases

    @Test("Returns nil for content without frontmatter delimiters")
    func noFrontmatter() {
        let content = """
        # Just a markdown file
        No frontmatter here.
        """
        let result = FrontmatterParser.parse(content)
        #expect(result.name == nil)
        #expect(result.description == nil)
    }

    @Test("Returns nil for empty string")
    func emptyString() {
        let result = FrontmatterParser.parse("")
        #expect(result.name == nil)
        #expect(result.description == nil)
    }

    @Test("Returns nil for frontmatter with only opening delimiter")
    func onlyOpeningDelimiter() {
        let content = """
        ---
        name: broken
        description: No closing delimiter
        """
        let result = FrontmatterParser.parse(content)
        #expect(result.name == nil)
        #expect(result.description == nil)
    }

    @Test("Handles empty frontmatter block")
    func emptyFrontmatter() {
        let content = """
        ---
        ---

        Body content.
        """
        let result = FrontmatterParser.parse(content)
        #expect(result.name == nil)
        #expect(result.description == nil)
    }

    @Test("Handles frontmatter with trailing whitespace on delimiters")
    func trailingWhitespaceOnDelimiters() {
        let content = "---   \nname: test-skill\ndescription: A test skill.\n---  \n\nBody."
        let result = FrontmatterParser.parse(content)
        #expect(result.name == "test-skill")
        #expect(result.description == "A test skill.")
    }

    @Test("Handles missing name field")
    func missingName() {
        let content = """
        ---
        description: A skill without a name.
        ---

        Body.
        """
        let result = FrontmatterParser.parse(content)
        #expect(result.name == nil)
        #expect(result.description == "A skill without a name.")
    }

    @Test("Handles missing description field")
    func missingDescription() {
        let content = """
        ---
        name: minimal-skill
        ---

        Body.
        """
        let result = FrontmatterParser.parse(content)
        #expect(result.name == "minimal-skill")
        #expect(result.description == nil)
    }

    // MARK: - HTML Comment Preamble

    @Test("Handles HTML comment before frontmatter")
    func htmlCommentPreamble() {
        let content = """
        <!-- This is an auto-generated file -->
        ---
        name: generated-skill
        description: A skill with HTML comment preamble.
        ---

        Body.
        """
        let result = FrontmatterParser.parse(content)
        #expect(result.name == "generated-skill")
        #expect(result.description == "A skill with HTML comment preamble.")
    }

    // MARK: - Extra Fields Ignored

    @Test("Ignores extra YAML fields and lists")
    func extraFieldsIgnored() {
        let content = """
        ---
        name: seo
        description: SEO analysis skill.
        version: 2.0.0
        allowed-tools:
          - Read
          - Grep
          - Glob
        ---

        # SEO
        """
        let result = FrontmatterParser.parse(content)
        #expect(result.name == "seo")
        #expect(result.description == "SEO analysis skill.")
    }

    @Test("Parses frontmatter where --- appears later in the document body")
    func tripleHyphensInBody() {
        let content = """
        ---
        name: my-skill
        description: A skill description.
        ---

        # Heading

        ---

        ## Section after horizontal rule
        """
        let result = FrontmatterParser.parse(content)
        #expect(result.name == "my-skill")
        #expect(result.description == "A skill description.")
    }
}
