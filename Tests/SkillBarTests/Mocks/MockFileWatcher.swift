@testable import SkillBar

final class MockFileWatcher: FileWatching, @unchecked Sendable {
    var startCallCount = 0
    var stopCallCount = 0
    var onChangeHandler: (@Sendable () -> Void)?

    func start(onChange: @escaping @Sendable () -> Void) {
        startCallCount += 1
        onChangeHandler = onChange
    }

    func stop() {
        stopCallCount += 1
        onChangeHandler = nil
    }

    func simulateChange() {
        onChangeHandler?()
    }
}
