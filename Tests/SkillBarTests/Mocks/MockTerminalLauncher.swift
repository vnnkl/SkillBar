import Foundation
@testable import SkillBar

@MainActor
final class MockTerminalLauncher: TerminalLaunching, @unchecked Sendable {
    var launchCallCount = 0
    var lastCommand: String?
    var lastMode: LaunchMode?
    var lastBundleID: String?

    func launch(command: String, mode: LaunchMode, terminalBundleID: String?) async {
        launchCallCount += 1
        lastCommand = command
        lastMode = mode
        lastBundleID = terminalBundleID
    }
}
