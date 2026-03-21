import Testing
@testable import SkillBar

@Suite("TerminalLauncher")
@MainActor
struct TerminalLauncherTests {

    let launcher = TerminalLauncher()

    // MARK: - escapeForAppleScript

    @Test func escapeNoSpecialChars() {
        #expect(launcher.escapeForAppleScript("hello") == "hello")
    }

    @Test func escapeQuotes() {
        #expect(launcher.escapeForAppleScript("say \"hi\"") == "say \\\"hi\\\"")
    }

    @Test func escapeBackslashes() {
        #expect(launcher.escapeForAppleScript("path\\to\\file") == "path\\\\to\\\\file")
    }

    @Test func escapeBothQuotesAndBackslashes() {
        #expect(launcher.escapeForAppleScript("\"test\\path\"") == "\\\"test\\\\path\\\"")
    }

    // MARK: - buildScript

    @Test func iterm2PasteOnly() {
        let script = launcher.buildScript(bundleID: "com.googlecode.iterm2", command: "ls", execute: false)
        #expect(script != nil)
        #expect(script!.contains("newline no"))
    }

    @Test func iterm2Execute() {
        let script = launcher.buildScript(bundleID: "com.googlecode.iterm2", command: "ls", execute: true)
        #expect(script != nil)
        #expect(script!.contains("newline yes"))
    }

    @Test func terminalExecute() {
        let script = launcher.buildScript(bundleID: "com.apple.Terminal", command: "ls", execute: true)
        #expect(script != nil)
        #expect(script!.contains("do script"))
    }

    @Test func terminalPasteOnlyReturnsNil() {
        let script = launcher.buildScript(bundleID: "com.apple.Terminal", command: "ls", execute: false)
        #expect(script == nil)
    }

    @Test func warpReturnsNil() {
        let script = launcher.buildScript(bundleID: "dev.warp.Warp-Stable", command: "ls", execute: true)
        #expect(script == nil)
    }

    @Test func unknownTerminalReturnsNil() {
        let script = launcher.buildScript(bundleID: "com.unknown.app", command: "ls", execute: true)
        #expect(script == nil)
    }
}
