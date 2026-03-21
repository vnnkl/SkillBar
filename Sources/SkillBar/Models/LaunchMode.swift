enum LaunchMode: String, CaseIterable, Sendable {
    case copyOnly
    case paste
    case pasteAndExecute

    var displayName: String {
        switch self {
        case .copyOnly: "Copy Only"
        case .paste: "Paste"
        case .pasteAndExecute: "Paste + Run"
        }
    }
}
