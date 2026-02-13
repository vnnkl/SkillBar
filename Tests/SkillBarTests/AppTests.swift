import Testing
@testable import SkillBar

@Suite("AppDelegate Smoke Tests")
struct AppTests {
    @Test("AppDelegate initializes with nil statusItem and popover")
    @MainActor
    func initialState() {
        let delegate = AppDelegate()
        #expect(delegate.statusItem == nil)
        #expect(delegate.popover == nil)
    }
}
