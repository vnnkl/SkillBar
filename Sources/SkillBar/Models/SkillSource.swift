import SwiftUI

enum SkillSource: String, Hashable, Sendable, CaseIterable {
    case local
    case symlink
    case pluginCache

    var displayName: String {
        switch self {
        case .local: "Local"
        case .symlink: "Symlink"
        case .pluginCache: "Plugin"
        }
    }

    var color: Color {
        switch self {
        case .local: .blue
        case .symlink: .orange
        case .pluginCache: .purple
        }
    }

    var priority: Int {
        switch self {
        case .local: 0
        case .symlink: 1
        case .pluginCache: 2
        }
    }
}
