// SearchView.swift
// FastMoji — Compact horizontal HUD (520 × 154 px)
//
// Glass strategy:
//   macOS 26+ : .glassEffect(in: RoundedRectangle(cornerRadius:16)) on the VStack.
//               NO fill, NO NSVisualEffectView, NO .background() with color.
//               The shape parameter controls the glass region — NOT the default capsule.
//   macOS <26 : NSVisualEffectView (.hudWindow) is set up by SearchWindowController
//               behind the NSHostingView. SwiftUI layer is fully transparent.
//               Root view uses .clipShape(RoundedRectangle(16)) for clean edges.
//
// Bug fixes carried forward:
//   Bug 1 — Arrow keys: NSTextFieldDelegate.control(_:textView:doCommandBy:) intercepts
//            before the field editor acts. keyDown on the subclass is a fallback only.
//   Bug 2 — Stale emoji: ForEach id:\.offset forces full cell rebuild on results change.

import SwiftUI
import AppKit

// MARK: - Root

struct SearchView: View {
    @ObservedObject var controller: SearchWindowController

    var body: some View {
        if #available(macOS 26.0, *) {
            content
                // Shape must be RoundedRectangle — NOT the default Capsule.
                // .glassEffect clips to this shape AND draws the material.
                // Any Color fill behind this would fight the compositor.
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        } else {
            // NSVisualEffectView (set up by SearchWindowController) shows through.
            // We only need to clip our SwiftUI content to match the rounded corners.
            content
                .background(.clear)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // ── Content ───────────────────────────────────────────────────────────────

    private var content: some View {
        VStack(spacing: 0) {
            SearchBar(controller: controller)

            Divider().opacity(0.10)

            Group {
                if controller.toastState != .none {
                    ToastStrip(state: controller.toastState)
                } else if controller.query.isEmpty {
                    RecentsStrip(controller: controller)
                } else if controller.results.isEmpty {
                    NoResultsStrip(query: controller.query)
                } else {
                    ResultsStrip(controller: controller)
                }
            }
            .frame(height: 76)

            Divider().opacity(0.10)

            HintBar(controller: controller)
        }
        .frame(width: 520, height: 154)
    }
}

// MARK: - Search Bar

private struct SearchBar: View {
    @ObservedObject var controller: SearchWindowController

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            InterceptingTextField(
                text:         $controller.query,
                placeholder:  "Search emojis…",
                onArrowRight: { controller.selectNext() },
                onArrowLeft:  { controller.selectPrevious() },
                onArrowDown:  { controller.selectNext() },
                onArrowUp:    { controller.selectPrevious() },
                onReturn:     { controller.confirmSelection() },
                onTab:        { controller.confirmSelection() },
                onEscape:     { controller.hide() }
            )
            .frame(height: 20)

            if !controller.query.isEmpty {
                Button { controller.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
                .animation(.easeOut(duration: 0.12), value: controller.query.isEmpty)
            }

            Text(HotkeyManager.shared.displayString)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.quaternary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
    }
}

// MARK: - Results Strip
// Bug 2 fix: id:\.offset — positional identity prevents SwiftUI from recycling
// stale emoji glyphs when the result set changes between queries.

private struct ResultsStrip: View {
    @ObservedObject var controller: SearchWindowController

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(
                        Array(controller.results.prefix(12).enumerated()),
                        id: \.offset
                    ) { idx, entry in
                        EmojiCell(
                            emoji:      entry.emoji,
                            label:      entry.aliases.first ?? "",
                            isSelected: idx == controller.selectedIndex,
                            showDot:    EmojiStore.shared.frequencies[entry.emoji, default: 0] > 0
                        ) {
                            controller.selectAndConfirm(at: idx)
                        }
                        .id(idx)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .onChange(of: controller.selectedIndex) { _, newIdx in
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(newIdx, anchor: .center) }
            }
            .onChange(of: controller.results.map(\.emoji).joined()) { _, _ in
                proxy.scrollTo(0, anchor: .leading)
            }
        }
    }
}

// MARK: - Emoji Cell

private struct EmojiCell: View {
    let emoji:      String
    let label:      String
    let isSelected: Bool
    let showDot:    Bool
    let action:     () -> Void

    @State private var isHovered = false

    private var bg: Color {
        if isSelected { return Color.accentColor.opacity(0.85) }
        if isHovered  { return Color.primary.opacity(0.07) }
        return .clear
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(emoji)
                    .font(.system(size: 28))
                    .fixedSize()
                /*
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 52)*/
            }
            .frame(width: 58, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(bg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if showDot && !isSelected {
                    Circle()
                        .fill(Color.accentColor.opacity(0.65))
                        .frame(width: 5, height: 5)
                        .padding(5)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered ? 1.07 : 1.0)
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isHovered)
        .animation(.easeOut(duration: 0.10), value: isSelected)
    }
}

// MARK: - Recents Strip

private struct RecentsStrip: View {
    @ObservedObject var controller: SearchWindowController

    var body: some View {
        let recents = controller.recentEmojis

        if recents.isEmpty {
            HStack(spacing: 8) {
                Text("⌨️").font(.system(size: 22))
                Text("Start typing to search \(EmojiStore.shared.allEmojis.count) emojis")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        Text("Recent")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(-90))
                            .frame(width: 20)
                            .padding(.leading, 8)

                        HStack(spacing: 2) {
                            ForEach(Array(recents.enumerated()), id: \.offset) { idx, entry in
                                EmojiCell(
                                    emoji: entry.emoji,
                                    label: entry.aliases.first ?? "",
                                    isSelected: idx == controller.selectedIndex,
                                    showDot: false
                                ) {
                                    controller.selectedIndex = idx
                                    let prev = controller.previousAppForDirectPaste()
                                    PasteManager.shared.perform(emoji: entry.emoji, previousApp: prev)

                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                                        controller.hide()
                                    }
                                }
                                .id(idx)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.vertical, 6)
                }
                .onChange(of: controller.selectedIndex) { _, newIdx in
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(newIdx, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - No Results

private struct NoResultsStrip: View {
    let query: String
    var body: some View {
        HStack(spacing: 8) {
            Text("🤷").font(.system(size: 22))
            Text("No match for \(query)")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Toast Strip

private struct ToastStrip: View {
    let state: SearchWindowController.ToastState
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state == .pasted ? "checkmark.circle.fill" : "doc.on.clipboard.fill")
                .font(.system(size: 24))
                .foregroundStyle(state == .pasted ? .green : Color.accentColor)
                .symbolEffect(.bounce, value: state)
            VStack(alignment: .leading, spacing: 2) {
                Text(state == .pasted ? "Pasted!" : "Copied!")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                if state == .copied {
                    Text("Switch to your app and press ⌘V")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }
}

// MARK: - Hint Bar

private struct HintBar: View {
    @ObservedObject var controller: SearchWindowController
    var body: some View {
        HStack(spacing: 12) {
            HintPill(key: "↩",  label: "insert")
            HintPill(key: "↓↑", label: "navigate")
            HintPill(key: "⎋",  label: "dismiss")
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(PasteManager.shared.willAutoPaste ? .green : Color.accentColor)
                    .frame(width: 4, height: 4)
                Text(PasteManager.shared.willAutoPaste ? "Auto-paste" : "Clipboard")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 26)
    }
}

private struct HintPill: View {
    let key: String; let label: String
    var body: some View {
        HStack(spacing: 3) {
            Text(key).font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(.tertiary)
            Text(label).font(.system(size: 9, weight: .regular, design: .rounded)).foregroundStyle(.quaternary)
        }
    }
}

// MARK: - InterceptingTextField
//
// Bug 1 root cause: when NSTextField is being edited, the shared field editor
// (NSTextView) becomes first responder and consumes all key events.
// Overriding keyDown on the NSTextField subclass misses most of them.
//
// Fix: implement NSTextFieldDelegate.control(_:textView:doCommandBy:).
// This fires on the DELEGATE before the field editor acts — returning true
// suppresses the default behaviour entirely.
//
// Arrow left/right are smart: they only navigate results when the cursor is
// already at the start/end of the query, so mid-word editing still works.

struct InterceptingTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder:   String
    let onArrowRight:  () -> Void
    let onArrowLeft:   () -> Void
    let onArrowDown:   () -> Void
    let onArrowUp:     () -> Void
    let onReturn:      () -> Void
    let onTab:         () -> Void
    let onEscape:      () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> FastMojiTextField {
        let tf = FastMojiTextField()
        tf.delegate           = context.coordinator
        tf.placeholderString  = placeholder
        tf.isBordered         = false
        tf.isBezeled          = false
        tf.drawsBackground    = false
        tf.focusRingType      = .none
        tf.font               = NSFont.systemFont(ofSize: 15, weight: .regular)
        tf.textColor          = NSColor.labelColor
        tf.cell?.wraps        = false
        tf.cell?.isScrollable = true
        apply(to: tf)
        DispatchQueue.main.async { tf.window?.makeFirstResponder(tf) }
        return tf
    }

    func updateNSView(_ tf: FastMojiTextField, context: Context) {
        if tf.stringValue != text { tf.stringValue = text }
        apply(to: tf)
    }

    private func apply(to tf: FastMojiTextField) {
        tf.onArrowRight = onArrowRight; tf.onArrowLeft = onArrowLeft
        tf.onArrowDown  = onArrowDown;  tf.onArrowUp   = onArrowUp
        tf.onReturn     = onReturn;     tf.onTab       = onTab
        tf.onEscape     = onEscape
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: InterceptingTextField
        init(_ p: InterceptingTextField) { parent = p }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            parent.text = tf.stringValue
        }

        // PRIMARY intercept point — fires before the field editor acts.
        func control(_ control: NSControl,
                     textView: NSTextView,
                     doCommandBy sel: Selector) -> Bool {
            guard let tf = control as? FastMojiTextField else { return false }
            switch sel {
            case #selector(NSResponder.moveDown(_:)):
                tf.onArrowDown?(); return true
            case #selector(NSResponder.moveUp(_:)):
                tf.onArrowUp?(); return true
            case #selector(NSResponder.moveRight(_:)):
                let atEnd = textView.selectedRange().location == (textView.string as NSString).length
                if atEnd { tf.onArrowRight?(); return true }
                return false  // pass through — let cursor move within text
            case #selector(NSResponder.moveLeft(_:)):
                if textView.selectedRange().location == 0 { tf.onArrowLeft?(); return true }
                return false
            case #selector(NSResponder.insertNewline(_:)):
                tf.onReturn?(); return true
            case #selector(NSResponder.insertTab(_:)):
                tf.onTab?(); return true
            case #selector(NSResponder.cancelOperation(_:)):
                tf.onEscape?(); return true
            default:
                return false
            }
        }
    }
}

// MARK: - FastMojiTextField (belt-and-suspenders keyDown fallback)

final class FastMojiTextField: NSTextField {
    var onArrowRight: (() -> Void)?; var onArrowLeft: (() -> Void)?
    var onArrowDown:  (() -> Void)?; var onArrowUp:   (() -> Void)?
    var onReturn:     (() -> Void)?; var onTab:       (() -> Void)?
    var onEscape:     (() -> Void)?

    private enum KC {
        static let ret: UInt16 = 36; static let tab: UInt16 = 48
        static let esc: UInt16 = 53; static let up:  UInt16 = 126
        static let dn:  UInt16 = 125; static let lt: UInt16 = 123
        static let rt:  UInt16 = 124
    }

    override func keyDown(with e: NSEvent) {
        switch e.keyCode {
        case KC.dn:  onArrowDown?()
        case KC.up:  onArrowUp?()
        case KC.lt:  onArrowLeft?()
        case KC.rt:  onArrowRight?()
        case KC.ret: onReturn?()
        case KC.tab: onTab?()
        case KC.esc: onEscape?()
        default:     super.keyDown(with: e)
        }
    }

    override var acceptsFirstResponder: Bool { true }
}
