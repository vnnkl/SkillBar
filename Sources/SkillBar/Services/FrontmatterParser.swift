import Foundation

struct FrontmatterResult: Equatable, Sendable {
    let name: String?
    let description: String?
}

enum FrontmatterParser {

    static func parse(_ content: String) -> FrontmatterResult {
        guard let yaml = extractFrontmatter(from: content) else {
            return FrontmatterResult(name: nil, description: nil)
        }

        let fields = parseYAMLFields(yaml)
        return FrontmatterResult(
            name: fields["name"],
            description: fields["description"]
        )
    }

    // MARK: - Frontmatter Extraction

    private static func extractFrontmatter(from content: String) -> String? {
        let lines = content.components(separatedBy: "\n")

        var startIndex: Int?
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("---") && trimmed.allSatisfy({ $0 == "-" || $0 == " " }) {
                startIndex = index
                break
            }
            // Allow HTML comments before frontmatter
            let stripped = trimmed
                .replacingOccurrences(of: "<!--", with: "")
                .replacingOccurrences(of: "-->", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !stripped.isEmpty && !trimmed.hasPrefix("<!--") && !trimmed.hasPrefix("-->") && !trimmed.isEmpty {
                // Non-comment, non-empty, non-delimiter line before frontmatter
                return nil
            }
        }

        guard let start = startIndex else { return nil }

        for index in (start + 1)..<lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("---") && trimmed.allSatisfy({ $0 == "-" || $0 == " " }) {
                let yamlLines = lines[(start + 1)..<index]
                let yaml = yamlLines.joined(separator: "\n")
                return yaml.isEmpty ? nil : yaml
            }
        }

        return nil
    }

    // MARK: - Simple YAML Parsing

    private static func parseYAMLFields(_ yaml: String) -> [String: String] {
        var fields: [String: String] = [:]
        let lines = yaml.components(separatedBy: "\n")
        var index = 0

        while index < lines.count {
            let line = lines[index]

            guard let colonRange = line.range(of: ":"),
                  !line.trimmingCharacters(in: .whitespaces).hasPrefix("-"),
                  !line.trimmingCharacters(in: .whitespaces).hasPrefix("#") else {
                index += 1
                continue
            }

            let key = String(line[line.startIndex..<colonRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let rawValue = String(line[colonRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)

            if rawValue == ">" || rawValue == "|" {
                // Multiline folded/literal block
                let multiline = collectMultilineValue(lines: lines, startingAfter: index)
                fields[key] = multiline.value
                index = multiline.nextIndex
            } else if rawValue.isEmpty {
                // Could be a YAML list or map — skip
                index += 1
            } else {
                fields[key] = stripQuotes(rawValue)
                index += 1
            }
        }

        return fields
    }

    private static func collectMultilineValue(
        lines: [String],
        startingAfter index: Int
    ) -> (value: String, nextIndex: Int) {
        var parts: [String] = []
        var i = index + 1

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Continuation lines must be indented
            if line.first == " " || line.first == "\t" {
                // Check if this is a new key (indented key: value)
                if trimmed.contains(":") && !trimmed.hasPrefix("-") {
                    let beforeColon = trimmed.prefix(while: { $0 != ":" })
                    if beforeColon.allSatisfy({ $0.isLetter || $0 == "-" || $0 == "_" }) && !beforeColon.isEmpty {
                        break
                    }
                }
                parts.append(trimmed)
            } else {
                break
            }

            i += 1
        }

        let joined = parts.joined(separator: " ")
        return (value: joined, nextIndex: i)
    }

    private static func stripQuotes(_ value: String) -> String {
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
           (value.hasPrefix("'") && value.hasSuffix("'")) {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}
