import SwiftUI

struct TagChipView: View {
    let text: String
    var isActive: Bool = false
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 3) {
            Text(text)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .lineLimit(1)

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(chipBackground)
        .foregroundStyle(isActive ? .white : .primary)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    isActive ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08),
                    lineWidth: 0.5
                )
        )
    }

    @ViewBuilder
    private var chipBackground: some View {
        if isActive {
            Capsule().fill(Color.accentColor)
        } else {
            Capsule().fill(.ultraThinMaterial)
        }
    }
}
