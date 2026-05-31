import SwiftUI

/// A full set of Mori color tokens for one appearance, transcribed from
/// `~/Developer/mori/src/app/globals.css` (`:root` = light, `.dark` = dark).
struct ThemePalette {
    // `var` (not `let`) so a gradient theme can layer a derived accent over the
    // brand-driven tokens via `applying(theme:scheme:)`. The `static let`
    // light/dark literals below still build through the memberwise init.
    var background: TokenColor
    var foreground: TokenColor
    var card: TokenColor
    var cardForeground: TokenColor
    var popover: TokenColor
    var popoverForeground: TokenColor
    var primary: TokenColor
    var primaryForeground: TokenColor
    var secondary: TokenColor
    var secondaryForeground: TokenColor
    var muted: TokenColor
    var mutedForeground: TokenColor
    var accent: TokenColor
    var accentForeground: TokenColor
    var destructive: TokenColor
    var destructiveForeground: TokenColor
    var border: TokenColor
    var input: TokenColor
    var ring: TokenColor

    // Sidebar channel (own border/ring values, chroma-0 in dark).
    var sidebar: TokenColor
    var sidebarForeground: TokenColor
    var sidebarPrimary: TokenColor
    var sidebarPrimaryForeground: TokenColor
    var sidebarAccent: TokenColor
    var sidebarAccentForeground: TokenColor
    var sidebarBorder: TokenColor
    var sidebarRing: TokenColor

    // Status tokens (used by badges / load states).
    var statusInfoFg: TokenColor
    var statusSuccessFg: TokenColor
    var statusWarningFg: TokenColor
}

extension ThemePalette {
    private struct ForegroundSet {
        let foreground: TokenColor
        let muted: TokenColor
        let sidebar: TokenColor
    }

    private static let presetForegrounds: [String: ForegroundSet] = [
        "evangelion": ForegroundSet(
            foreground: .hex("#F4EEFF"),
            muted: .hex("#CEC4E8"),
            sidebar: .hex("#FBF7FF")
        ),
        "tokyo-ghoul": ForegroundSet(
            foreground: .hex("#FFF0F2"),
            muted: .hex("#D9AEB5"),
            sidebar: .hex("#FFF6F6")
        ),
        "demon-slayer": ForegroundSet(
            foreground: .hex("#EAF8F2"),
            muted: .hex("#BBD9D0"),
            sidebar: .hex("#F3FFF9")
        ),
        "jujutsu-kaisen": ForegroundSet(
            foreground: .hex("#EAF6FF"),
            muted: .hex("#B8CCE6"),
            sidebar: .hex("#F4FAFF")
        ),
        "chainsaw-man": ForegroundSet(
            foreground: .hex("#FFF1E8"),
            muted: .hex("#DDB8A7"),
            sidebar: .hex("#FFF7F1")
        ),
        "your-name": ForegroundSet(
            foreground: .hex("#FFF2EA"),
            muted: .hex("#DCC2D2"),
            sidebar: .hex("#FFF8EF")
        ),
        "sailor-moon": ForegroundSet(
            foreground: .hex("#232746"),
            muted: .hex("#657095"),
            sidebar: .hex("#1E2441")
        )
    ]

    /// Light theme — `:root` block.
    static let light = ThemePalette(
        background: .hex("#f7f7f7"),
        foreground: .oklch(0.165, 0.018, 248.5103),
        card: .oklch(0.985, 0.0015, 220),
        cardForeground: .oklch(0.165, 0.018, 248.5103),
        popover: .oklch(0.998, 0.0008, 240),
        popoverForeground: .oklch(0.165, 0.018, 248.5103),
        primary: .oklch(0.645, 0.11, 241.2),
        primaryForeground: .oklch(1, 0, 0),
        secondary: .oklch(0.165, 0.018, 248.5103),
        secondaryForeground: .oklch(1, 0, 0),
        muted: .oklch(0.935, 0.002, 245),
        mutedForeground: .oklch(0.48, 0.012, 248.5103),
        accent: .hex("#ededed"),
        accentForeground: .oklch(0.645, 0.11, 241.2),
        destructive: .oklch(0.635, 0.24, 28),
        destructiveForeground: .hex("#ededed"),
        border: .oklch(0.92, 0, 0),
        input: .hex("#ededed"),
        ring: .oklch(0.55, 0, 0),
        sidebar: .hex("#ebebeb"),
        sidebarForeground: .oklch(0.165, 0.018, 248.5103),
        sidebarPrimary: .oklch(0.645, 0.11, 241.2),
        sidebarPrimaryForeground: .oklch(1, 0, 0),
        sidebarAccent: .hex("#ffffff"),
        sidebarAccentForeground: .oklch(0.165, 0.018, 248.5103),
        sidebarBorder: .oklch(0.915, 0, 0),
        sidebarRing: .oklch(0.55, 0, 0),
        statusInfoFg: .oklch(0.5, 0.134, 242.749),
        statusSuccessFg: .oklch(0.527, 0.154, 150.069),
        statusWarningFg: .oklch(0.555, 0.163, 48.998)
    )

    /// Dark theme — `.dark` block. Neutral chrome is chroma-0 by rule.
    static let dark = ThemePalette(
        background: .hex("#222222"),
        foreground: .hex("#E8EAED"),
        card: .oklch(0.36, 0, 0),
        cardForeground: .hex("#E8EAED"),
        popover: .oklch(0.3, 0, 0),
        popoverForeground: .hex("#E8EAED"),
        primary: .oklch(0.62, 0.13, 241.5),
        primaryForeground: .oklch(0.28, 0.008, 235),
        secondary: .hex("#E8EAED"),
        secondaryForeground: .oklch(0.3, 0, 0),
        muted: .oklch(0.36, 0, 0),
        mutedForeground: .hex("#AEB6BF"),
        accent: .oklch(0.42, 0, 0),
        accentForeground: .oklch(0.62, 0.13, 241.5),
        destructive: .oklch(0.62, 0.22, 27),
        destructiveForeground: .oklch(1, 0, 0),
        border: .oklch(0.45, 0, 0),
        input: .oklch(0.4, 0.02, 240),
        ring: .oklch(0.6, 0, 0),
        sidebar: .hex("#151515"),
        sidebarForeground: .hex("#F1F3F5"),
        sidebarPrimary: .oklch(0.6, 0.12, 241),
        sidebarPrimaryForeground: .oklch(0.28, 0.008, 235),
        sidebarAccent: .hex("#2a2a2a"),
        sidebarAccentForeground: .oklch(0.62, 0.13, 241.5),
        sidebarBorder: .oklch(0.48, 0, 0),
        sidebarRing: .oklch(0.6, 0, 0),
        statusInfoFg: .oklch(0.746, 0.16, 232.661),
        statusSuccessFg: .oklch(0.792, 0.209, 151.711),
        statusWarningFg: .oklch(0.828, 0.189, 84.429)
    )

    static func forScheme(_ scheme: ColorScheme) -> ThemePalette {
        scheme == .dark ? .dark : .light
    }

    /// Layer a gradient theme's derived accent over a base scheme palette.
    /// Overrides only the brand-driven tokens (primary/ring/accent + their
    /// sidebar twins) and theme-aware foregrounds; surfaces stay as the proven
    /// light/dark values while the gradient supplies the colored chrome wash.
    func applying(theme: GradientTheme, scheme: ColorScheme) -> ThemePalette {
        guard !theme.isEmpty else { return self }
        let accent = GradientEngine.accentForUI(theme, scheme: scheme).token
        let onAccent = GradientEngine.contrastingText(on: RGB(accent)).token
        var p = self
        p.primary = accent
        p.primaryForeground = onAccent
        p.ring = accent
        p.accentForeground = accent
        p.sidebarPrimary = accent
        p.sidebarPrimaryForeground = onAccent
        p.sidebarRing = accent
        p.applyForegrounds(for: theme, scheme: scheme)
        return p
    }

    private mutating func applyForegrounds(for theme: GradientTheme, scheme: ColorScheme) {
        let foregrounds = theme.presetID.flatMap { Self.presetForegrounds[$0] }
            ?? Self.derivedForegrounds(for: theme, scheme: scheme)
        foreground = foregrounds.foreground
        cardForeground = foregrounds.foreground
        popoverForeground = foregrounds.foreground
        secondary = foregrounds.foreground
        mutedForeground = foregrounds.muted
        sidebarForeground = foregrounds.sidebar
    }

    private static func derivedForegrounds(for theme: GradientTheme, scheme: ColorScheme) -> ForegroundSet {
        guard !theme.dots.isEmpty else {
            return scheme == .dark
                ? ForegroundSet(foreground: .hex("#E8EAED"), muted: .hex("#AEB6BF"), sidebar: .hex("#F1F3F5"))
                : ForegroundSet(foreground: .oklch(0.165, 0.018, 248.5103),
                                muted: .oklch(0.48, 0.012, 248.5103),
                                sidebar: .oklch(0.165, 0.018, 248.5103))
        }

        let average = theme.dots.reduce(RGB(r: 0, g: 0, b: 0)) { partial, dot in
            RGB(r: partial.r + dot.rgb.r, g: partial.g + dot.rgb.g, b: partial.b + dot.rgb.b)
        }
        let count = Double(theme.dots.count)
        let base = GradientEngine.contrastingText(
            on: RGB(r: average.r / count, g: average.g / count, b: average.b / count)
        )
        if GradientEngine.isDark(base) {
            return ForegroundSet(foreground: .hex("#22263D"), muted: .hex("#626C86"), sidebar: .hex("#1F253A"))
        }
        return ForegroundSet(foreground: .hex("#F5F7FA"), muted: .hex("#C4CDD8"), sidebar: .hex("#FFFFFF"))
    }
}

/// Radius scale. Base `--radius: 0.4rem` ≈ 6.4px, expanded per `@theme inline`.
/// Buttons override to 10px squircle; dropdowns/popovers use `rounded-xl`.
enum Radius {
    static let base: CGFloat = 6.4
    static let sm: CGFloat = 2.4   // calc(radius - 4px)
    static let md: CGFloat = 4.4   // calc(radius - 2px)
    static let lg: CGFloat = 6.4   // radius
    static let xl: CGFloat = 10.4  // calc(radius + 4px)
    static let button: CGFloat = 10
    static let popover: CGFloat = 12 // tailwind rounded-xl
    static let window: CGFloat = 10  // the floating web-content card (Arc-style)
}

/// Type scale. Base interactive text is 13px; quiet labels 12px (per MASTER §2).
enum Typography {
    static let base: CGFloat = 13
    static let label: CGFloat = 12
    static let small: CGFloat = 11
    static let title: CGFloat = 13
    static let bodyTracking: CGFloat = -0.011 * 13  // tracking-[-0.011em] at 13px

    /// Söhne in the webapp; the native default falls back to the system font.
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let name = FontRegistry.soehneFamily {
            return .custom(name, size: size).weight(weight)
        }
        return .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Visual language for the sidebar tab/tile surface. A selected item is a
/// translucent white fill lifted by a soft drop shadow with no border; at rest
/// it is transparent (tiles carry a faint fill); hover is a quiet black/white
/// overlay; a press shrinks the item to 98.5%.
enum TabSurface {
    static let radius: CGFloat = 10
    static let pressScale: CGFloat = 0.985
    /// Faint resting fill for pinned/icon tiles.
    static func tileRestFill(_ s: ColorScheme) -> Color {
        s == .dark ? .white.opacity(0.06) : .black.opacity(0.05)
    }
    /// Translucent fill for the selected item.
    static func selectedFill(_ s: ColorScheme) -> Color {
        s == .dark ? .white.opacity(0.18) : .white.opacity(0.85)
    }
    /// Quiet overlay on hover.
    static func hoverFill(_ s: ColorScheme) -> Color {
        s == .dark ? .white.opacity(0.10) : .black.opacity(0.07)
    }
    /// Soft elevation shadow under the selected item.
    static func shadow(_ s: ColorScheme) -> Color {
        s == .dark ? .black.opacity(0.05) : .black.opacity(0.15)
    }
    static let shadowRadius: CGFloat = 1.5
    static let shadowY: CGFloat = 0.8
}

/// Plain button that shrinks slightly while pressed, matching the tab surface.
struct PressShrinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? TabSurface.pressScale : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

/// Motion tokens (MASTER §3): snappy easing, 150ms default state change.
enum Motion {
    /// `--ease-snappy: cubic-bezier(0.2, 0.4, 0.1, 0.95)`
    static let snappy = Animation.timingCurve(0.2, 0.4, 0.1, 0.95, duration: 0.15)
    static let state = Animation.easeInOut(duration: 0.15)
    static let reveal = Animation.easeInOut(duration: 0.25)
}

/// SwiftUI environment access to the active palette.
private struct PaletteKey: EnvironmentKey {
    static let defaultValue: ThemePalette = .light
}

extension EnvironmentValues {
    var palette: ThemePalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
