# Plan: Quick Launch (Synthesized)

*Synthesized from 3 competing plans (Alpha/Pragmatist, Bravo/Defender, Charlie/Architect)*

## Problem Statement

SkillBar copies `/commands` to clipboard, but users must still Cmd+Tab, Cmd+V, Enter. Quick Launch eliminates this: one click pastes the command directly into the active terminal session.

## Goals

- One-click skill execution: click → command appears in terminal
- Support iTerm2, Terminal.app, Warp (with graceful fallback)
- Three launch modes: Copy Only (default) / Paste / Paste + Execute
- No new external dependencies
- Preserve current behavior as default

## Non-Goals

- Detecting which terminal runs Claude Code
- VS Code integrated terminal, Emacs
- Reading terminal output
- Linux/Windows

## Source Attribution

- **Architecture:** Alpha's closures + single TerminalLaunching protocol
- **AppleScript execution:** Bravo's `Process`-based `osascript` (avoids blocking MainActor)
- **Error handling:** Bravo's comprehensive failure matrix
- **Testability:** Charlie's mock pattern, Alpha's MockTerminalLauncher
- **Complexity target:** Alpha's ~300 LOC scope

## Architecture

### Data Flow

```
Cmd+Shift+K pressed
  → AppDelegate captures NSWorkspace.shared.frontmostApplication (before popover shows)
  → stores previousApp

User clicks skill
  → SkillListViewModel.launchSkill(skill)
    → copySkill(skill)              // clipboard + analytics + checkmark (always first)
    → if launchMode == .copyOnly: done
    → else:
        → closePopover?()           // dismiss popover
        → Task.sleep(150ms)         // let popover animate out
        → terminalLauncher.launch(  // fire AppleScript
            command: slashCommand,
            mode: launchMode,
            terminalBundleID: capturedTerminalBundleID?()
          )
```

### Components

```
AppDelegate
  ├── captures previousApp before showing popover
  ├── sets closures on ViewModel: closePopover, capturedTerminalBundleID
  └── unchanged hotkey/popover lifecycle

SkillListViewModel
  ├── launchMode: LaunchMode (persisted via KeyValueStore)
  ├── closePopover: (() -> Void)?
  ├── capturedTerminalBundleID: (() -> String?)?
  ├── terminalLauncher: TerminalLaunching
  └── launchSkill(_:) → calls copySkill then launcher

TerminalLauncher (concrete)
  ├── launch(command:mode:terminalBundleID:) async
  ├── switch on bundleID: iTerm2 / Terminal.app / fallback
  ├── builds AppleScript per terminal
  ├── runs via Process("/usr/bin/osascript") — non-blocking
  └── on failure: activates terminal (clipboard already has command)
```

### Key Design Decisions

**No strategy pattern.** Three terminals don't justify 3 strategy files. A switch/case in one file is clearer. Extract to strategies when terminal #4 arrives.

**`Process`-based osascript, not `NSAppleScript`.** `NSAppleScript.executeAndReturnError()` is synchronous and blocks MainActor. `Process` with `osascript -e` is fire-and-forget. (Bravo's insight)

**Closures for popover/terminal wiring, not protocol injection.** ViewModel gets `closePopover: (() -> Void)?` and `capturedTerminalBundleID: (() -> String?)?`. Simpler than making AppDelegate conform to a protocol.

**Store `LaunchMode` as `[String]`.** Encode `[mode.rawValue]` via existing `KeyValueStore.set([String], forKey:)`. No protocol expansion needed.

**Keep `copySkill`, add `launchSkill` on top.** Avoids breaking call sites and tests. `launchSkill` calls `copySkill` then does the terminal interaction.

## Data Model

### LaunchMode

```swift
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
```

Persisted as `[rawValue]` under `Constants.launchModeKey` ("launchMode"). Missing key → `.copyOnly`.

### Terminal Identification

Bundle IDs matched via switch:
- `"com.googlecode.iterm2"` → iTerm2
- `"com.apple.Terminal"` → Terminal.app
- `"dev.warp.Warp-Stable"` → Warp (fallback only)
- anything else → fallback (clipboard + activate)

## Detailed Design

### New Files

#### `Sources/SkillBar/Models/LaunchMode.swift` (~15 lines)

The enum above.

#### `Sources/SkillBar/Services/TerminalLauncher.swift` (~90 lines)

```swift
@MainActor
protocol TerminalLaunching: Sendable {
    func launch(command: String, mode: LaunchMode, terminalBundleID: String?) async
}

final class TerminalLauncher: TerminalLaunching, @unchecked Sendable {

    func launch(command: String, mode: LaunchMode, terminalBundleID: String?) async {
        guard mode != .copyOnly else { return }
        guard let bundleID = terminalBundleID else { return }

        let execute = mode == .pasteAndExecute
        let script = buildScript(bundleID: bundleID, command: command, execute: execute)

        // Activate terminal
        activateApp(bundleID: bundleID)

        // Run AppleScript if we have one
        if let script {
            runOsascript(script)
        }
    }

    // MARK: - Script Building

    private func buildScript(bundleID: String, command: String, execute: Bool) -> String? {
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
            if execute {
                return """
                    tell application "Terminal"
                        do script "\(escaped)" in front window
                    end tell
                    """
            } else {
                // Paste-only for Terminal.app needs System Events (Accessibility)
                // Fall back to clipboard + activate; user pastes manually
                return nil
            }
        default:
            // Warp, Kitty, unknown — no AppleScript
            return nil
        }
    }

    // MARK: - Execution

    private func runOsascript(_ script: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        // Fire and forget — clipboard already has command
    }

    private func activateApp(bundleID: String) {
        NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == bundleID }?
            .activate()
    }

    private func escapeForAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
```

#### `Sources/SkillBar/ViewModels/SkillListViewModel+Launch.swift` (~40 lines)

```swift
extension SkillListViewModel {
    func launchSkill(_ skill: Skill) {
        copySkill(skill)
        guard launchMode != .copyOnly else { return }
        let command = skill.slashCommand
        let bundleID = capturedTerminalBundleID?()
        let mode = launchMode
        closePopover?()
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            await terminalLauncher.launch(
                command: command,
                mode: mode,
                terminalBundleID: bundleID
            )
        }
    }

    func setLaunchMode(_ mode: LaunchMode) {
        launchMode = mode
        store.set([mode.rawValue], forKey: Constants.launchModeKey)
    }
}
```

### Modified Files

#### `Sources/SkillBar/Utilities/Constants.swift`

Add: `static let launchModeKey = "launchMode"`

#### `Sources/SkillBar/ViewModels/SkillListViewModel.swift`

Add stored properties:
```swift
var launchMode: LaunchMode = .copyOnly
var closePopover: (() -> Void)?
var capturedTerminalBundleID: (() -> String?)?
private let terminalLauncher: TerminalLaunching
```

Update init:
- Accept `terminalLauncher: TerminalLaunching = TerminalLauncher()`
- Load launch mode: `if let stored = store.array(forKey: Constants.launchModeKey)?.first, let mode = LaunchMode(rawValue: stored) { launchMode = mode }`

#### `Sources/SkillBar/App/AppDelegate.swift`

Add:
```swift
private var previousApp: NSRunningApplication?
```

In `togglePopover()`, before `popover.show(...)`:
```swift
previousApp = NSWorkspace.shared.frontmostApplication
```

After `setupViewModel()`:
```swift
viewModel?.closePopover = { [weak self] in
    self?.popover?.performClose(nil)
}
viewModel?.capturedTerminalBundleID = { [weak self] in
    self?.previousApp?.bundleIdentifier
}
```

#### `Sources/SkillBar/ViewModels/SkillListViewModel+Navigation.swift`

Change `confirmSelection()` to call `launchSkill(list[index])` instead of `copySkill(list[index])`.

#### `Sources/SkillBar/Views/SkillListView.swift`

Update `skillRow` `onCopy` closure to call `viewModel.launchSkill(skill)`.

Update `SettingsView` instantiation to pass launch mode props.

#### `Sources/SkillBar/Views/SettingsView.swift`

Add launch mode section (Picker with `.radioGroup` style) between "Launch at Login" and "Clear Favorites":
```swift
private var launchModeSection: some View {
    VStack(alignment: .leading, spacing: 6) {
        Picker("Skill Action", selection: Binding(
            get: { launchMode },
            set: { onSetLaunchMode($0) }
        )) {
            ForEach(LaunchMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.radioGroup)

        Text(launchModeDescription)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
```

Add params: `launchMode: LaunchMode`, `onSetLaunchMode: (LaunchMode) -> Void`.

## Edge Cases (Union of All Plans)

| Edge Case | Handling | Source |
|-----------|----------|--------|
| No terminal was frontmost (Finder, etc.) | `capturedTerminalBundleID` returns non-terminal ID. Launcher activates it (harmless). Clipboard has command. | Alpha |
| iTerm2 has no windows/sessions | AppleScript fails. `Process` exits non-zero. Clipboard has command. | Bravo |
| Terminal.app paste-only mode without Accessibility | `buildScript` returns nil for paste mode. Falls back to clipboard + activate. | Bravo |
| Command contains `"`, `\`, `$` | `escapeForAppleScript` handles `"` and `\`. Shell metacharacters are literal text (not interpreted). | All |
| User switches apps while popover open | `previousApp` was captured at open time. Correct — that was the terminal they were using. | Alpha |
| Rapid double-invoke | Second call overwrites clipboard, sends again. Idempotent for paste; for execute, command runs twice (matches intent). | Alpha |
| Popover dismissal not complete before activate | 150ms delay. If still not dismissed, terminal activates anyway — cosmetic only. | Bravo |
| Terminal.app `do script` creates new window | Use `do script ... in front window`. If no window exists, creates one. | Charlie |
| macOS Automation permission prompt | First `osascript` targeting a terminal triggers system prompt. User approves once. If denied, `osascript` fails silently. Clipboard works. | Bravo |
| Warp terminal | No AppleScript. Clipboard + activate. User pastes manually. | All |
| `frontmostApplication` returns SkillBar itself | Captured before `NSApp.activate()` in `togglePopover()`. Hotkey handler fires before activation. | Bravo |
| LaunchMode decode failure (corrupt UserDefaults) | `LaunchMode(rawValue:)` returns nil → default `.copyOnly`. | Bravo |
| `Process` executable not found | `/usr/bin/osascript` exists on all macOS. If somehow missing, `try? process.run()` swallows error. | Bravo |

## Testing Approach

### New Files

**`Tests/SkillBarTests/Mocks/MockTerminalLauncher.swift`** (~20 lines)
```swift
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
```

**`Tests/SkillBarTests/LaunchTests.swift`** (~120 lines)

Tests:
- `launchSkill` always copies to clipboard (regardless of mode)
- `launchSkill` always records usage
- `launchSkill` in `.copyOnly` does NOT call terminalLauncher
- `launchSkill` in `.paste` calls terminalLauncher with `execute=false`
- `launchSkill` in `.pasteAndExecute` calls terminalLauncher with `execute=true`
- `launchSkill` passes `capturedTerminalBundleID` to launcher
- `launchSkill` calls `closePopover` when mode != `.copyOnly`
- `launchSkill` does NOT call `closePopover` when mode == `.copyOnly`
- `setLaunchMode` persists to store
- `launchMode` loads from store on init
- `launchMode` defaults to `.copyOnly` when store is empty
- `confirmSelection` calls `launchSkill`

**`Tests/SkillBarTests/TerminalLauncherTests.swift`** (~60 lines)

Tests:
- `escapeForAppleScript` handles backslashes and quotes
- `buildScript` returns correct iTerm2 script for paste (newline no)
- `buildScript` returns correct iTerm2 script for execute (newline yes)
- `buildScript` returns correct Terminal.app script for execute
- `buildScript` returns nil for Terminal.app paste-only
- `buildScript` returns nil for unknown bundle ID
- `launch` with `.copyOnly` returns immediately (no process)
- `launch` with nil bundleID returns immediately

## Implementation Order

1. `LaunchMode` enum + `Constants.launchModeKey`
2. `TerminalLaunching` protocol + `TerminalLauncher` service
3. `SkillListViewModel` — add properties, load mode in init
4. `SkillListViewModel+Launch` extension
5. `AppDelegate` — capture previous app, set closures
6. Update `+Navigation.confirmSelection` and `SkillListView` to call `launchSkill`
7. `SettingsView` — launch mode picker
8. `MockTerminalLauncher` + `LaunchTests` + `TerminalLauncherTests`

## File Summary

### New Files (4 source + 1 mock + 2 test)

| File | Lines |
|------|-------|
| `Models/LaunchMode.swift` | ~15 |
| `Services/TerminalLauncher.swift` | ~90 |
| `ViewModels/SkillListViewModel+Launch.swift` | ~40 |
| `Tests/Mocks/MockTerminalLauncher.swift` | ~20 |
| `Tests/LaunchTests.swift` | ~120 |
| `Tests/TerminalLauncherTests.swift` | ~60 |

### Modified Files (6)

| File | Changes |
|------|---------|
| `Utilities/Constants.swift` | +1 key |
| `ViewModels/SkillListViewModel.swift` | +4 properties, +1 init param, +3 lines in init |
| `ViewModels/SkillListViewModel+Navigation.swift` | 1-line change: `launchSkill` |
| `App/AppDelegate.swift` | +1 property, +3 lines in togglePopover, +6 lines wiring closures |
| `Views/SettingsView.swift` | +30 lines (launch mode section) |
| `Views/SkillListView.swift` | +3 lines (pass launch mode props, call launchSkill) |

### Totals

- **~345 production LOC** across 3 new + 6 modified source files
- **~200 test LOC** across 1 mock + 2 test files
- **~545 total**

## Open Questions

1. **Default mode?** Plan says `.copyOnly`. Could make `.paste` the default for new installs since it's strictly better (clipboard still works as fallback).
2. **iTerm2 paste vs execute:** `write text` with `newline no` may not be supported in older iTerm2 versions. Need to verify. If not, paste and execute are identical for iTerm2.
3. **Terminal.app paste-only:** Current plan falls back to clipboard+activate. Could use System Events keystroke if Accessibility is granted. Worth adding as enhancement later.
4. **Dual-action UX:** Row tap = launchSkill, copy button = always copyOnly? Gives both options without settings. Deferred — simpler to start with single mode.
