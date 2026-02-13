import SwiftUI

struct SkillListView: View {
    @Bindable var viewModel: SkillListViewModel

    var body: some View {
        Group {
            if let skill = viewModel.selectedSkill {
                SkillDetailView(
                    skill: skill,
                    content: viewModel.readSkillContent(skill),
                    onBack: { viewModel.dismissDetail() }
                )
            } else {
                listContent
            }
        }
        .frame(width: Constants.popoverWidth, height: Constants.popoverHeight)
        .onAppear {
            viewModel.scan()
        }
    }

    private var listContent: some View {
        VStack(spacing: 0) {
            header
            searchField
            filterPills
            Divider()
            skillList
            Divider()
            footer
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

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("Search skills...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.body)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterPillView(
                    title: "All",
                    isSelected: viewModel.activeSourceFilter == nil,
                    color: .primary
                ) {
                    viewModel.activeSourceFilter = nil
                }
                ForEach(SkillSource.allCases, id: \.self) { source in
                    FilterPillView(
                        title: source.displayName,
                        isSelected: viewModel.activeSourceFilter == source,
                        color: source.color
                    ) {
                        viewModel.activeSourceFilter = source
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    private var skillList: some View {
        Group {
            if viewModel.filteredSkills.isEmpty {
                if viewModel.skills.isEmpty {
                    ContentUnavailableView(
                        "No Skills Found",
                        systemImage: "doc.questionmark",
                        description: Text("Add SKILL.md files to ~/.claude/skills/")
                    )
                } else {
                    ContentUnavailableView(
                        "No Matching Skills",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search or filter")
                    )
                }
            } else {
                List {
                    ForEach(viewModel.filteredOrderedSources, id: \.self) { source in
                        if let skills = viewModel.filteredGroupedSkills[source] {
                            Section(source.displayName) {
                                ForEach(skills) { skill in
                                    SkillRowView(
                                        skill: skill,
                                        isCopied: viewModel.recentlyCopiedSkillId == skill.id,
                                        onTap: { viewModel.copySkill(skill) },
                                        onDetail: { viewModel.selectSkillForDetail(skill) }
                                    )
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
            if viewModel.filteredCount < viewModel.totalCount {
                Text("\(viewModel.filteredCount) of \(viewModel.totalCount) skills")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(viewModel.totalCount) skills")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Filter Pill

private struct FilterPillView: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? color.opacity(0.15) : Color.clear)
                .foregroundStyle(isSelected ? color : .secondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? color.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
