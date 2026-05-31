import SwiftUI

/// The theme gallery: a grid of ready-made anime presets plus a "Default" tile
/// that clears the theme. Selecting a tile writes its `GradientTheme` to
/// `BrowserSettings.shared.gradientTheme`, so the chrome wash and derived accent
/// update immediately. (The earlier freeform color picker was retired in favor
/// of curated presets.)
struct ThemePicker: View {
    @ObservedObject private var settings = BrowserSettings.shared
    @Environment(\.palette) private var p

    private let columns = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    private var activePresetID: String? { settings.gradientTheme.presetID }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            DefaultTile(isSelected: settings.gradientTheme.isEmpty) {
                settings.gradientTheme = .none
            }
            ForEach(ThemePreset.all) { preset in
                PresetTile(preset: preset,
                           isSelected: activePresetID == preset.id) {
                    settings.gradientTheme = preset.theme
                }
            }
        }
        .frame(width: 320)
    }
}

// MARK: - Tiles

/// Shared tile geometry/chrome so the preset and default tiles read as one set.
private enum Tile {
    static let radius: CGFloat = 12
    static let height: CGFloat = 70

    static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    /// A faint inner bevel that separates the card from the surface on any
    /// background color (works over gradients and the neutral default alike).
    static var hairline: some View {
        shape.strokeBorder(.white.opacity(0.10), lineWidth: 1)
    }
}

/// A single preset tile: its gradient preview with the name overlaid and a ring
/// when active.
private struct PresetTile: View {
    let preset: ThemePreset
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.palette) private var p
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                GradientMesh(colors: preset.theme.dots.map(\.rgb.color))
                // A crisp bottom scrim keeps the label legible without a muddy
                // blurred text shadow.
                LinearGradient(colors: [.clear, .black.opacity(0.45)],
                               startPoint: .center, endPoint: .bottom)
                label
            }
            .frame(height: Tile.height)
            .clipShape(Tile.shape)
            .overlay(Tile.hairline)
            .shadow(color: .black.opacity(hovering ? 0.30 : 0.20),
                    radius: hovering ? 9 : 5, y: hovering ? 4 : 2)
            .overlay(SelectionRing(isSelected: isSelected, accent: p.primary.color))
            .scaleEffect(hovering ? 1.02 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.state, value: hovering)
        .animation(Motion.state, value: isSelected)
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(preset.name)
                .font(Typography.ui(Typography.label, weight: .semibold))
            Text(preset.subtitle)
                .font(Typography.ui(Typography.small))
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 1, y: 0.5)
        .padding(10)
    }
}

/// The "no theme" tile — restores the plain light/dark chrome. Styled to match
/// the preset tiles (two-line label, same chrome) with a quiet neutral wash so
/// it reads as a deliberate option rather than an empty slot.
private struct DefaultTile: View {
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.palette) private var p
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [p.card.color, p.sidebar.color],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Default")
                        .font(Typography.ui(Typography.label, weight: .semibold))
                    Text("System chrome")
                        .font(Typography.ui(Typography.small))
                        .opacity(0.7)
                }
                .foregroundStyle(p.foreground.color)
                .padding(10)
            }
            .frame(height: Tile.height)
            .clipShape(Tile.shape)
            .overlay(Tile.hairline)
            .shadow(color: .black.opacity(hovering ? 0.30 : 0.20),
                    radius: hovering ? 9 : 5, y: hovering ? 4 : 2)
            .overlay(SelectionRing(isSelected: isSelected, accent: p.primary.color))
            .scaleEffect(hovering ? 1.02 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.state, value: hovering)
        .animation(Motion.state, value: isSelected)
    }
}

/// A single accent ring drawn just outside the card so a gap of the surface
/// shows through — clean separation on any tile color, no doubled outline.
private struct SelectionRing: View {
    let isSelected: Bool
    let accent: Color

    var body: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: Tile.radius + 3, style: .continuous)
                .strokeBorder(accent, lineWidth: 2)
                .padding(-4)
                .shadow(color: accent.opacity(0.6), radius: 5)
        }
    }
}
