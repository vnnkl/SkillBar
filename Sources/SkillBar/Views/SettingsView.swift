import SwiftUI

struct SettingsView: View {
    let hasFavorites: Bool
    let onClearFavorites: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader
            Divider()
            settingsContent
            Spacer()
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)

            Text("Settings")
                .font(.headline)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
            HStack {
                Toggle("Launch at Login", isOn: .constant(false))
                    .toggleStyle(.switch)
                    .disabled(true)
            }
            Text("Requires app bundling (.app). Available in a future release.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
}
