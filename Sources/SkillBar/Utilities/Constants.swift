import AppKit
import Carbon.HIToolbox

enum Constants {
    static let popoverWidth: CGFloat = 400
    static let popoverHeight: CGFloat = 500

    static let hotkeyKeyCode: UInt16 = UInt16(kVK_ANSI_K)
    static let hotkeyModifiers: NSEvent.ModifierFlags = [.command, .shift]

    // Carbon hotkey constants
    static let carbonHotkeyKeyCode: UInt32 = UInt32(kVK_ANSI_K)
    static let carbonHotkeyModifiers: UInt32 = UInt32(cmdKey | shiftKey)
    static let hotkeyID = EventHotKeyID(signature: OSType(0x534B4252), id: 1) // "SKBR"

    static let favoritesKey = "favoriteSkillNames"
    static let debounceInterval: TimeInterval = 0.5

    // Design
    static let cornerRadius: CGFloat = 6
    static let buttonMinSize: CGFloat = 28
    static let standalonePackageKey = "Standalone"
    static let detailPanelWidth: CGFloat = 420

    static var scanDirectories: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.claude/skills",
            "\(home)/.claude/plugins/cache",
            "\(home)/.claude/plugins/marketplaces",
        ]
    }

    static let skillFileName = "SKILL.md"

    // Persistence keys
    static let collapsedPackagesKey = "collapsedPackageNames"
    static let usageRecordsKey = "skillUsageRecords"
    static let skillTagsKey = "skillTags"

    // Usage tracking limits
    static let recentLimit = 10
    static let frequentThreshold = 5
    static let frequentLimit = 5
    static let maxTagLength = 30
    static let maxTagsPerSkill = 5
}
