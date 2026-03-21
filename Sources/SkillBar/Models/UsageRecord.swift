import Foundation

struct UsageRecord: Codable, Sendable, Equatable {
    let skillName: String
    var copyCount: Int
    var lastCopiedAt: Date
}
