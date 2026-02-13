# SkillBar

A macOS menu bar app that gives you instant access to all your Claude Code skills. Scans your skill directories, shows a searchable popover, and copies `/commands` to your clipboard with one click.

## Features

- **Menu bar popover** — 400x500 popover attached to a terminal icon in your menu bar
- **Auto-discovery** — scans `~/.claude/skills/`, `~/.claude/plugins/cache/`, and `~/.claude/plugins/marketplaces/` for SKILL.md files
- **YAML frontmatter parsing** — extracts skill name and description from SKILL.md frontmatter (handles multiline, quoted values, HTML comment preambles)
- **Click-to-copy** — click any skill row to copy its `/command` to your clipboard, with a checkmark confirmation
- **Search** — real-time filtering by skill name and description
- **Source filter pills** — filter by All, Local, Symlink, or Plugin sources
- **Favorites** — star skills to pin them to a dedicated Favorites section at the top. Persists across restarts
- **Skill detail view** — click the info button on any row to read the full SKILL.md content
- **Global hotkey** — `Cmd+Shift+K` toggles the popover from any app (no Accessibility permission required, uses Carbon hotkey)
- **Keyboard navigation** — arrow keys to browse, Enter to copy, Tab to move between search and list
- **Live refresh** — FSEventStream watches your skill directories recursively. Add or remove a SKILL.md and the list updates automatically
- **Deduplication** — if the same skill name appears in multiple sources, the highest-priority source wins (local > symlink > plugin)
- **Settings** — gear icon in the footer opens settings with a Clear Favorites button
- **Zero dependencies** — pure Swift 6 + SwiftUI, no third-party packages

## Requirements

- macOS 14 (Sonoma) or later
- Swift 6.0+

## Build & Run

```bash
# Clone and build
git clone <repo-url> && cd SkillBar
swift build

# Run
swift run SkillBar

# Release build
swift build -c release
# Binary at .build/release/SkillBar
```

## Usage

1. Run `swift run SkillBar` — a terminal icon appears in your menu bar
2. Click the icon (or press `Cmd+Shift+K`) to open the popover
3. Type in the search field to filter skills
4. Click a skill row to copy its `/command` to your clipboard
5. Paste the command into Claude Code

### Keyboard workflow

`Cmd+Shift+K` → type to search → `Tab` to move to list → arrow keys to navigate → `Enter` to copy

### Favorites

Click the star icon on any skill row to pin it. Favorites appear in a dedicated section at the top of the list. Clear all favorites from Settings (gear icon in the footer).

### Skill detail

Click the info icon (ⓘ) on any row to view the full SKILL.md file content. Press the back arrow to return to the list.

### Source types

| Badge | Source | Path |
|-------|--------|------|
| **Local** (blue) | Skills you created directly | `~/.claude/skills/<name>/SKILL.md` |
| **Symlink** (orange) | Symlinked skill directories | `~/.claude/skills/<name>/SKILL.md` (symlink) |
| **Plugin** (purple) | Installed plugins | `~/.claude/plugins/cache/**/SKILL.md` and `~/.claude/plugins/marketplaces/**/SKILL.md` |

## Install as a persistent background app

Copy the release binary somewhere on your PATH and add it to your Login Items:

```bash
swift build -c release
cp .build/release/SkillBar /usr/local/bin/skillbar
```

Then add `/usr/local/bin/skillbar` to System Settings → General → Login Items.

## Project structure

```
Sources/SkillBar/
  App/
    SkillBarApp.swift              # @main entry point
    AppDelegate.swift              # NSStatusItem, NSPopover, Carbon hotkey
  Models/
    Skill.swift                    # Identifiable skill struct
    SkillSource.swift              # Source enum with colors and priority
  Protocols/
    Dependencies.swift             # Testability protocols
  Services/
    SkillScanner.swift             # Enumerates skill directories, deduplicates
    FrontmatterParser.swift        # Custom YAML frontmatter parser
    FileWatcher.swift              # FSEventStream recursive watcher with debounce
    DefaultFileSystemProvider.swift # FileManager wrapper
  ViewModels/
    SkillListViewModel.swift       # @Observable, scan/copy/detail logic
    SkillListViewModel+Filtering.swift
    SkillListViewModel+Favorites.swift
    SkillListViewModel+Navigation.swift
  Views/
    SkillListView.swift            # Main popover content
    SkillRowView.swift             # Skill row with copy, favorite, detail, badge
    SkillDetailView.swift          # Full SKILL.md viewer
    SettingsView.swift             # Settings panel
  Utilities/
    Clipboard.swift                # NSPasteboard wrapper
    Constants.swift                # Paths, dimensions, hotkey codes
    UserDefaultsStore.swift        # KeyValueStore implementation
```

## License

MIT
