@testable import SkillBar

final class MockSkillScanner: SkillScanning, @unchecked Sendable {
    var stubbedSkills: [Skill] = []
    var scanCallCount = 0
    var shouldThrow = false

    func scan() throws -> [Skill] {
        scanCallCount += 1
        if shouldThrow {
            throw MockScannerError.scanFailed
        }
        return stubbedSkills
    }
}

enum MockScannerError: Error {
    case scanFailed
}
