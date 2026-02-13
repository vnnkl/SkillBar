# SkillBar - macOS Menu Bar Skills Cheat Sheet

## Context
You have 130+ Claude Code skills across local, symlinked, and plugin sources. No quick way to see them all. SkillBar = menu bar app that scans `~/.claude/skills/` and plugin dirs, parses SKILL.md frontmatter, shows searchable cheat sheet. Click to copy `/command`.

## Architecture
- **Swift 6 + SwiftUI**, SPM, macOS 14+, zero dependencies
- Menu bar only (no dock icon via `.accessory` activation policy)
- `NSPopover` (400x500) attached to `NSStatusItem`
- Global hotkey: `Cmd+Shift+K` via `NSEvent.addGlobalMonitorForEvents`
- FSEvents file watcher for live refresh

## File Structure (14 files)
```
SkillBar/
  Package.swift
  Sources/SkillBar/
    App/
      SkillBarApp.swift         # @main, hides dock icon
      AppDelegate.swift         # NSStatusItem, NSPopover, hotkey monitors
    Models/
      Skill.swift               # Identifiable struct: name, desc, source, slashCommand
      SkillSource.swift         # enum: local/symlink/pluginCache (color-coded)
    Services/
      SkillScanner.swift        # Enumerates 3 root dirs, detects symlinks
      FrontmatterParser.swift   # Custom YAML frontmatter parser (no deps)
      FileWatcher.swift         # FSEvents wrapper, 0.5s debounce
    ViewModels/
      SkillListViewModel.swift  # @Observable, search/filter/copy logic
    Views/
      SkillListView.swift       # Search bar + source pills + grouped list
      SkillRowView.swift        # /name + desc + source badge, click-to-copy
    Utilities/
      Clipboard.swift           # NSPasteboard helper
      Constants.swift           # Paths, dimensions, keycode
```

## Scan Paths
1. `~/.claude/skills/` -> `.local` (non-symlink dirs) or `.symlink`
2. `~/.claude/plugins/cache/**/SKILL.md` -> `.pluginCache`
3. `~/.claude/plugins/marketplaces/**/SKILL.md` -> `.pluginCache` (same category)

## FrontmatterParser
Custom parser handles real-world SKILL.md quirks:
- Skips HTML comments before opening `---`
- Handles `description: >` folded multiline
- Handles YAML lists (`- item`) and CSV strings
- Handles quoted values, booleans
- No Yams dependency needed

## UI Layout
```
+------------------------------------------+
| [terminal icon]  SkillBar                |
+------------------------------------------+
| [Search skills...                      ] |
| [All(131)] [Local(20)] [Symlink(10)] ... |
+------------------------------------------+
| LOCAL                                    |
|  /commit              [local]            |
|  Write conventional commit messages...   |
|  /docker-optimize     [local]            |
|  Audit Dockerfiles for size, security... |
| SYMLINK                                  |
|  /compound-plan       [symlink]          |
|  Implementation plans for ralph-tui...   |
| PLUGIN                                   |
|  /tdd-workflow        [plugin]           |
|  ...                                     |
+------------------------------------------+
| 131 skills              [Refresh]        |
+------------------------------------------+
```

Click row -> copies `/skill-name` to clipboard, checkmark animation.

## Build & Run
```bash
cd ~/Code/SkillBar
swift build && swift run SkillBar
# Release: swift build -c release
```

## Design Decisions
- **No detail view in v1** - just name + 2-line desc + click-to-copy. Keep it fast.
- **Show all sources** - no hiding plugin skills, user can filter with pills
- **Deduplicate by name** - keep highest-priority source (local > symlink > plugin)
- **No login item in v1** - user runs manually or adds to Login Items themselves
- **Accessibility permission** needed for global hotkey - show alert if denied

## Verification
1. `swift build` succeeds
2. `swift run SkillBar` shows terminal icon in menu bar
3. Click icon -> popover with all skills
4. Search filters in real-time
5. Click skill -> `/name` copied to clipboard
6. Add/remove a SKILL.md -> list auto-refreshes
7. Cmd+Shift+K toggles popover from any app
