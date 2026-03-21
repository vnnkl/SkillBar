import SwiftUI

struct SkillRowView: View {
    let skill: Skill
    let isCopied: Bool
    let isFavorite: Bool
    let isDetailSelected: Bool
    var tags: [String] = []
    let onTap: () -> Void
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
                    .frame(width: Constants.buttonMinSize, height: Constants.buttonMinSize)
            }
            .buttonStyle(GlassButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(skill.displayName)
                    .font(.system(.body, design: .monospaced, weight: .medium))
                    .lineLimit(1)

                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !tags.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(tags.prefix(3), id: \.self) { tag in
                            TagChipView(text: tag)
                        }
                        if tags.count > 3 {
                            Text("+\(tags.count - 3)")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .lineLimit(1)
                }
            }

            Spacer()

            if isCopied {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                    .transition(.scale.combined(with: .opacity))
            }

            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: Constants.buttonMinSize, height: Constants.buttonMinSize)
            }
            .buttonStyle(GlassButtonStyle())

            Text(skill.source.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .foregroundStyle(skill.source.color)
                .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.cornerRadius)
                        .strokeBorder(skill.source.color.opacity(0.2), lineWidth: 0.5)
                )
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .fill(rowBackground)
                .padding(.horizontal, -4)
                .padding(.vertical, -2)
        )
        .animation(.easeInOut(duration: 0.2), value: isCopied)
        .animation(.easeInOut(duration: 0.2), value: isFavorite)
    }

    private var rowBackground: AnyShapeStyle {
        if isDetailSelected {
            return AnyShapeStyle(Color.accentColor.opacity(0.12))
        }
        if isHovered {
            return AnyShapeStyle(.ultraThinMaterial)
        }
        return AnyShapeStyle(.clear)
    }
}
