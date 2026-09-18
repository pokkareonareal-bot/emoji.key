// HotkeyManager.swift
// FastMoji — Global hotkey via Carbon RegisterEventHotKey
//
// WHY CARBON: CGEventTap requires Accessibility permission and is banned from
// the App Sandbox. RegisterEventHotKey is a documented, App Store-approved
// API for global hotkeys. It does NOT require Accessibility permission.
//
// Default: ⌘⇧E  (Command + Shift + E)

import Carbon.HIToolbox
import AppKit

// MARK: - HotkeyManager

final class HotkeyManager {
    static let shared = HotkeyManager()
    private init() {}

    /// Called on the main thread when the hotkey fires.
    var onHotkeyPressed: (() -> Void)?

    private var hotKeyRef:        EventHotKeyRef?
    private var eventHandlerRef:  EventHandlerRef?
    private var handlerInstalled  = false

    // ── Persisted Hotkey ────────────────────────────────────────────────────
    private let keyCodeKey  = "fm_hotkeyCode"
    private let modifiersKey = "fm_hotkeyMods"

    // Carbon modifier bit-masks (not NSEventModifierFlags)
    private let defaultKeyCode:   UInt32 = UInt32(kVK_ANSI_E)
    private let defaultModifiers: UInt32 = UInt32(cmdKey | shiftKey)

    private(set) var keyCode:   UInt32 = 0
    private(set) var modifiers: UInt32 = 0

    // MARK: - Public API

    /// Call once from AppDelegate.applicationDidFinishLaunching
    func register() {
        loadSaved()
        installEventHandlerIfNeeded()
        registerHotkey()
    }

    /// Update the hotkey (called from Settings).
    func update(keyCode newCode: UInt32, carbonModifiers newMods: UInt32) {
        keyCode   = newCode
        modifiers = newMods
        UserDefaults.standard.set(Int(newCode), forKey: keyCodeKey)
        UserDefaults.standard.set(Int(newMods), forKey: modifiersKey)
        registerHotkey()
    }

    /// Human-readable string, e.g. "⌘⇧E"
    var displayString: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        s += keyName(for: keyCode)
        return s
    }

    // MARK: - Private

    private func loadSaved() {
        if let code = UserDefaults.standard.object(forKey: keyCodeKey) as? Int {
            keyCode   = UInt32(code)
        } else {
            keyCode   = defaultKeyCode
        }
        if let mods = UserDefaults.standard.object(forKey: modifiersKey) as? Int {
            modifiers = UInt32(mods)
        } else {
            modifiers = defaultModifiers
        }
    }

    private func installEventHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind:  UInt32(kEventHotKeyPressed)
        )

        // Pass unretained — the singleton lives for the app's lifetime.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let ptr = userData else { return OSStatus(eventNotHandledErr) }
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(ptr).takeUnretainedValue()
                DispatchQueue.main.async { mgr.onHotkeyPressed?() }
                return noErr
            },
            1,
            &eventSpec,
            selfPtr,
            &eventHandlerRef
        )
    }

    private func registerHotkey() {
        // Unregister previous
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }

        // Signature "FMOJ" as UInt32 big-endian: 0x464D4F4A
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = 0x464D4F4A
        hotKeyID.id        = 1

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            print("[FastMoji] RegisterEventHotKey failed: \(status)")
        }
    }

    // MARK: - Key name lookup

    private func keyName(for keyCode: UInt32) -> String {
        // Common ANSI key-code → glyph map
        let map: [UInt32: String] = [
            0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E",
            0x03: "F", 0x05: "G", 0x04: "H", 0x22: "I", 0x26: "J",
            0x28: "K", 0x25: "L", 0x2E: "M", 0x2D: "N", 0x1F: "O",
            0x23: "P", 0x0C: "Q", 0x0F: "R", 0x01: "S", 0x11: "T",
            0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X", 0x10: "Y",
            0x06: "Z",
            0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5",
            0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9", 0x1D: "0",
            0x24: "↩", 0x30: "⇥", 0x31: "Space", 0x33: "⌫", 0x35: "⎋",
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5",
            0x61: "F6", 0x62: "F7", 0x64: "F8",
        ]
        return map[keyCode] ?? "?"
    }
}

// MARK: - NSEventModifierFlags → Carbon modifiers

extension HotkeyManager {
    /// Converts SwiftUI/AppKit modifier flags to Carbon modifier bit-mask.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey)     }
        if flags.contains(.shift)   { mods |= UInt32(shiftKey)   }
        if flags.contains(.option)  { mods |= UInt32(optionKey)  }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }
}
