import SwiftUI

/// The dynamic sidebar media player. Minimal but fully functional: artwork,
/// scrubbable progress, skip ±10s, play/pause, mute, and Picture-in-Picture.
/// Appears only while a tab is playing/holding media; animates in and out.
struct MediaPlayerStrip: View {
    @ObservedObject var store: BrowserStore
    @ObservedObject var media: MediaController
    @Environment(\.palette) private var p

    @State private var scrubbing = false
    @State private var scrubValue: Double = 0

    private var s: MediaState { media.state }

    var body: some View {
        VStack(spacing: 7) {
            // Top row: artwork + title/artist + PiP.
            HStack(spacing: 9) {
                artwork
                    .onTapGesture { media.revealOwningTab(in: store) }

                VStack(alignment: .leading, spacing: 1) {
                    Text(s.title.isEmpty ? "Playing" : s.title)
                        .font(Typography.ui(Typography.label, weight: .medium))
                        .foregroundStyle(p.sidebarForeground.color)
                        .lineLimit(1)
                    Text(s.artist)
                        .font(Typography.ui(Typography.small))
                        .foregroundStyle(p.mutedForeground.color)
                        .lineLimit(1)
                }
                Spacer(minLength: 2)

                if s.canPiP || s.inPiP {
                    PlayerButton(systemName: s.inPiP ? "pip.exit" : "pip.enter",
                                 size: 13, active: s.inPiP) { media.togglePiP() }
                        .help("Picture in Picture")
                }
            }

            // Scrubber.
            scrubber

            // Transport row.
            HStack(spacing: 2) {
                PlayerButton(systemName: "gobackward.10", size: 13) { media.skipBack() }
                PlayerButton(systemName: s.playing ? "pause.fill" : "play.fill",
                             size: 15, prominent: true) { media.togglePlay() }
                PlayerButton(systemName: "goforward.10", size: 13) { media.skipForward() }
                Spacer()
                Text(timeLabel)
                    .font(Typography.mono(Typography.small))
                    .foregroundStyle(p.mutedForeground.color)
                    .monospacedDigit()
                Spacer()
                PlayerButton(systemName: s.muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                             size: 12, active: s.muted) { media.toggleMute() }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Radius.popover, style: .continuous)
                .fill(p.sidebarAccent.color.opacity(p.sidebarAccent.a == 1 ? 0.7 : 1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.popover, style: .continuous)
                .strokeBorder(p.sidebarBorder.color.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    // MARK: Pieces

    private var artwork: some View {
        Group {
            if let url = artURL {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        artFallback
                    }
                }
            } else {
                artFallback
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(p.sidebarBorder.color.opacity(0.4), lineWidth: 0.5)
        )
    }

    private var artFallback: some View {
        ZStack {
            p.muted.color
            Icon(name: s.isVideo ? "play.rectangle.fill" : "music.note", size: 17, weight: .regular)
                .foregroundStyle(p.mutedForeground.color)
        }
    }

    private var artURL: URL? {
        if !s.artwork.isEmpty { return URL(string: s.artwork) }
        if let tab = media.resolveTab?(s.browserId), let f = tab.faviconURL {
            return URL(string: f)
        }
        return nil
    }

    private var scrubber: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let frac = progressFraction
            ZStack(alignment: .leading) {
                Capsule().fill(p.foreground.color.opacity(0.12))
                    .frame(height: 3)
                Capsule().fill(p.primary.color)
                    .frame(width: max(0, min(w, w * frac)), height: 3)
                Circle().fill(p.primary.color)
                    .frame(width: scrubbing ? 11 : 8, height: scrubbing ? 11 : 8)
                    .offset(x: max(0, min(w, w * frac)) - (scrubbing ? 5.5 : 4))
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
            }
            .frame(height: 12)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        scrubbing = true
                        scrubValue = max(0, min(1, v.location.x / w)) * max(s.duration, 0)
                    }
                    .onEnded { _ in
                        if s.duration > 0 { media.seek(to: scrubValue) }
                        scrubbing = false
                    }
            )
            .animation(Motion.state, value: scrubbing)
        }
        .frame(height: 12)
    }

    private var progressFraction: Double {
        guard s.duration > 0 else { return 0 }
        let pos = scrubbing ? scrubValue : s.position
        return max(0, min(1, pos / s.duration))
    }

    private var timeLabel: String {
        let pos = scrubbing ? scrubValue : s.position
        if s.duration <= 0 { return Self.fmt(pos) }
        return "\(Self.fmt(pos)) / \(Self.fmt(s.duration))"
    }

    private static func fmt(_ t: Double) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let total = Int(t)
        let m = total / 60, sec = total % 60
        if m >= 60 {
            return String(format: "%d:%02d:%02d", m / 60, m % 60, sec)
        }
        return String(format: "%d:%02d", m, sec)
    }
}

/// A compact, token-styled transport button (no transform-on-press).
private struct PlayerButton: View {
    let systemName: String
    var size: CGFloat = 13
    var prominent: Bool = false
    var active: Bool = false
    let action: () -> Void

    @Environment(\.palette) private var p
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Icon(name: systemName, size: size * 1.25, weight: prominent ? .semibold : .medium)
                .foregroundStyle(foreground)
                .frame(width: prominent ? 32 : 26, height: prominent ? 32 : 26)
                .background(
                    Circle().fill(prominent
                                  ? p.primary.color.opacity(hovering ? 0.16 : 0.12)
                                  : (hovering ? p.foreground.color.opacity(0.07) : .clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.state, value: hovering)
    }

    private var foreground: Color {
        if prominent { return p.primary.color }
        if active { return p.primary.color }
        return p.sidebarForeground.color.opacity(0.85)
    }
}
