# SkillBar Feature Ideas — 2026-03-21

Selected from Idea Wizard session (30 → 5 → 15 → 6 selected).

---

## C5. Collapsible Package Groups with Memory

**Goal**: Package group expand/collapse state persists across popover opens.

**User story**: As a power user with many packages, I want my collapsed groups to stay collapsed so I don't re-collapse noisy packages every time I open SkillBar.

**Scope**: Small (hours)

**Key requirements**:
- Persist expand/collapse state per package group name in UserDefaults
- Restore state when popover reopens
- New packages default to expanded
- Removed packages silently drop from persistence

**Technical approach**:
- Store a `Set<String>` of collapsed group names via `KeyValueStore`
- Read/write in `SkillListViewModel` where disclosure group state is managed
- No new files needed — extends existing ViewModel + UserDefaults infrastructure

**Acceptance criteria**:
- [ ] Collapse a package group, close popover, reopen — group stays collapsed
- [ ] Expand a collapsed group, close popover, reopen — group stays expanded
- [ ] Newly discovered packages appear expanded by default
- [ ] "Clear Favorites" in Settings does NOT reset group collapse state

---

## C1. User-Defined Tags

**Goal**: Users can tag skills with freeform labels and filter by tag.

**User story**: As a user with 50+ skills, I want to tag skills by intent (e.g. "testing", "deploy") so I can find them across packages.

**Scope**: Medium (days)

**Key requirements**:
- Add/remove tags on a skill via context menu or detail view
- Tags stored in UserDefaults keyed by skill identifier
- Tag filter bar (below source pills or inline)
- Multiple tag selection filters with AND logic
- Tags survive skill file changes (keyed by name, not path)

**Technical approach**:
- New `SkillListViewModel+Tags.swift` extension for tag CRUD and filtering
- Store `[String: [String]]` (skill name → tags) in `KeyValueStore`
- Add tag pills UI in `SkillListView` — dynamically built from all used tags
- Tag editing via right-click context menu on `SkillRowView` or a tag editor in `SkillDetailView`
- Filter integration in `SkillListViewModel+Filtering.swift`

**Acceptance criteria**:
- [ ] Right-click a skill → "Add Tag" → type freeform tag → tag appears on row
- [ ] Tags persist across app restarts
- [ ] Clicking a tag pill filters to only skills with that tag
- [ ] Multiple tag selection narrows results (AND)
- [ ] Tags visible as small pills on skill rows
- [ ] "Manage Tags" in Settings allows deleting tags globally
- [ ] Removing a skill's last tag removes it from filtered view only if tag filter is active

**Open questions**:
- Should there be suggested/preset tags, or purely freeform?
- Max tags per skill — unlimited or capped (e.g. 5)?

---

## B1. Recently Used Skills

**Goal**: A "Recent" section shows the last 10 copied skills.

**User story**: As a user, I want to quickly re-invoke a skill I just used without searching for it again.

**Scope**: Small (hours)

**Key requirements**:
- Track skill name + timestamp on every copy action
- Show "Recent" section (collapsible) above main list, below Favorites
- Cap at 10 entries, FIFO eviction
- Persist across app restarts

**Technical approach**:
- Store an array of `{skillName: String, timestamp: Date}` in `KeyValueStore`
- Hook into the existing copy action in `SkillListViewModel`
- New section in `SkillListView` between Favorites and main list
- Reuse `SkillRowView` for recent entries

**Acceptance criteria**:
- [ ] Copy a skill → it appears in "Recent" section on next popover open
- [ ] Most recent skill at top of the section
- [ ] Max 10 entries; 11th copy evicts oldest
- [ ] Duplicates move to top instead of creating a second entry
- [ ] Recent section is collapsible
- [ ] Persists across app restarts

---

## B2. Most Used Skills (Frequently Used)

**Goal**: Auto-surface skills based on actual usage frequency.

**User story**: As a daily user, I want my most-copied skills to appear prominently without manually favoriting them.

**Scope**: Small (hours)

**Key requirements**:
- Increment counter per skill on every copy
- Show "Frequently Used" section after a skill hits a threshold (e.g. 5+ copies)
- Sorted by count descending, capped at 5 shown
- Persist counts across restarts

**Technical approach**:
- Store `[String: Int]` (skill name → count) in `KeyValueStore`
- Share the analytics write path with B1 (single hook point in copy action)
- New section in `SkillListView` — show after Favorites and Recent
- "Reset Usage Data" button in Settings

**Acceptance criteria**:
- [ ] Copy a skill 5 times → it appears in "Frequently Used"
- [ ] Section sorted by copy count (highest first)
- [ ] Max 5 skills shown in this section
- [ ] Skills also appear in their normal package location (not removed)
- [ ] "Reset Usage Data" in Settings clears all counts
- [ ] Section hidden when no skill has reached threshold

---

## B3. Active Project Context Detection

**Goal**: SkillBar detects the active terminal's project and boosts relevant skills.

**User story**: As a developer switching between projects, I want SkillBar to highlight skills relevant to my current working directory.

**Scope**: Large (weeks)

**Key requirements**:
- Detect frontmost terminal app's CWD
- Check for project-specific skills in `<cwd>/.claude/skills/`
- Add "Project" filter pill when project skills are detected
- Boost project skills to top of list when no filter is active

**Technical approach**:
- New `TerminalDetector` service using AppleScript or `lsof` on tty
- Support Terminal.app, iTerm2, Warp, Kitty
- New `SkillSource.project` case in `SkillSource.swift`
- Scan `<detected_cwd>/.claude/skills/` and merge into skill list with highest priority
- Add "Project" pill to source filter bar
- Re-scan on popover open (not continuously)

**Acceptance criteria**:
- [ ] Open terminal in a project with `.claude/skills/` → "Project" pill appears
- [ ] Project skills appear at top of unfiltered list
- [ ] "Project" pill filters to only project-scoped skills
- [ ] Switching terminal projects updates on next popover open
- [ ] Graceful fallback when terminal CWD can't be detected (no crash, no "Project" pill)
- [ ] Works with Terminal.app and iTerm2 at minimum

**Open questions**:
- Should this require Accessibility permission? AppleScript may suffice for some terminals but not others
- Should project skills be cached, or always re-scanned on popover open?

---

## B4. Smart Search with Field Weighting

**Goal**: Search results ranked by relevance instead of flat substring matching.

**User story**: As a user searching for "test", I want skills named "tdd" and "test-runner" above skills that merely mention testing in their description.

**Scope**: Small (hours)

**Key requirements**:
- Name matches rank above description matches, which rank above package matches
- Exact prefix matches rank above substring matches
- Maintain current instant-filter UX (no delay)

**Technical approach**:
- Add a `searchScore(query:)` method to `Skill` model
- Scoring: name-prefix=100, name-contains=80, description-prefix=60, description-contains=40, package-contains=20
- Sort filtered results by score descending in `SkillListViewModel+Filtering.swift`
- No new dependencies — pure string matching

**Acceptance criteria**:
- [ ] Searching "test" shows `tdd-guide` (name match) above a skill that mentions "test" only in description
- [ ] Exact name match always ranks first
- [ ] Search remains instant (no perceptible delay)
- [ ] Empty search returns normal order (favorites/package grouping)
