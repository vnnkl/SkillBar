import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let hasFavorites: Bool
    let hasUsageData: Bool
    let hasAnyTags: Bool
    let launchMode: LaunchMode
    let onSetLaunchMode: (LaunchMode) -> Void
    let onClearFavorites: () -> Void
    let onClearUsageData: () -> Void
    let onClearAllTags: () -> Void
    let onBack: () -> Void

    @State private var launchAtLogin = false
    @State private var launchAtLoginError: String?

    private var isAppBundle: Bool {
        Bundle.main.bundlePath.hasSuffix(".app")
    }

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader
            Divider()
            settingsContent
            Spacer()
        }
        .onAppear {
            if isAppBundle {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .frame(width: Constants.buttonMinSize, height: Constants.buttonMinSize)
            }
            .buttonStyle(GlassButtonStyle())

            Text("Settings")
                .font(.headline)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            launchModeSection
            Divider()
            launchAtLoginSection
            Divider()
            favoritesSection
            Divider()
            tagsSection
            Divider()
            usageDataSection
        }
        .padding(12)
    }

    private var launchModeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Skill Action")
                .font(.system(.body, weight: .medium))

            Picker("", selection: Binding(
                get: { launchMode },
                set: { onSetLaunchMode($0) }
            )) {
                ForEach(LaunchMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            Text(launchModeHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var launchModeHelpText: String {
        switch launchMode {
        case .copyOnly:
            "Copy the /command to clipboard. You paste it manually."
        case .paste:
            "Paste the /command into the last active terminal. Works with iTerm2. Terminal.app and Warp fall back to copy + activate."
        case .pasteAndExecute:
            "Paste and run the /command in the last active terminal. Works with iTerm2 and Terminal.app. Use with caution."
        }
    }

    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isAppBundle {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { toggleLaunchAtLogin($0) }
                ))
                .toggleStyle(.switch)

                if let error = launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("Automatically start SkillBar when you log in.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Toggle("Launch at Login", isOn: .constant(false))
                    .toggleStyle(.switch)
                    .disabled(true)
                Text("Requires app bundle (.app). Build with Scripts/package_app.sh")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onClearFavorites) {
                HStack(spacing: 4) {
                    Image(systemName: "star.slash")
                        .font(.caption)
                    Text("Clear Favorites")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(hasFavorites ? .red : .secondary)
            .disabled(!hasFavorites)

            Text("Remove all pinned skills from the favorites section.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onClearAllTags) {
                HStack(spacing: 4) {
                    Image(systemName: "tag.slash")
                        .font(.caption)
                    Text("Clear All Tags")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(hasAnyTags ? .red : .secondary)
            .disabled(!hasAnyTags)

            Text("Remove all tags from all skills.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var usageDataSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onClearUsageData) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.caption)
                    Text("Reset Usage Data")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(hasUsageData ? .red : .secondary)
            .disabled(!hasUsageData)

            Text("Clear recently and frequently used skill tracking data.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            launchAtLoginError = "Failed to \(enabled ? "enable" : "disable"): \(error.localizedDescription)"
        }
    }
}
