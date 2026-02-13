import SwiftUI

struct SkillRowView: View {
    let skill: Skill
    let isCopied: Bool
    let onTap: () -> Void
    let onDetail: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.slashCommand)
                    .font(.body.monospaced().weight(.medium))
                    .lineLimit(1)

                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

            Button(action: onDetail) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Text(skill.source.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(skill.source.color.opacity(0.15))
                .foregroundStyle(skill.source.color)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .animation(.easeInOut(duration: 0.2), value: isCopied)
    }
}
