@preconcurrency import MarkdownUI
import SwiftUI

struct SkillDetailView: View {
    let skill: Skill
    let content: String
    let currentFilePath: String
    let breadcrumbs: [String]
    let canNavigateBack: Bool
    let onNavigateToFile: (String) -> Void
    let onNavigateBack: () -> Void
    let onBreadcrumbTap: (Int) -> Void
    let onDismiss: () -> Void

    @State private var collapsedSections: Set<Int> = []
    @State private var lastFilePath: String = ""

    private var strippedContent: String {
        MarkdownStripper.stripFrontmatter(content)
    }

    private var sections: [MarkdownSection] {
        MarkdownSectionParser.parse(strippedContent)
    }

    private var fileBaseURL: URL {
        URL(fileURLWithPath: currentFilePath).deletingLastPathComponent()
    }

    private var collapsibleSectionIds: [Int] {
        sections.flatMap { section -> [Int] in
            if section.level == 2 {
                return [section.id] + section.children.map(\.id)
            }
            return section.level == 3 ? [section.id] : []
        }
    }

    private var allCollapsed: Bool {
        let ids = Set(collapsibleSectionIds)
        return !ids.isEmpty && ids.isSubset(of: collapsedSections)
    }

    var body: some View {
        VStack(spacing: 0) {
            detailHeader
            if breadcrumbs.count > 1 {
                breadcrumbBar
            }
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sections) { section in
                        sectionView(section)
                    }
                }
                .padding(12)
                .textSelection(.enabled)
            }
        }
        .onChange(of: currentFilePath) { _, newPath in
            if newPath != lastFilePath {
                collapsedSections = []
                lastFilePath = newPath
            }
        }
        .onAppear {
            lastFilePath = currentFilePath
        }
    }

    // MARK: - Header

    private var detailHeader: some View {
        HStack(spacing: 8) {
            if canNavigateBack {
                Button(action: onNavigateBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(
                            width: Constants.buttonMinSize,
                            height: Constants.buttonMinSize
                        )
                }
                .buttonStyle(GlassButtonStyle())
            }

            Text(skill.slashCommand)
                .font(.headline.monospaced())
                .lineLimit(1)

            Spacer()

            toggleCollapseButton

            Text(skill.source.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .foregroundStyle(skill.source.color)
                .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(
                        width: Constants.buttonMinSize,
                        height: Constants.buttonMinSize
                    )
            }
            .buttonStyle(GlassButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var toggleCollapseButton: some View {
        let ids = collapsibleSectionIds
        if !ids.isEmpty {
            Button(action: {
                if allCollapsed {
                    collapsedSections = []
                } else {
                    collapsedSections = Set(ids)
                }
            }) {
                Image(systemName: allCollapsed
                    ? "arrow.down.right.and.arrow.up.left"
                    : "arrow.up.left.and.arrow.down.right"
                )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(
                        width: Constants.buttonMinSize,
                        height: Constants.buttonMinSize
                    )
            }
            .buttonStyle(GlassButtonStyle())
            .help(allCollapsed ? "Expand all sections" : "Collapse all sections")
        }
    }

    // MARK: - Breadcrumbs

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.quaternary)
                    }
                    let isLast = index == breadcrumbs.count - 1
                    Button(action: { onBreadcrumbTap(index) }) {
                        Text(crumb)
                            .font(.system(size: 10, weight: isLast ? .semibold : .regular, design: .monospaced))
                            .foregroundStyle(isLast ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLast)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.ultraThinMaterial.opacity(0.5))
    }

    // MARK: - Section Rendering

    @ViewBuilder
    private func sectionView(_ section: MarkdownSection) -> some View {
        if section.level == 0 {
            if !section.content.isEmpty {
                markdownBlock(section.content)
            }
        } else if section.level == 2 {
            disclosureSection(section)
        } else if !section.content.isEmpty {
            // Orphan h3 (not nested under h2) — render with heading
            markdownBlock("### \(section.heading)\n\n\(section.content)")
        }
    }

    private func disclosureSection(_ section: MarkdownSection) -> some View {
        let isExpanded = !collapsedSections.contains(section.id)
        return VStack(alignment: .leading, spacing: 0) {
            collapsibleHeader(
                title: section.heading,
                isExpanded: isExpanded,
                font: .system(size: 13, weight: .semibold),
                foreground: .primary
            ) {
                toggleParentSection(section)
            }
            .padding(.top, 8)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    if !section.content.isEmpty {
                        markdownBlock(section.content)
                    }
                    ForEach(section.children) { child in
                        childDisclosure(child)
                    }
                }
            }
        }
    }

    private func childDisclosure(_ section: MarkdownSection) -> some View {
        let isExpanded = !collapsedSections.contains(section.id)
        return VStack(alignment: .leading, spacing: 0) {
            collapsibleHeader(
                title: section.heading,
                isExpanded: isExpanded,
                font: .system(size: 12, weight: .medium),
                foreground: .primary.opacity(0.85)
            ) {
                toggleSection(section.id)
            }
            .padding(.leading, 8)
            .padding(.top, 4)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    if !section.content.isEmpty {
                        markdownBlock(section.content)
                            .padding(.leading, 8)
                    }
                }
            }
        }
    }

    private func collapsibleHeader(
        title: String,
        isExpanded: Bool,
        font: Font,
        foreground: some ShapeStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.15), value: isExpanded)
                Text(title)
                    .font(font)
                    .foregroundStyle(foreground)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleSection(_ id: Int) {
        if collapsedSections.contains(id) {
            collapsedSections.remove(id)
        } else {
            collapsedSections.insert(id)
        }
    }

    private func toggleParentSection(_ section: MarkdownSection) {
        let isCollapsed = collapsedSections.contains(section.id)
        if isCollapsed {
            // Expanding: also expand all children
            collapsedSections.remove(section.id)
            for child in section.children {
                collapsedSections.remove(child.id)
            }
        } else {
            collapsedSections.insert(section.id)
        }
    }

    // MARK: - Markdown Rendering

    private func markdownBlock(_ text: String) -> some View {
        Markdown(text, baseURL: fileBaseURL)
            .markdownTheme(markdownTheme)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.openURL, OpenURLAction { url in
                if url.isFileURL, url.pathExtension == "md" {
                    onNavigateToFile(url.path)
                    return .handled
                }
                return .systemAction
            })
    }

    private var markdownTheme: MarkdownUI.Theme {
        Theme()
            .text {
                FontSize(.em(0.85))
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.8))
            }
            .codeBlock { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.8))
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .heading1 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(.em(1.3))
                    }
                    .markdownMargin(top: 16, bottom: 8)
            }
            .heading2 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.15))
                    }
                    .markdownMargin(top: 12, bottom: 6)
            }
            .heading3 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.05))
                    }
                    .markdownMargin(top: 10, bottom: 4)
            }
            .link {
                ForegroundColor(.accentColor)
            }
    }
}
