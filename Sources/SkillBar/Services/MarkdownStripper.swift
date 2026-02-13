import Foundation

enum MarkdownStripper {

    static func stripFrontmatter(_ content: String) -> String {
        let lines = content.components(separatedBy: "\n")

        var firstDelimiter: Int?
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("---") && trimmed.allSatisfy({ $0 == "-" || $0 == " " }) {
                firstDelimiter = index
                break
            }
            let stripped = trimmed
                .replacingOccurrences(of: "<!--", with: "")
                .replacingOccurrences(of: "-->", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !stripped.isEmpty && !trimmed.hasPrefix("<!--") && !trimmed.hasPrefix("-->") && !trimmed.isEmpty {
                return content
            }
        }

        guard let start = firstDelimiter else { return content }

        for index in (start + 1)..<lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("---") && trimmed.allSatisfy({ $0 == "-" || $0 == " " }) {
                let remaining = lines[(index + 1)...]
                let result = remaining.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return result.isEmpty ? content : result
            }
        }

        return content
    }
}
