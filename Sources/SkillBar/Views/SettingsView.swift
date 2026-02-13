import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let hasFavorites: Bool
    let onClearFavorites: () -> Void
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
            launchAtLoginSection
            Divider()
            favoritesSection
        }
        .padding(12)
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
