import AppKit
import SwiftUI
import Combine

@MainActor
final class SearchWindowController: NSObject, ObservableObject {

    @Published var query:         String       = ""
    @Published var results:       [EmojiEntry] = []
    @Published var selectedIndex: Int          = 0
    @Published var toastState:    ToastState   = .none
    @Published var isVisible:     Bool         = false

    enum ToastState { case none, copied, pasted }

    private var panel:            NSPanel?
    private(set) var previousApp: NSRunningApplication?
    private var queryCancellable: AnyCancellable?

    override init() {
        super.init()

        // Wakes up the EmojiStore to perform the JSON merge in the background
        _ = EmojiStore.shared

        queryCancellable = $query
            .removeDuplicates()
            .sink { [weak self] q in self?.updateResults(for: q) }

        PasteManager.shared.onPasteResult = { [weak self] autoPasted in
            guard let self else { return }
            self.toastState = autoPasted ? .pasted : .copied
        }
    }

    // MARK: - Public API

    func toggle() { if isVisible { hide() } else { show() } }

    func show() {
        guard !isVisible else { return }

        previousApp = NSWorkspace.shared.frontmostApplication

        ensurePanelExists()
        resetSearch()

        panel?.alphaValue = 0
        panel?.setFrameOrigin(centeredOrigin())
        panel?.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            if let textField = self.panel?.contentView?.findTextField() {
                self.panel?.makeFirstResponder(textField)
            }
        }

        isVisible = true

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel?.animator().alphaValue = 1
        }
    }

    func hide() {
        guard isVisible else { return }
        isVisible  = false
        toastState = .none

        let appToRestore = previousApp

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.10
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self else { return }

            self.panel?.orderOut(nil)
            self.resetSearch()

            // 🔑 Restore focus
            if let app = appToRestore, !app.isTerminated {
                app.activate(options: [])
            }
        }
    }

    func selectNext() {
        let count = query.isEmpty ? recentEmojis.count : results.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + 1) % count
    }

    func selectPrevious() {
        let count = query.isEmpty ? recentEmojis.count : results.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex - 1 + count) % count
    }

    func confirmSelection() {
        // Grab the correct entry whether we are searching or looking at recents
        let entry: EmojiEntry? = query.isEmpty ?
            (selectedIndex < recentEmojis.count ? recentEmojis[selectedIndex] : nil) :
            selectedEntry

        guard let confirmedEntry = entry else { return }
        let app = previousApp

        // Tell the store this was used so it moves up in frequency rankings
        EmojiStore.shared.recordUsage(of: confirmedEntry.emoji)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { self.hide() }
        PasteManager.shared.perform(emoji: confirmedEntry.emoji, previousApp: app)
    }

    func selectAndConfirm(at index: Int) {
        // Fixed: Ensure we check bounds against the correct array
        let count = query.isEmpty ? recentEmojis.count : results.count
        guard index < count else { return }
        
        selectedIndex = index
        confirmSelection()
    }

    var selectedEntry: EmojiEntry? {
        guard !results.isEmpty, selectedIndex < results.count else { return nil }
        return results[selectedIndex]
    }

    func previousAppForDirectPaste() -> NSRunningApplication? { previousApp }

    // MARK: - Search

    var recentEmojis: [EmojiEntry] {
        let freq = EmojiStore.shared.frequencies
        return EmojiStore.shared.allEmojis
            .filter { freq[$0.emoji, default: 0] > 0 }
            .sorted { freq[$0.emoji, default: 0] > freq[$1.emoji, default: 0] }
            .prefix(12)
            .map { $0 }
    }

    private func updateResults(for query: String) {
        results       = EmojiStore.shared.search(query: query)
        selectedIndex = 0
    }

    private func resetSearch() {
        query         = ""
        results       = []
        selectedIndex = 0
        toastState    = .none
    }

    // MARK: Panel setup (unchanged)

    private let panelWidth: CGFloat = 520
    private let panelHeight: CGFloat = 154

    private func ensurePanelExists() {
        guard panel == nil else { return }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        
        p.backgroundColor             = .clear
        p.isOpaque                    = false
        p.styleMask = [.borderless]
        p.becomesKeyOnlyIfNeeded      = false
        p.hasShadow                   = true
        p.level                       = .floating + 1
        p.isMovableByWindowBackground = true
        p.collectionBehavior          = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.isReleasedWhenClosed        = false
        p.delegate                    = self
        let panelFrame = CGRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        let host = NSHostingView(rootView: SearchView(controller: self))
        host.frame            = panelFrame
        host.autoresizingMask = [.width, .height]
        host.wantsLayer       = true
        host.layer?.backgroundColor = .clear
        host.layer?.cornerRadius  = 16
        host.layer?.borderColor = .clear

        if #available(macOS 26.0, *) {
            p.contentView = host
        } else {
            let vfx = NSVisualEffectView(frame: panelFrame)
            vfx.material          = .hudWindow
            vfx.blendingMode      = .behindWindow
            vfx.state             = .active
            vfx.wantsLayer        = true
            vfx.layer?.cornerRadius  = 16
            vfx.layer?.masksToBounds = true
            vfx.layer?.borderColor   = .clear
            vfx.layer?.borderWidth   = 0.5
            vfx.autoresizingMask     = [.width, .height]
            let container = NSView(frame: panelFrame)
            container.autoresizingMask = [.width, .height]
            container.addSubview(vfx)
            container.addSubview(host)
            p.contentView = container
        }
        panel = p
    }

    private func centeredOrigin() -> NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        let sf = screen.frame
        return NSPoint(
            x: sf.midX - panelWidth / 2,
            y: sf.midY + sf.height * 0.10
        )
    }
}

extension SearchWindowController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, self.isVisible else { return }
            if self.panel?.isKeyWindow == false { self.hide() }
        }
    }
}

extension NSPanel {
    override open var canBecomeKey: Bool { true }
}

extension NSView {
    func findTextField() -> NSTextField? {
        if let textField = self as? NSTextField { return textField }
        for subview in subviews {
            if let found = subview.findTextField() { return found }
        }
        return nil
    }
}
