import SwiftUI

struct SkillRowView: View {
    let skill: Skill

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

            Text(skill.source.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(skill.source.color.opacity(0.15))
                .foregroundStyle(skill.source.color)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .contentShape(Rectangle())
    }
}
