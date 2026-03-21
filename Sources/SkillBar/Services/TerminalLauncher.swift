import AppKit

@MainActor
protocol TerminalLaunching: Sendable {
    func launch(command: String, mode: LaunchMode, terminalBundleID: String?) async
}

@MainActor
final class TerminalLauncher: TerminalLaunching, @unchecked Sendable {

    func launch(command: String, mode: LaunchMode, terminalBundleID: String?) async {
        guard mode != .copyOnly, let bundleID = terminalBundleID else { return }
        activateApp(bundleID: bundleID)
        let execute = mode == .pasteAndExecute
        if let script = buildScript(bundleID: bundleID, command: command, execute: execute) {
            runOsascript(script)
        }
    }

    // MARK: - Internal (visible to tests)

    func buildScript(bundleID: String, command: String, execute: Bool) -> String? {
        let escaped = escapeForAppleScript(command)
        switch bundleID {
        case "com.googlecode.iterm2":
            let newline = execute ? "yes" : "no"
            return """
                tell application "iTerm2"
                    tell current session of current window
                        write text "\(escaped)" newline \(newline)
                    end tell
                end tell
                """
        case "com.apple.Terminal":
            guard execute else { return nil }
            return """
                tell application "Terminal"
                    do script "\(escaped)" in front window
                end tell
                """
        default:
            return nil
        }
    }

    func escapeForAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - Private

    private func runOsascript(_ script: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }

    private func activateApp(bundleID: String) {
        NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == bundleID }?
            .activate()
    }
}
