import AppKit
import Carbon.HIToolbox

enum Constants {
    static let popoverWidth: CGFloat = 400
    static let popoverHeight: CGFloat = 500

    static let hotkeyKeyCode: UInt16 = UInt16(kVK_ANSI_K)
    static let hotkeyModifiers: NSEvent.ModifierFlags = [.command, .shift]

    static let debounceInterval: TimeInterval = 0.5

    static var scanDirectories: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.claude/skills",
            "\(home)/.claude/plugins/cache",
            "\(home)/.claude/plugins/marketplaces",
        ]
    }

    static let skillFileName = "SKILL.md"
}
