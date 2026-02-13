import SwiftUI

struct SkillDetailView: View {
    let skill: Skill
    let content: String
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            detailHeader
            Divider()
            ScrollView {
                Text(content)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
            }
        }
    }

    private var detailHeader: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)

            Text(skill.slashCommand)
                .font(.headline.monospaced())
                .lineLimit(1)

            Spacer()

            Text(skill.source.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(skill.source.color.opacity(0.15))
                .foregroundStyle(skill.source.color)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
