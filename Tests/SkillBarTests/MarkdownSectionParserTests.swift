import Testing
@testable import SkillBar

@Suite("MarkdownSectionParser Tests")
struct MarkdownSectionParserTests {

    // MARK: - Preamble

    @Test("Content with no headings is a single preamble section")
    func preambleOnly() {
        let md = "Some intro text\n\nMore text here."
        let sections = MarkdownSectionParser.parse(md)

        #expect(sections.count == 1)
        #expect(sections[0].level == 0)
        #expect(sections[0].heading == "")
        #expect(sections[0].content.contains("Some intro text"))
        #expect(sections[0].children.isEmpty)
    }

    @Test("Empty content produces a single empty preamble")
    func emptyContent() {
        let sections = MarkdownSectionParser.parse("")

        #expect(sections.count == 1)
        #expect(sections[0].level == 0)
    }

    // MARK: - h1 as Preamble

    @Test("h1 headings are treated as preamble content, not split points")
    func h1AsPreamble() {
        let md = """
        # Title
        Some intro

        More content
        """
        let sections = MarkdownSectionParser.parse(md)

        #expect(sections.count == 1)
        #expect(sections[0].level == 0)
        #expect(sections[0].content.contains("# Title"))
    }

    // MARK: - Single h2

    @Test("Single h2 produces preamble + one section")
    func singleH2() {
        let md = """
        Preamble text

        ## Section One
        Content under section one.
        """
        let sections = MarkdownSectionParser.parse(md)

        #expect(sections.count == 2)
        #expect(sections[0].level == 0)
        #expect(sections[0].content.contains("Preamble"))
        #expect(sections[1].level == 2)
        #expect(sections[1].heading == "Section One")
        #expect(sections[1].content.contains("Content under section one"))
    }

    // MARK: - Multiple h2

    @Test("Multiple h2 sections are parsed correctly")
    func multipleH2() {
        let md = """
        ## First
        Content 1

        ## Second
        Content 2

        ## Third
        Content 3
        """
        let sections = MarkdownSectionParser.parse(md)

        // Empty preamble + 3 h2 sections
        let h2s = sections.filter { $0.level == 2 }
        #expect(h2s.count == 3)
        #expect(h2s[0].heading == "First")
        #expect(h2s[1].heading == "Second")
        #expect(h2s[2].heading == "Third")
    }

    // MARK: - Nested h3

    @Test("h3 sections nest under preceding h2")
    func h3NestedUnderH2() {
        let md = """
        ## Parent Section
        Parent content

        ### Child One
        Child 1 content

        ### Child Two
        Child 2 content
        """
        let sections = MarkdownSectionParser.parse(md)

        let h2s = sections.filter { $0.level == 2 }
        #expect(h2s.count == 1)

        let parent = h2s[0]
        #expect(parent.heading == "Parent Section")
        #expect(parent.children.count == 2)
        #expect(parent.children[0].heading == "Child One")
        #expect(parent.children[0].level == 3)
        #expect(parent.children[1].heading == "Child Two")
    }

    @Test("h3 before any h2 is treated as top-level section")
    func orphanH3() {
        let md = """
        ### Orphan Section
        Some content
        """
        let sections = MarkdownSectionParser.parse(md)

        // Preamble (empty) + orphan h3
        let h3s = sections.filter { $0.level == 3 }
        #expect(h3s.count == 1)
        #expect(h3s[0].heading == "Orphan Section")
    }

    // MARK: - Code Blocks

    @Test("Headings inside code blocks are not treated as section splits")
    func codeBlocksNotSplit() {
        let md = """
        ## Real Section
        Here is code:

        ```markdown
        ## This is NOT a heading
        ### Neither is this
        ```

        Still in Real Section.
        """
        let sections = MarkdownSectionParser.parse(md)

        let h2s = sections.filter { $0.level == 2 }
        #expect(h2s.count == 1)
        #expect(h2s[0].heading == "Real Section")
        #expect(h2s[0].content.contains("## This is NOT a heading"))
        #expect(h2s[0].content.contains("Still in Real Section"))
    }

    // MARK: - Empty Content Between Headings

    @Test("Empty content between headings produces empty content string")
    func emptyContentBetweenHeadings() {
        let md = """
        ## First
        ## Second
        Some content
        """
        let sections = MarkdownSectionParser.parse(md)

        let h2s = sections.filter { $0.level == 2 }
        #expect(h2s.count == 2)
        #expect(h2s[0].heading == "First")
        #expect(h2s[0].content == "")
        #expect(h2s[1].heading == "Second")
        #expect(h2s[1].content.contains("Some content"))
    }

    // MARK: - IDs

    @Test("Each section has a unique ID")
    func uniqueIds() {
        let md = """
        Preamble

        ## Section A
        Content A

        ### Sub A1
        Sub content

        ## Section B
        Content B
        """
        let sections = MarkdownSectionParser.parse(md)

        var allIds: [Int] = []
        for section in sections {
            allIds.append(section.id)
            for child in section.children {
                allIds.append(child.id)
            }
        }

        #expect(Set(allIds).count == allIds.count)
    }

    // MARK: - Mixed Structure

    @Test("Complex mixed structure parses correctly")
    func complexMixedStructure() {
        let md = """
        # Title
        Intro paragraph

        ## Getting Started
        Install instructions

        ### Prerequisites
        Need Node.js

        ### Configuration
        Set env vars

        ## Usage
        Run the app

        ## FAQ
        """
        let sections = MarkdownSectionParser.parse(md)

        // Preamble (with h1 + intro) + 3 h2 sections
        let preamble = sections.first { $0.level == 0 }
        #expect(preamble != nil)
        #expect(preamble?.content.contains("# Title") == true)

        let h2s = sections.filter { $0.level == 2 }
        #expect(h2s.count == 3)
        #expect(h2s[0].heading == "Getting Started")
        #expect(h2s[0].children.count == 2)
        #expect(h2s[1].heading == "Usage")
        #expect(h2s[1].children.isEmpty)
        #expect(h2s[2].heading == "FAQ")
        #expect(h2s[2].content == "")
    }
}
