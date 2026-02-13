import SwiftUI

struct SkillListView: View {
    @Bindable var viewModel: SkillListViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            skillList
            Divider()
            footer
        }
        .frame(width: Constants.popoverWidth, height: Constants.popoverHeight)
        .onAppear {
            viewModel.scan()
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Image(systemName: "terminal")
                .font(.title3)
            Text("SkillBar")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var skillList: some View {
        Group {
            if viewModel.skills.isEmpty {
                ContentUnavailableView(
                    "No Skills Found",
                    systemImage: "doc.questionmark",
                    description: Text("Add SKILL.md files to ~/.claude/skills/")
                )
            } else {
                List {
                    ForEach(viewModel.orderedSources, id: \.self) { source in
                        if let skills = viewModel.groupedSkills[source] {
                            Section(source.displayName) {
                                ForEach(skills) { skill in
                                    SkillRowView(skill: skill)
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(viewModel.totalCount) skills")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
