import SwiftUI

struct TagFilterBar: View {
    let tags: [String]
    let activeFilters: Set<String>
    let onToggle: (String) -> Void
    let onClearAll: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(tags, id: \.self) { tag in
                    Button(action: { onToggle(tag) }) {
                        TagChipView(
                            text: tag,
                            isActive: activeFilters.contains(tag)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if !activeFilters.isEmpty {
                    Button(action: onClearAll) {
                        Text("Clear")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.bottom, 4)
    }
}
