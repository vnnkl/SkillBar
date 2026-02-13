import Foundation

struct Skill: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let source: SkillSource
    let slashCommand: String
    let filePath: String

    init(name: String, description: String, source: SkillSource, filePath: String) {
        self.id = "\(source.rawValue):\(name)"
        self.name = name
        self.description = description
        self.source = source
        self.slashCommand = "/\(name)"
        self.filePath = filePath
    }
}
