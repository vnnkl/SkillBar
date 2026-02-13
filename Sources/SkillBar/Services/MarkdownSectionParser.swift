import Foundation

struct MarkdownSection: Identifiable, Sendable {
    let id: Int
    let level: Int        // 0=preamble, 2=##, 3=###
    let heading: String   // text without # prefix
    let content: String   // markdown below heading
    let children: [MarkdownSection]
}

enum MarkdownSectionParser {

    static func parse(_ markdown: String) -> [MarkdownSection] {
        let lines = markdown.components(separatedBy: "\n")
        var flatSections: [(level: Int, heading: String, lines: [String])] = []
        var currentLines: [String] = []
        var currentLevel = 0
        var currentHeading = ""
        var inFencedBlock = false
        var nextId = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                inFencedBlock = !inFencedBlock
            }

            if !inFencedBlock, let match = headingMatch(trimmed) {
                flatSections.append((
                    level: currentLevel,
                    heading: currentHeading,
                    lines: currentLines
                ))
                currentLevel = match.level
                currentHeading = match.text
                currentLines = []
            } else {
                currentLines.append(line)
            }
        }

        flatSections.append((
            level: currentLevel,
            heading: currentHeading,
            lines: currentLines
        ))

        return buildTree(from: flatSections, nextId: &nextId)
    }

    private struct HeadingMatch {
        let level: Int
        let text: String
    }

    private static func headingMatch(_ line: String) -> HeadingMatch? {
        // Match ## or ### headings only (h2/h3). h1 (#) is treated as preamble content.
        guard line.hasPrefix("##") else { return nil }

        var hashCount = 0
        for char in line {
            if char == "#" { hashCount += 1 }
            else { break }
        }

        guard hashCount >= 2, hashCount <= 3 else { return nil }

        let rest = String(line.dropFirst(hashCount))
            .trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty else { return nil }

        return HeadingMatch(level: hashCount, text: rest)
    }

    private static func buildTree(
        from flat: [(level: Int, heading: String, lines: [String])],
        nextId: inout Int
    ) -> [MarkdownSection] {
        var result: [MarkdownSection] = []
        var index = 0

        while index < flat.count {
            let item = flat[index]
            let content = item.lines.joined(separator: "\n")
                .trimmingCharacters(in: .newlines)

            if item.level == 2 {
                // Collect child h3 sections
                var children: [MarkdownSection] = []
                var childIndex = index + 1
                while childIndex < flat.count, flat[childIndex].level == 3 {
                    let child = flat[childIndex]
                    let childContent = child.lines.joined(separator: "\n")
                        .trimmingCharacters(in: .newlines)
                    let childSection = MarkdownSection(
                        id: nextId,
                        level: 3,
                        heading: child.heading,
                        content: childContent,
                        children: []
                    )
                    nextId += 1
                    children.append(childSection)
                    childIndex += 1
                }

                let section = MarkdownSection(
                    id: nextId,
                    level: 2,
                    heading: item.heading,
                    content: content,
                    children: children
                )
                nextId += 1
                result.append(section)
                index = childIndex
            } else {
                // Preamble (level 0) or orphan h3
                let section = MarkdownSection(
                    id: nextId,
                    level: item.level,
                    heading: item.heading,
                    content: content,
                    children: []
                )
                nextId += 1
                result.append(section)
                index += 1
            }
        }

        return result
    }
}
