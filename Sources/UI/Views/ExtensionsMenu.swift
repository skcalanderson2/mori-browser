import SwiftUI
import AppKit

/// The cluster shown at the trailing edge of the omnibox: any pinned extensions
/// as their own icons, followed by the puzzle-piece button that opens the full
/// extensions menu. Hidden entirely when no extensions are installed.
struct ExtensionToolbarItems: View {
    @ObservedObject var store: BrowserStore
    @ObservedObject private var extensions = ExtensionStore.shared
    @State private var showMenu = false
    @State private var activePopupExtensionID: BrowserExtension.ID?
    @State private var browserPopupExtensionID: BrowserExtension.ID?
    @Environment(\.palette) private var p

    private var browserPopupExtension: BrowserExtension? {
        guard let browserPopupExtensionID else { return nil }
        return extensions.extensions.first {
            $0.id == browserPopupExtensionID && extensions.popupURL(for: $0) != nil
        }
    }

    var body: some View {
        if !extensions.extensions.isEmpty {
            HStack(spacing: 2) {
                ForEach(extensions.pinnedExtensions) { ext in
                    let popupURL = extensions.popupURL(for: ext)
                    let actionState = extensions.actionState(for: ext.id)
                    ExtensionIconButton(
                        ext: ext,
                        actionState: actionState,
                        isActive: activePopupExtensionID == ext.id,
                        isEnabled: ext.enabled
                    ) {
                        showMenu = false
                        if popupURL != nil {
                            activePopupExtensionID =
                                activePopupExtensionID == ext.id ? nil : ext.id
                        } else {
                            activePopupExtensionID = nil
                            store.activateExtensionAction(extensionID: ext.id)
                        }
                    }
                    .popover(
                        isPresented: Binding(
                            get: { activePopupExtensionID == ext.id },
                            set: { presented in
                                if !presented, activePopupExtensionID == ext.id {
                                    activePopupExtensionID = nil
                                }
                            }),
                        arrowEdge: .bottom
                    ) {
                        if let url = extensions.popupURL(for: ext) {
                            ExtensionActionPopup(
                                url: url,
                                size: extensions.popupSize(for: ext)
                            )
                        }
                    }
                }

                Button {
                    activePopupExtensionID = nil
                    showMenu.toggle()
                } label: {
                    Icon(name: "puzzlepiece.extension", size: 15)
                        .foregroundStyle(showMenu ? p.foreground.color : p.mutedForeground.color)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(showMenu ? p.accent.color.opacity(0.6) : .clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Extensions")
                .popover(isPresented: $showMenu, arrowEdge: .bottom) {
                    ExtensionsMenu(store: store) { showMenu = false }
                }
            }
            .popover(
                isPresented: Binding(
                    get: { browserPopupExtension != nil },
                    set: { presented in
                        if !presented {
                            browserPopupExtensionID = nil
                        }
                    }),
                arrowEdge: .bottom
            ) {
                if let ext = browserPopupExtension,
                   let url = extensions.popupURL(for: ext) {
                    ExtensionActionPopup(
                        url: url,
                        size: extensions.popupSize(for: ext)
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .moriOpenExtensionPopup)) { note in
                guard let extensionID = note.userInfo?["extensionId"] as? String,
                      extensions.popupURL(forExtensionID: extensionID) != nil
                else { return }
                let reason = note.userInfo?["reason"] as? String ?? "unknown"
                showMenu = false
                activePopupExtensionID = nil
                browserPopupExtensionID = extensionID
                NSLog("__MORI_EXTENSION_POPUP_OPENED__ %@ %@", extensionID, reason)
            }
        }
    }
}

/// A single pinned extension's icon button in the omnibox.
private struct ExtensionIconButton: View {
    let ext: BrowserExtension
    let actionState: ExtensionStore.ActionState
    let isActive: Bool
    let isEnabled: Bool
    let action: () -> Void
    @Environment(\.palette) private var p
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            ExtensionIconView(ext: ext, size: 16)
                .frame(width: 22, height: 22)
                .overlay(alignment: .topTrailing) {
                    if !actionState.badgeText.isEmpty {
                        Text(String(actionState.badgeText.prefix(4)))
                            .font(Typography.ui(7, weight: .bold))
                            .foregroundStyle(actionState.badgeTextColor.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 3)
                            .frame(minWidth: 11, minHeight: 10)
                            .background(
                                Capsule()
                                    .fill(actionState.badgeBackgroundColor.color)
                            )
                            .offset(x: 5, y: -3)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill((hover || isActive) ? p.accent.color.opacity(0.6) : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .onHover { hover = $0 }
        .help(actionState.title ?? ext.name)
    }
}

private extension Array where Element == Int {
    var color: Color {
        let r = Double(indices.contains(0) ? self[0] : 217) / 255.0
        let g = Double(indices.contains(1) ? self[1] : 48) / 255.0
        let b = Double(indices.contains(2) ? self[2] : 37) / 255.0
        let a = Double(indices.contains(3) ? self[3] : 255) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

private struct ExtensionActionPopup: View {
    let url: String
    let size: CGSize

    var body: some View {
        ExtensionPopupBrowser(url: url)
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct ExtensionPopupBrowser: NSViewRepresentable {
    let url: String

    func makeNSView(context: Context) -> MoriBrowserView {
        let view = MoriBrowserView(url: url)
        view.setIgnoresGlobalWebContentSuppression(true)
        view.setWebWindowVisible(true)
        return view
    }

    func updateNSView(_ view: MoriBrowserView, context: Context) {
        view.setIgnoresGlobalWebContentSuppression(true)
        if view.currentURL != url {
            view.loadURL(url)
        }
        view.setWebWindowVisible(true)
    }

    static func dismantleNSView(_ view: MoriBrowserView, coordinator: ()) {
        view.closeBrowser()
    }
}

/// Reusable square icon for an extension: its declared icon, or a puzzle-piece
/// placeholder. Dimmed when the extension is disabled.
struct ExtensionIconView: View {
    let ext: BrowserExtension
    var size: CGFloat = 28
    @Environment(\.palette) private var p

    var body: some View {
        Group {
            if let path = ext.iconPath, let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .fill(p.input.color.opacity(0.6))
                    .frame(width: size, height: size)
                    .overlay(
                        Icon(name: "puzzlepiece.extension", size: size * 0.6, weight: .regular)
                            .foregroundStyle(p.mutedForeground.color)
                    )
            }
        }
        .opacity(ext.enabled ? 1 : 0.4)
    }
}

/// The popover listing every installed extension, with a pin toggle on each and
/// a shortcut to the full management surface in Settings.
struct ExtensionsMenu: View {
    @ObservedObject var store: BrowserStore
    let dismiss: () -> Void

    @ObservedObject private var extensions = ExtensionStore.shared
    @Environment(\.palette) private var p
    @State private var activePopupExtensionID: BrowserExtension.ID?

    private var activePopupExtension: BrowserExtension? {
        guard let activePopupExtensionID else { return nil }
        return extensions.extensions.first {
            $0.id == activePopupExtensionID && $0.enabled
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let ext = activePopupExtension,
               let popupURL = extensions.popupURL(for: ext) {
                HStack(spacing: 8) {
                    Button {
                        activePopupExtensionID = nil
                    } label: {
                        Icon(name: "chevron.left", size: 13, weight: .medium)
                            .foregroundStyle(p.foreground.color)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Back to extensions")

                    ExtensionIconView(ext: ext, size: 18)

                    Text(extensions.actionState(for: ext.id).title ?? ext.name)
                        .font(Typography.ui(Typography.base, weight: .semibold))
                        .foregroundStyle(p.foreground.color)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 7)

                Hairline().opacity(0.6)

                ExtensionActionPopup(
                    url: popupURL,
                    size: extensions.popupSize(for: ext)
                )
            } else {
                Text("Extensions")
                    .font(Typography.ui(Typography.base, weight: .semibold))
                    .foregroundStyle(p.foreground.color)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                Hairline().opacity(0.6)

                if extensions.extensions.isEmpty {
                    Text("No extensions installed.")
                        .font(Typography.ui(Typography.base))
                        .foregroundStyle(p.mutedForeground.color)
                        .padding(14)
                } else {
                    ScrollView {
                        VStack(spacing: 1) {
                            ForEach(extensions.extensions) { ext in
                                ExtensionMenuRow(
                                    ext: ext,
                                    hasAction: ext.enabled,
                                    onActivate: { activate(ext) },
                                    onTogglePin: { extensions.togglePinned(ext) }
                                )
                            }
                        }
                        .padding(5)
                    }
                    .frame(maxHeight: 320)
                }

                Hairline().opacity(0.6)

                Button {
                    store.settingsVisible = true
                    dismiss()
                } label: {
                    HStack(spacing: 7) {
                        Icon(name: "gearshape", size: 14, weight: .regular)
                        Text("Manage Extensions…")
                            .font(Typography.ui(Typography.base))
                        Spacer()
                    }
                    .foregroundStyle(p.foreground.color)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: activePopupExtension.map { extensions.popupSize(for: $0).width } ?? 300)
        .background(p.popover.color)
    }

    private func activate(_ ext: BrowserExtension) {
        if extensions.popupURL(for: ext) != nil {
            activePopupExtensionID = ext.id
        } else if let url = extensions.optionsURL(for: ext) {
            store.newTab(url: url)
            dismiss()
        } else if ext.enabled {
            store.activateExtensionAction(extensionID: ext.id)
            dismiss()
        }
    }
}

private struct ExtensionMenuRow: View {
    let ext: BrowserExtension
    let hasAction: Bool
    let onActivate: () -> Void
    let onTogglePin: () -> Void

    @Environment(\.palette) private var p
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onActivate) {
                HStack(spacing: 10) {
                    ExtensionIconView(ext: ext, size: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ext.name)
                            .font(Typography.ui(Typography.base, weight: .medium))
                            .foregroundStyle(p.foreground.color)
                            .lineLimit(1)
                        if !ext.enabled {
                            Text("Disabled")
                                .font(Typography.ui(Typography.small))
                                .foregroundStyle(p.mutedForeground.color)
                        }
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!hasAction)
            .help(hasAction ? "Run \(ext.name)" : "\(ext.name) is disabled")

            Button(action: onTogglePin) {
                Icon(name: ext.pinned ? "pin.fill" : "pin", size: 14)
                    .foregroundStyle(ext.pinned ? p.primary.color : p.mutedForeground.color)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(ext.pinned ? "Unpin from toolbar" : "Pin to toolbar")
        }
        .padding(.horizontal, 8)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(hover ? p.accent.color.opacity(0.5) : .clear)
        )
        .onHover { hover = $0 }
    }
}
