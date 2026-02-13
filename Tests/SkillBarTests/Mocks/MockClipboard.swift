@testable import SkillBar

final class MockClipboard: ClipboardProvider, @unchecked Sendable {
    var lastCopiedString: String?
    var copyCallCount = 0

    func copy(_ string: String) {
        copyCallCount += 1
        lastCopiedString = string
    }
}
