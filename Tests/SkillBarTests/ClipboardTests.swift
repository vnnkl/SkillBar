import Testing
@testable import SkillBar

@Suite("Clipboard Tests")
struct ClipboardTests {

    @Test("MockClipboard records copied string")
    func mockClipboardRecordsCopy() {
        let clipboard = MockClipboard()
        clipboard.copy("/commit")

        #expect(clipboard.lastCopiedString == "/commit")
        #expect(clipboard.copyCallCount == 1)
    }

    @Test("MockClipboard overwrites previous content")
    func mockClipboardOverwrites() {
        let clipboard = MockClipboard()
        clipboard.copy("/first")
        clipboard.copy("/second")

        #expect(clipboard.lastCopiedString == "/second")
        #expect(clipboard.copyCallCount == 2)
    }

    @Test("MockClipboard handles special characters")
    func mockClipboardSpecialChars() {
        let clipboard = MockClipboard()
        clipboard.copy("/my-skill:sub-command")

        #expect(clipboard.lastCopiedString == "/my-skill:sub-command")
    }

    @Test("Clipboard conforms to ClipboardProvider protocol")
    func clipboardConformsToProtocol() {
        let clipboard: any ClipboardProvider = Clipboard()
        #expect(clipboard is Clipboard)
    }
}
