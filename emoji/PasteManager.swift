// PasteManager.swift
// FastMoji — Two-mode paste engine
//
// Mode 1 · Clipboard (default, zero permissions)
//   Copies emoji → switches to previous app → shows "Press ⌘V" toast in our UI.
//
// Mode 2 · Auto-paste (optional, requires Accessibility)
//   Copies emoji → switches to previous app → waits 150ms → sends ⌘V via CGEvent.
//
// The user opts into Mode 2 during onboarding or from Settings.
// Accessibility is NEVER required to use the app. It is only an enhancement.

import AppKit
import ApplicationServices
import SwiftUI

// MARK: - Paste Mode

enum PasteMode: String, CaseIterable {
    case clipboard  = "clipboard"   // default — no permissions
    case autoPaste  = "autoPaste"   // sends ⌘V — needs Accessibility

    var displayName: LocalizedStringKey {
        switch self {
        case .clipboard: return "Copy to Clipboard"
        case .autoPaste: return "Auto-Paste (Accessibility)"
        }
    }

    var description: LocalizedStringKey {
        switch self {
        case .clipboard:
            return "Copies the emoji and switches back. Press ⌘V to paste."
        case .autoPaste:
            return "Automatically pastes the emoji — requires Accessibility access."
        }
    }
}

// MARK: - PasteManager

final class PasteManager {
    static let shared = PasteManager()
    private init() {}

    // ── Settings ─────────────────────────────────────────────────────────────

    var mode: PasteMode {
        get {
            PasteMode(rawValue: UserDefaults.standard.string(forKey: "fm_pasteMode") ?? "")
                ?? .clipboard
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "fm_pasteMode")
        }
    }

    /// Returns true only when Accessibility is both granted AND auto-paste is on.
    var willAutoPaste: Bool {
        mode == .autoPaste && AXIsProcessTrusted()
    }

    // ── Completion callback so SearchView can show a toast ────────────────────

    /// Called BEFORE the window dismisses. `autoPasted` tells the view
    /// whether to show "Pasted!" or "Press ⌘V to paste".
    var onPasteResult: ((_ autoPasted: Bool) -> Void)?

    // MARK: - Core Action

    /// The entire paste pipeline. Call right after user confirms a selection.
    ///
    /// - Parameters:
    ///   - emoji: The emoji character to insert.
    ///   - previousApp: The app that was frontmost BEFORE FastMoji opened.
    func perform(emoji: String, previousApp: NSRunningApplication?) {
        // 1 · Record frequency
        EmojiStore.shared.recordUsage(of: emoji)

        // 2 · Write to clipboard
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(emoji, forType: .string)

        // 3 · Notify UI (show toast before we dismiss)
        let willPaste = willAutoPaste
        onPasteResult?(willPaste)

        // 4 · Brief delay for the toast to be visible, then switch apps
        DispatchQueue.main.asyncAfter(deadline: .now() + (willPaste ? 0.08 : 0.55)) {
            guard let app = previousApp else { return }
            app.activate(options: [])

            if willPaste {
                // 5a · Auto-paste: wait for the app to become frontmost
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    self.sendCommandV()
                }
            }
            // 5b · Clipboard mode: user presses ⌘V themselves.
        }
    }

    // MARK: - Send ⌘V via CGEvent (requires Accessibility)

    private func sendCommandV() {
        guard AXIsProcessTrusted() else { return }

        let src = CGEventSource(stateID: .hidSystemState)

        // kVK_ANSI_V = 0x09
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)

        let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
