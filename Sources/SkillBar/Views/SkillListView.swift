import SwiftUI

struct SkillListView: View {
    @Bindable var viewModel: SkillListViewModel
    @FocusState private var isSearchFocused: Bool
    @State private var collapsedPackages: Set<String> = []

    private var showDetailPanel: Bool {
        viewModel.selectedSkill != nil && !viewModel.showSettings
    }

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if viewModel.showSettings {
                    SettingsView(
                        hasFavorites: viewModel.hasFavorites,
                        onClearFavorites: { viewModel.clearFavorites() },
                        onBack: { viewModel.showSettings = false }
                    )
                } else {
                    listContent
                }
            }
            .frame(width: Constants.popoverWidth)

            if showDetailPanel, let skill = viewModel.selectedSkill {
                Divider()
                SkillDetailView(
                    skill: skill,
                    content: viewModel.readCurrentDetailContent(),
                    currentFilePath: viewModel.currentDetailFilePath ?? skill.filePath,
                    breadcrumbs: viewModel.detailBreadcrumbs,
                    canNavigateBack: viewModel.canNavigateBack,
                    onNavigateToFile: { viewModel.navigateToFile($0) },
                    onNavigateBack: { viewModel.navigateBack() },
                    onBreadcrumbTap: { viewModel.navigateToBreadcrumb(at: $0) },
                    onDismiss: { viewModel.dismissDetail() }
                )
                .frame(width: Constants.detailPanelWidth)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(
            width: showDetailPanel
                ? Constants.popoverWidth + Constants.detailPanelWidth + 1
                : Constants.popoverWidth,
            height: Constants.popoverHeight
        )
        .animation(.easeInOut(duration: 0.2), value: showDetailPanel)
        .onAppear {
            viewModel.scan()
            viewModel.clearSelection()
            isSearchFocused = true
            initializeCollapseState()
        }
        .onChange(of: viewModel.filteredOrderedPackages) { _, _ in }
        .onKeyPress(.downArrow) {
            viewModel.moveDown()
            return .handled
        }
        .onKeyPress(.upArrow) {
            viewModel.moveUp()
            return .handled
        }
        .onKeyPress(.return) {
            viewModel.confirmSelection()
            return .handled
        }
        .onKeyPress(.tab) {
            if isSearchFocused {
                isSearchFocused = false
                if viewModel.selectedIndex == nil {
                    viewModel.moveDown()
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            if viewModel.selectedSkill != nil {
                viewModel.dismissDetail()
                return .handled
            }
            return .ignored
        }
    }

    private func initializeCollapseState() {
        collapsedPackages = []
    }

    private var listContent: some View {
        VStack(spacing: 0) {
            header
            searchField
            filterPills
            skillList
            footer
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary.opacity(0.8))

            Text("SkillBar")
                .font(.system(.headline, design: .monospaced, weight: .bold))

            Spacer()

            Text("\(viewModel.totalCount)")
                .font(.system(.caption2, design: .monospaced, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
                .font(.system(size: 11, weight: .medium))
            TextField("Search skills...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .default))
                .focused($isSearchFocused)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Filter Pills

    private var allPackagesCollapsed: Bool {
        let pkgs = Set(viewModel.filteredOrderedPackages)
        return !pkgs.isEmpty && pkgs.isSubset(of: collapsedPackages)
    }

    private var filterPills: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    FilterPillView(
                        title: "All",
                        count: viewModel.totalCount,
                        isSelected: viewModel.activeSourceFilter == nil,
                        color: .primary
                    ) {
                        viewModel.activeSourceFilter = nil
                    }
                    ForEach(SkillSource.allCases, id: \.self) { source in
                        FilterPillView(
                            title: source.displayName,
                            count: viewModel.groupedSkills[source]?.count ?? 0,
                            isSelected: viewModel.activeSourceFilter == source,
                            color: source.color
                        ) {
                            viewModel.activeSourceFilter = source
                        }
                    }
                }
                .padding(.leading, 12)
            }

            Button(action: {
                if allPackagesCollapsed {
                    collapsedPackages = []
                } else {
                    collapsedPackages = Set(viewModel.filteredOrderedPackages)
                }
            }) {
                Image(systemName: allPackagesCollapsed
                    ? "arrow.down.right.and.arrow.up.left"
                    : "arrow.up.left.and.arrow.down.right"
                )
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(GlassButtonStyle())
            .help(allPackagesCollapsed ? "Expand all groups" : "Collapse all groups")
            .padding(.trailing, 12)
        }
        .padding(.bottom, 6)
    }

    // MARK: - Skill List

    private var skillList: some View {
        Group {
            if viewModel.filteredSkills.isEmpty {
                emptyState
            } else {
                List {
                    if !viewModel.filteredFavoritedSkills.isEmpty {
                        Section {
                            ForEach(viewModel.filteredFavoritedSkills) { skill in
                                skillRow(skill)
                            }
                        } header: {
                            sectionHeader("Favorites", icon: "star.fill", count: viewModel.filteredFavoritedSkills.count)
                        }
                    }
                    ForEach(viewModel.filteredOrderedPackages, id: \.self) { pkg in
                        if let skills = viewModel.filteredPackageGroupedSkills[pkg] {
                            packageSection(pkg: pkg, skills: skills)
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            if viewModel.skills.isEmpty {
                Image(systemName: "doc.questionmark")
                    .font(.system(size: 28))
                    .foregroundStyle(.quaternary)
                Text("No Skills Found")
                    .font(.system(.body, design: .monospaced, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Add SKILL.md files to ~/.claude/skills/")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundStyle(.quaternary)
                Text("No Matching Skills")
                    .font(.system(.body, design: .monospaced, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Try a different search or filter")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Package Section

    private func packageSection(pkg: String, skills: [Skill]) -> some View {
        let isExpanded = !collapsedPackages.contains(pkg)
        return DisclosureGroup(
            isExpanded: Binding(
                get: { isExpanded },
                set: { expanded in
                    if expanded {
                        collapsedPackages.remove(pkg)
                    } else {
                        collapsedPackages.insert(pkg)
                    }
                }
            )
        ) {
            ForEach(skills) { skill in
                skillRow(skill)
            }
        } label: {
            sectionHeader(pkg, count: skills.count)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isExpanded {
                        collapsedPackages.insert(pkg)
                    } else {
                        collapsedPackages.remove(pkg)
                    }
                }
        }
    }

    private func sectionHeader(_ title: String, icon: String? = nil, count: Int) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(.secondary)

            Text("\(count)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }

    // MARK: - Skill Row

    private func skillRow(_ skill: Skill) -> some View {
        let isSelected = isSkillSelected(skill)
        let isDetailTarget = viewModel.selectedSkill?.id == skill.id
        return SkillRowView(
            skill: skill,
            isCopied: viewModel.recentlyCopiedSkillId == skill.id,
            isFavorite: viewModel.isFavorite(skill),
            isDetailSelected: isDetailTarget,
            onTap: { viewModel.selectSkillForDetail(skill) },
            onCopy: { viewModel.copySkill(skill) },
            onToggleFavorite: { viewModel.toggleFavorite(skill) }
        )
        .listRowBackground(
            isSelected
                ? RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: Constants.cornerRadius)
                            .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 0.5)
                    )
                : nil
        )
    }

    private func isSkillSelected(_ skill: Skill) -> Bool {
        guard let index = viewModel.selectedIndex else { return false }
        let list = viewModel.filteredSkills
        return index < list.count && list[index].id == skill.id
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Group {
                if viewModel.filteredCount < viewModel.totalCount {
                    Text("\(viewModel.filteredCount) of \(viewModel.totalCount)")
                } else {
                    Text("\(viewModel.totalCount) skills")
                }
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.tertiary)

            Spacer()

            Button(action: { viewModel.showSettings = true }) {
                Image(systemName: "gear")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: Constants.buttonMinSize, height: Constants.buttonMinSize)
            }
            .buttonStyle(GlassButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Filter Pill

private struct FilterPillView: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                if isSelected {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(color.opacity(0.6))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(pillBackground)
            .foregroundStyle(isSelected ? color : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? color.opacity(0.25) : Color.primary.opacity(isHovered ? 0.08 : 0.05),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private var pillBackground: some View {
        if isSelected {
            Capsule().fill(color.opacity(0.12))
        } else if isHovered {
            Capsule().fill(.ultraThinMaterial)
        } else {
            Capsule().fill(.clear)
        }
    }
}
