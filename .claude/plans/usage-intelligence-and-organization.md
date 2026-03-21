# Plan: Usage Intelligence & Organization (Synthesized)

*Synthesized from 3 competing plans (Alpha/Pragmatist, Bravo/Defender, Charlie/Architect)*

## Problem Statement

SkillBar shows all skills equally. As collections grow (50-100+), users waste time re-finding skills they just used, scrolling past collapsed groups that won't stay collapsed, and searching without relevance ranking. The app needs to learn from usage, remember UI state, and let users organize by intent.

## Goals

- C5: Persist package group collapse state across popover opens
- B1: Track recently copied skills, show "Recent" section (last 10, FIFO)
- B2: Track copy frequency, show "Frequently Used" section (5+ copies threshold)
- B4: Rank search results by field relevance (name > description > package)
- C1: User-defined freeform tags on skills with tag-based filtering (AND logic)

## Non-Goals

- B3 (project context detection), AI/semantic search, cross-machine sync, analytics export

## Source Attribution

- **Storage strategy:** Extend `KeyValueStore` with `Data` support (original deep plan)
- **Architecture:** Alpha's direct ViewModel extensions (no intermediate service layer)
- **Search design:** Charlie's dual `rank()`/`matches()` API
- **Scoring algorithm:** Bravo's additive scoring (field matches accumulate)
- **Validation/guards:** Bravo's tag limits + corruption recovery
- **Edge cases:** Union of all three plans

## Architecture

### Storage Layer

Extend `KeyValueStore` protocol with two new methods:

```swift
protocol KeyValueStore: Sendable {
    // existing
    func array(forKey key: String) -> [String]?
    func set(_ value: [String], forKey key: String)
    func removeObject(forKey key: String)
    // new
    func data(forKey key: String) -> Data?
    func set(_ value: Data, forKey key: String)
}
```

Why not tab-delimited encoding (Alpha/Charlie): breaks if tags contain tabs/commas.
Why not JSON inside `[String]` (Bravo): abuses the API semantically.
Protocol extension is 2 methods, trivial implementations, clean API.

### ViewModel Layer

Three new extensions + modifications:

| Extension | Purpose | Est. Lines |
|-----------|---------|-----------|
| `+CollapseState` | Persist collapse state | ~45 |
| `+Analytics` | Usage tracking, recent/frequent | ~100 |
| `+Tags` | Tag CRUD, tag filter state | ~80 |
| `+Filtering` (modify) | Ranked search, tag filter composition | ~30 changed |

### View Layer

| Component | Purpose | Est. Lines |
|-----------|---------|-----------|
| `SearchRanker` (enum) | Pure scoring logic, `rank()` + `matches()` | ~60 |
| `TagChipView` | Reusable tag capsule | ~40 |
| `TagFilterBar` | Tag filter pills row | ~55 |

### Section Display Order

1. **Favorites** (existing)
2. **Recently Used** (new — icon: `clock.arrow.circlepath`)
3. **Frequently Used** (new — icon: `flame.fill`, hidden when empty)
4. **Package groups** (existing, with persisted collapse)

## Data Model

### UsageRecord (B1, B2)

```swift
struct UsageRecord: Codable, Sendable, Equatable {
    let skillName: String
    var copyCount: Int
    var lastCopiedAt: Date
}
```

Stored as JSON-encoded `[UsageRecord]` via `KeyValueStore.set(Data, forKey:)` under key `"skillUsageRecords"`. Single array serves both Recent (sort by `lastCopiedAt`) and Frequent (filter by `copyCount`).

### Tags (C1)

Stored as JSON-encoded `[String: [String]]` (skill name → tags) under key `"skillTags"`. Keyed by `skill.name` (not `skill.id`) so tags survive source changes.

### Collapse State (C5)

Stored as `[String]` (set of collapsed package names) under key `"collapsedPackageNames"`. Uses existing `KeyValueStore.set([String], forKey:)` — no `Data` method needed.

## Data Flow

### Copy Action (B1 + B2)

```
copySkill(_:) → clipboard.copy() → recordUsage(skill)
  → decode [UsageRecord] from store
  → find-or-create record for skill.name
  → increment copyCount, set lastCopiedAt = Date()
  → encode and write back
```

### Search (B4) — Charlie's dual API insight

```
filteredSkills (main package list):
  → SearchRanker.rank(sourceFiltered, query:) → scored + sorted

filteredRecentSkills / filteredFrequentSkills / filteredFavoritedSkills:
  → SearchRanker.matches(skill, query:) → boolean filter only
  → preserves recency/frequency/alpha ordering within sections
```

Why this matters: Alpha and Bravo both apply `rank()` everywhere, which would re-sort the Recent section by search relevance instead of recency. Charlie correctly identified that section-specific ordering must be preserved.

### Collapse State (C5)

```
SkillListView.packageSection → viewModel.togglePackageCollapse(pkg)
  → mutate collapsedPackageNames set → persist as [String]
onAppear: viewModel provides persisted state (no more @State reset)
```

### Tag Filtering (C1)

```
activeTagFilters: Set<String> (ephemeral, not persisted)
matchesTagFilter(skill) → true if activeTagFilters.isEmpty
                       OR skill has ALL active tags (AND logic)
filteredSkills = skills.filter { matchesSourceFilter && matchesTagFilter }
                       then ranked by search if query active
```

## Detailed Design

### Phase 1: Storage Foundation

**Files to create:**
- None

**Files to modify:**
- `Protocols/Dependencies.swift` — add `data(forKey:)` and `set(Data, forKey:)` to `KeyValueStore`
- `Utilities/UserDefaultsStore.swift` — implement via `defaults.data(forKey:)` / `defaults.set(data, forKey:)`
- `Utilities/Constants.swift` — add new persistence keys
- `Tests/Mocks/InMemoryKeyValueStore.swift` — add `dataStorage: [String: Data]` dict

### Phase 2: C5 — Collapse State Persistence

**Files to create:**
- `ViewModels/SkillListViewModel+CollapseState.swift` (~45 lines)

**Files to modify:**
- `ViewModels/SkillListViewModel.swift` — add `var collapsedPackageNames: Set<String> = []`, load in `init`
- `Views/SkillListView.swift` — remove `@State private var collapsedPackages`, remove `initializeCollapseState()`, delegate to viewModel

**Extension API:**
```swift
extension SkillListViewModel {
    func isPackageCollapsed(_ pkg: String) -> Bool
    func togglePackageCollapse(_ pkg: String)
    func setAllPackagesCollapsed(_ collapsed: Bool, packages: [String])
    func expandAllPackages()
}
```

Each mutation persists immediately via `store.set(Array(collapsedPackageNames), forKey:)`.

### Phase 3: B1 + B2 — Usage Analytics

**Files to create:**
- `Models/UsageRecord.swift` (~15 lines)
- `ViewModels/SkillListViewModel+Analytics.swift` (~100 lines)

**Files to modify:**
- `ViewModels/SkillListViewModel.swift` — add stored property, call `recordUsage` in `copySkill`
- `Views/SkillListView.swift` — add Recent and Frequent sections
- `Views/SettingsView.swift` — add "Reset Usage Data" button

**Extension API:**
```swift
extension SkillListViewModel {
    func recordUsage(_ skill: Skill)

    var recentlyUsedSkills: [Skill]             // last 10, recency order
    var filteredRecentlyUsedSkills: [Skill]      // + search/source/tag filter (boolean match, NOT ranked)
    var frequentlyUsedSkills: [Skill]            // >= 5 copies, count desc, max 5
    var filteredFrequentlyUsedSkills: [Skill]    // + search/source/tag filter (boolean match)

    func clearUsageData()
}
```

**Stale entry handling:** Resolve names against current `skills` array. Stale names silently excluded (same pattern as favorites).

**Duplicate in Recent:** Re-copy updates existing record (`lastCopiedAt` = now, `copyCount` += 1). Sorted by `lastCopiedAt` desc, so re-copy moves to top.

### Phase 4: B4 — Smart Search

**Files to create:**
- `Utilities/SearchRanker.swift` (~60 lines)

**Files to modify:**
- `ViewModels/SkillListViewModel+Filtering.swift` — replace `matchesSearch` with ranker

**SearchRanker design (Charlie's dual API + Bravo's additive scoring):**
```swift
enum SearchRanker {
    /// Rank skills by relevance. Returns only matches, sorted by score desc.
    static func rank(_ skills: [Skill], query: String) -> [Skill]

    /// Boolean: does this skill match the query at all?
    static func matches(_ skill: Skill, query: String) -> Bool

    /// Score a single skill. Additive across fields.
    static func score(_ skill: Skill, query: String) -> Int
}
```

**Scoring (additive):**
- Name exact match: +100
- Name/displayName prefix: +80
- Name/displayName contains: +60
- Description contains: +30
- Package contains: +15
- No match across any field: 0

Additive means a skill matching both name AND description gets 60+30=90, naturally outranking a name-only match at 60. This is Bravo's insight — Alpha's "take the max" approach doesn't reward multiple-field matches.

**Filtering change:**
```swift
var filteredSkills: [Skill] {
    let base = skills.filter { matchesSourceFilter($0) && matchesTagFilter($0) }
    guard !searchText.isEmpty else { return base }
    return SearchRanker.rank(base, query: searchText)
}
```

### Phase 5: C1 — Tags

**Files to create:**
- `ViewModels/SkillListViewModel+Tags.swift` (~80 lines)
- `Views/Components/TagChipView.swift` (~40 lines)
- `Views/Components/TagFilterBar.swift` (~55 lines)

**Files to modify:**
- `ViewModels/SkillListViewModel.swift` — add `skillTags`, `activeTagFilters` properties, load in `init`
- `ViewModels/SkillListViewModel+Filtering.swift` — add `matchesTagFilter`
- `Views/SkillListView.swift` — add tag filter bar below source pills
- `Views/SkillRowView.swift` — show tag pills (read-only, max 3 + overflow)
- `Views/SkillDetailView.swift` — add "Tags" section for add/remove
- `Views/SettingsView.swift` — add "Clear All Tags" button

**Extension API:**
```swift
extension SkillListViewModel {
    func tags(for skill: Skill) -> [String]
    func addTag(_ tag: String, to skill: Skill)
    func removeTag(_ tag: String, from skill: Skill)
    var allTags: [String]
    func toggleTagFilter(_ tag: String)
    func clearTagFilters()
    func deleteTagGlobally(_ tag: String)
    func clearAllTags()
}
```

**Validation (from Bravo):**
- Trim whitespace, reject empty
- Max 30 chars per tag
- Max 5 tags per skill
- Deduplicate case-insensitively on write (store as-entered for display)

**Tag editing UX:** Detail panel gets a "Tags" section (text field + existing tags with × buttons). Row shows read-only pills. This avoids cluttering the row with editing UI (Alpha's recommendation).

**Tag filter bar:** Renders below source pills only when `allTags` is non-empty. Tapping toggles `activeTagFilters`. AND logic.

## Edge Cases (Union of All Plans)

| Edge Case | Handling | Source |
|-----------|----------|--------|
| Skill renamed on disk | Old records orphaned, invisible. New name starts fresh. | All |
| Two skills with same name, different sources | Share usage/tag data (keyed by name). Matches favorites pattern. | Alpha |
| Copy same skill rapidly | `@MainActor` — no race. Frequency increments each time. | Bravo |
| Corrupted JSON in store | Decode returns nil → empty defaults. No crash. | Bravo |
| UserDefaults disk full | `set` silently fails. Next launch starts fresh. | Bravo |
| Tag with special characters | JSON encoding handles escaping. No restriction beyond length. | Bravo |
| Very long tag list on row | Max 3 displayed + "+N" overflow badge. | Charlie |
| New package appears | Not in collapsed set → expanded by default. | All |
| Tag filter active, all matches deleted | `filteredSkills` empty → existing empty state view. | Bravo |
| First launch (no stored data) | All loads return nil → empty defaults. | Bravo |
| Empty/whitespace tag | Rejected by `addTag` validation. | Bravo |
| 11th recent copy | FIFO: oldest record dropped. | All |
| Search in Recent section | Boolean `matches()` filter preserves recency order. | Charlie |
| "Clear Favorites" clicked | Does NOT clear collapse state, usage data, or tags. Independent. | All |

## Error Handling Strategy (from Bravo)

All persistence loads follow fail-open pattern:
```swift
guard let data = store.data(forKey: key),
      let decoded = try? JSONDecoder().decode(T.self, from: data) else {
    return defaultValue  // empty array, empty dict, etc.
}
```

No thrown errors to callers. All persistence is fire-and-forget. Internal failures silently degrade to empty state.

## Testing Approach

All tests use Swift Testing (`@Suite`, `@Test`, `#expect`), `@MainActor`, `InMemoryKeyValueStore`.

### Test Files

| File | Tests | Est. Lines |
|------|-------|-----------|
| `CollapseStateTests.swift` | 7 tests: persist, toggle, expand-all, collapse-all, load-on-init, corrupt-data, new-package-default | ~80 |
| `AnalyticsTests.swift` | 12 tests: record-copy, FIFO, dedup, cap-at-10, frequency-increment, threshold, stale-filter, persist, load, clear, filtered-recent, filtered-frequent | ~150 |
| `SearchRankerTests.swift` | 8 tests: name-above-desc, desc-above-pkg, prefix-bonus, exact-match, additive, empty-query, no-match, matches-bool | ~100 |
| `TagTests.swift` | 12 tests: add, remove, persist, load, dedup, empty-reject, length-limit, max-per-skill, AND-filter, compose-with-search, clear-all, delete-globally | ~140 |

**Total: ~39 tests, ~470 lines**

## File Summary

### New Files (9 source + 4 test)

| File | Lines | Purpose |
|------|-------|---------|
| `Models/UsageRecord.swift` | ~15 | Codable copy event struct |
| `Utilities/SearchRanker.swift` | ~60 | `rank()`, `matches()`, `score()` |
| `ViewModels/SkillListViewModel+CollapseState.swift` | ~45 | Collapse persistence |
| `ViewModels/SkillListViewModel+Analytics.swift` | ~100 | Usage tracking |
| `ViewModels/SkillListViewModel+Tags.swift` | ~80 | Tag CRUD + filter state |
| `Views/Components/TagChipView.swift` | ~40 | Reusable tag capsule |
| `Views/Components/TagFilterBar.swift` | ~55 | Tag filter pills row |
| Tests (4 files) | ~470 | See testing section |

### Modified Files (9)

| File | Changes |
|------|---------|
| `Protocols/Dependencies.swift` | +2 methods on `KeyValueStore` |
| `Utilities/UserDefaultsStore.swift` | +2 method implementations |
| `Utilities/Constants.swift` | +6 keys and thresholds |
| `ViewModels/SkillListViewModel.swift` | +4 stored properties, +3 init loads, +1 line in `copySkill` |
| `ViewModels/SkillListViewModel+Filtering.swift` | Replace `matchesSearch` with `SearchRanker`, add `matchesTagFilter` |
| `Views/SkillListView.swift` | Remove `@State collapsedPackages`, add 2 sections, add tag filter bar |
| `Views/SkillRowView.swift` | +tag pills display (read-only) |
| `Views/SkillDetailView.swift` | +Tags editing section |
| `Views/SettingsView.swift` | +2 buttons (Reset Usage Data, Clear Tags) |
| `Tests/Mocks/InMemoryKeyValueStore.swift` | +`dataStorage` dict, +2 methods |

### Totals

- **New production code:** ~395 lines across 7 files
- **Modified production code:** ~120 lines across 9 files
- **New test code:** ~470 lines across 4 files
- **Grand total:** ~985 lines across 20 files

## Implementation Order

### Wave 1 — Foundation
1. Extend `KeyValueStore` with `data` methods
2. Implement in `UserDefaultsStore` + `InMemoryKeyValueStore`
3. Add constants

### Wave 2 — C5 (Collapse Persistence) — smallest, validates pattern
4. `+CollapseState` extension
5. Update `SkillListView`
6. `CollapseStateTests`

### Wave 3 — B1 + B2 (Usage Analytics)
7. `UsageRecord` model
8. `+Analytics` extension
9. Hook into `copySkill`
10. View sections + Settings button
11. `AnalyticsTests`

### Wave 4 — B4 (Smart Search)
12. `SearchRanker` utility
13. Update `+Filtering` to use ranker
14. `SearchRankerTests`

### Wave 5 — C1 (Tags) — largest, depends on SearchRanker for `matches()`
15. `+Tags` extension
16. `matchesTagFilter` in `+Filtering`
17. `TagChipView` + `TagFilterBar` components
18. Update `SkillRowView`, `SkillDetailView`, `SettingsView`
19. `TagTests`

## Open Questions

1. **Tags: preset suggestions or purely freeform?** Start freeform. Add autocomplete from `allTags` if needed later.
2. **Frequent threshold configurable?** Hardcode at 5. Add Settings toggle only if users request.
3. **Duplicate display across sections?** A skill in Favorites AND Recent appears in both. Matches existing pattern where favorites also appear in their package group.
4. **Tag filter persistence?** Ephemeral (resets on popover close). Avoids "hidden filter" confusion.

## Rejected Alternatives

| Rejected | From | Why | Reconsider When |
|----------|------|-----|-----------------|
| `SkillUsageTracker` service | Charlie | Extra indirection; ViewModel extensions + injected store suffice | Persistence grows to 10+ keys |
| Tab-delimited `[String]` encoding | Alpha, Charlie | Breaks on special chars in tags | Never |
| JSON inside `[String]` array | Bravo | Abuses API semantics; confusing for readers | Never |
| `SearchResult` wrapper struct | Bravo | Tuples in computed property suffice | Search results carry metadata beyond score |
| Case-normalizing tags on write | Bravo | Destroys user's casing preference | Users complain about "Swift" vs "swift" |
| Shared collapse keys for sections | Alpha | `__recent__` sentinel could collide with package names | Never |
| Tag editing on row | — | Row too tight; detail panel already exists | If detail panel is removed |
