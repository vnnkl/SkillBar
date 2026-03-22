# Plan: Workflow Memory (Synthesized)

*Synthesized from 3 competing plans (Alpha/Pragmatist, Bravo/Defender, Charlie/Architect)*

## Problem Statement

Developers follow repeating skill sequences but SkillBar is blind to them. Workflow Memory learns transitions (A→B counts), persists them, and surfaces "Next Up" suggestions.

## Goals

- Track skill transitions and persist across sessions
- Surface "Next Up" section (max 2, threshold 3+) at top of popover
- Zero configuration — emerges from behavior

## Non-Goals

- Automated chaining, time-decay, workflow editor UI, configurable threshold

## Source Attribution

- **Architecture:** Charlie's separate `+WorkflowMemory` extension (one concern per extension)
- **Data model:** Alpha's raw `[String: [String: Int]]` (no wrapper struct)
- **Error handling:** Bravo's comprehensive failure matrix
- **Testing:** Bravo's 20-test coverage with Charlie's separate test file
- **Filter strategy:** Charlie's "fetch extras, filter, then limit"

## Data Model

### Transition Matrix

```
[String: [String: Int]]
```

`matrix[fromSkillName][toSkillName] = count`. JSON-encoded via `store.data(forKey:)`.

### Last Launched Skill

```
lastLaunchedSkillName: String?
```

Stored property on ViewModel, loaded in `init`, persisted as `[String]` via `store.array(forKey:)`. Matches `launchMode` encoding pattern.

### Constants

```swift
static let transitionMatrixKey = "skillTransitionMatrix"
static let lastLaunchedSkillKey = "lastLaunchedSkillName"
static let transitionThreshold = 3
static let nextUpLimit = 2
```

### State Management

| State | Location | Persisted |
|-------|----------|-----------|
| Transition matrix | `KeyValueStore` (JSON Data) | Yes |
| `lastLaunchedSkillName` | ViewModel property + `KeyValueStore` ([String]) | Yes |

## Data Flow

```
copySkill(B) → recordUsage(B)
  → existing UsageRecord logic...
  → if lastLaunchedSkillName != nil && != B.name:
      recordTransition(from: lastLaunchedSkillName, to: B.name)
  → lastLaunchedSkillName = B.name
  → persist lastLaunchedSkillName to store

Next popover open:
  → suggestedNextSkills computed property:
    → load matrix from store
    → lookup matrix[lastLaunchedSkillName]
    → filter to count >= 3
    → sort by count desc, take top 4 (headroom for filtering)
    → resolve names against skills array
    → apply source/tag/search filters
    → take first 2
    → return [Skill]
```

## New Files

### `Sources/SkillBar/ViewModels/SkillListViewModel+WorkflowMemory.swift` (~60 lines)

```swift
extension SkillListViewModel {

    // MARK: - Record Transition

    func recordTransition(from source: String, to target: String) {
        guard source != target else { return }
        var matrix = loadTransitionMatrix()
        var targets = matrix[source] ?? [:]
        targets[target] = (targets[target] ?? 0) + 1
        matrix[source] = targets
        saveTransitionMatrix(matrix)
    }

    // MARK: - Suggestions

    var suggestedNextSkills: [Skill] {
        guard let last = lastLaunchedSkillName else { return [] }
        let matrix = loadTransitionMatrix()
        guard let transitions = matrix[last] else { return [] }
        let skillsByName = Dictionary(uniqueKeysWithValues: skills.map { ($0.name, $0) })
        return transitions
            .filter { $0.value >= Constants.transitionThreshold }
            .sorted { $0.value > $1.value }
            .prefix(Constants.nextUpLimit + 2)
            .compactMap { skillsByName[$0.key] }
            .filter { matchesSourceFilter($0) && matchesTagFilter($0) }
            .filter { searchText.isEmpty || SearchRanker.matches($0, query: searchText) }
            .prefix(Constants.nextUpLimit)
            .map { $0 }
    }

    var filteredSuggestedNextSkills: [Skill] {
        suggestedNextSkills  // filtering already applied in suggestedNextSkills
    }

    // MARK: - Clear

    func clearWorkflowMemory() {
        store.removeObject(forKey: Constants.transitionMatrixKey)
        store.removeObject(forKey: Constants.lastLaunchedSkillKey)
        lastLaunchedSkillName = nil
    }

    // MARK: - Private

    private func loadTransitionMatrix() -> [String: [String: Int]] {
        guard let data = store.data(forKey: Constants.transitionMatrixKey) else { return [:] }
        return (try? JSONDecoder().decode([String: [String: Int]].self, from: data)) ?? [:]
    }

    private func saveTransitionMatrix(_ matrix: [String: [String: Int]]) {
        guard let data = try? JSONEncoder().encode(matrix) else { return }
        store.set(data, forKey: Constants.transitionMatrixKey)
    }
}
```

### `Tests/SkillBarTests/WorkflowMemoryTests.swift` (~180 lines)

## Modified Files

### `Sources/SkillBar/ViewModels/SkillListViewModel.swift`

Add stored property:
```swift
var lastLaunchedSkillName: String?
```

Load in `init`:
```swift
if let stored = store.array(forKey: Constants.lastLaunchedSkillKey)?.first {
    self.lastLaunchedSkillName = stored
}
```

### `Sources/SkillBar/ViewModels/SkillListViewModel+Analytics.swift`

Add to end of `recordUsage(_:)`:
```swift
if let previous = lastLaunchedSkillName, previous != skill.name {
    recordTransition(from: previous, to: skill.name)
}
lastLaunchedSkillName = skill.name
store.set([skill.name], forKey: Constants.lastLaunchedSkillKey)
```

Update `clearUsageData()`:
```swift
func clearUsageData() {
    store.removeObject(forKey: Constants.usageRecordsKey)
    clearWorkflowMemory()
}
```

Update `hasUsageData`:
```swift
var hasUsageData: Bool {
    !loadUsageRecords().isEmpty
    || store.data(forKey: Constants.transitionMatrixKey) != nil
}
```

### `Sources/SkillBar/Utilities/Constants.swift`

Add 4 constants (listed above).

### `Sources/SkillBar/Views/SkillListView.swift`

Add "Next Up" section as FIRST section in List (before Favorites):
```swift
if !viewModel.suggestedNextSkills.isEmpty {
    Section {
        ForEach(viewModel.suggestedNextSkills) { skill in
            skillRow(skill)
        }
    } header: {
        sectionHeader("Next Up", icon: "arrow.right.circle.fill", count: viewModel.suggestedNextSkills.count)
    }
}
```

Update `hasAnyVisibleContent`:
```swift
|| !viewModel.suggestedNextSkills.isEmpty
```

### `Sources/SkillBar/Views/SettingsView.swift`

Update help text:
```swift
"Clear recently used, frequently used, and workflow suggestion data."
```

## Edge Cases (Union of All Plans)

| Edge Case | Handling | Source |
|-----------|----------|--------|
| First-ever copy (no lastLaunched) | `lastLaunchedSkillName` nil, no transition, skill name saved | All |
| Self-transition (A→A) | Guard `source != target` in `recordTransition` | All |
| Stale skill in matrix | `compactMap` with `skillsByName` excludes deleted skills | All |
| Corrupt matrix JSON | `?? [:]` on decode failure, no crash | Bravo |
| Corrupt lastLaunched array | `?.first` returns nil, no suggestions | Bravo |
| All suggestions filtered out by search/source/tag | Returns `[]`, section hidden | All |
| App quit between A and B copy | `lastLaunchedSkillName` persisted on A copy; B copy next session creates transition | Bravo |
| Clear data then immediately copy | `lastLaunchedSkillName` is nil, first copy sets it, no transition recorded | Bravo |
| Rapid-fire copies (A, B, C quickly) | `@MainActor` serializes. A→B, B→C recorded correctly | Bravo |
| Skill name with special characters | JSON encoding handles arbitrary strings | Bravo |
| Large matrix (200 skills × 200 targets) | ~1.2MB worst case, well within UserDefaults limits | Bravo |
| Encode failure on save | `try?` swallows, data stays stale | All |

## Error Handling

Every persistence operation follows fail-open:
- Decode failure → empty defaults (no crash)
- Encode failure → silently skip (clipboard still works)
- Missing key → nil/empty (no suggestions shown)
- Stale names → filtered out via `compactMap`

## Testing

### Test Cases (~18 tests)

**Transition Recording:**
1. First copy sets `lastLaunchedSkillName`, no transition recorded
2. A then B records `matrix["A"]["B"] == 1`
3. A then B repeated 5 times yields count 5
4. Self-transition (A then A) not recorded
5. A→B then B→A records both directions independently
6. Transition persists to store (verify via `store.data`)

**Suggestions:**
7. `suggestedNextSkills` empty when `lastLaunchedSkillName` is nil
8. Empty when no transitions exist for last skill
9. Empty when all transitions below threshold (count < 3)
10. Returns skill when count >= 3
11. Returns max 2 skills sorted by count descending
12. Stale skills excluded from suggestions
13. Respects search filter
14. Respects source filter
15. Respects tag filter

**Persistence:**
16. `lastLaunchedSkillName` survives VM re-creation with same store
17. Transition matrix survives VM re-creation

**Clear:**
18. `clearUsageData` removes matrix, lastLaunched, and usage records

**Corrupt Data:**
19. Corrupt matrix JSON → returns empty, no crash

## File Summary

| File | Action | Lines |
|------|--------|-------|
| `ViewModels/SkillListViewModel+WorkflowMemory.swift` | **Create** | ~60 |
| `Tests/WorkflowMemoryTests.swift` | **Create** | ~180 |
| `ViewModels/SkillListViewModel.swift` | Modify | +4 |
| `ViewModels/SkillListViewModel+Analytics.swift` | Modify | +8 |
| `Utilities/Constants.swift` | Modify | +5 |
| `Views/SkillListView.swift` | Modify | +12 |
| `Views/SettingsView.swift` | Modify | +1 |
| **Total** | | **~270** |

## Rejected Alternatives

| Rejected | From | Why | Reconsider When |
|----------|------|-----|-----------------|
| `TransitionMatrix` / `TransitionEntry` structs | Charlie | Wrapping `Int` in a struct for speculative future fields. YAGNI. | Adding time-decay or weights |
| Matrix row cap at 200 | Bravo | Users have <200 skills, worst-case ~1MB. Unnecessary complexity. | 1000+ skills becomes realistic |
| All logic in `+Analytics.swift` | Alpha | Would grow to ~170 lines, mixing concerns. Separate extension is cleaner. | Never — follows established pattern |
| Reading `lastLaunchedSkillName` from store on every access | Alpha | Unnecessary I/O on each computed property evaluation. Load once in init. | Never |

## Open Questions

None.
