// SettingsView.swift
// emoji.key — Preferences window (General + Permissions tabs)
//
// Opened via the standard macOS Settings scene (Cmd+,) or status bar menu.

import SwiftUI
import AppKit
import ApplicationServices
import ServiceManagement

// MARK: - Root

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            KeywordsTab()
                .tabItem {
                    Label("Keywords", systemImage: "keyboard")
                }

            PermissionsTab()
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
        }
        .frame(width: 480, height: 380)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @State private var launchAtLogin: Bool = {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }()

    @AppStorage("fm_pasteMode") private var pasteModeRaw: String = PasteMode.clipboard.rawValue
    private var currentPasteMode: PasteMode { PasteMode(rawValue: pasteModeRaw) ?? .clipboard }

    var body: some View {
        Form {
            // ── Hotkey ────────────────────────────────────────────────────
            Section("Keyboard Shortcut") {
                HotkeyRecorderRow()
            }

            // ── Paste mode ────────────────────────────────────────────────
            Section("Paste Mode") {
                ForEach(PasteMode.allCases, id: \.rawValue) { mode in
                    PasteModeRow(
                        mode: mode,
                        isSelected: mode == currentPasteMode,
                        onTap: { selectPasteMode(mode) }
                    )
                }
            }

            // ── Login item ─────────────────────────────────────────────────
            Section("System") {
                Toggle("Open emoji.key at Login", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private func selectPasteMode(_ mode: PasteMode) {
        if mode == .autoPaste && !AXIsProcessTrusted() {
            // Open Accessibility settings
            openAccessibilitySettings()
            return
        }
        pasteModeRaw = mode.rawValue
        PasteManager.shared.mode = mode
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("[emoji.key] SMAppService error: \(error)")
                // Revert toggle on failure
                launchAtLogin = !enabled
            }
        }
    }

    private func openAccessibilitySettings() {
        let opts: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        AXIsProcessTrustedWithOptions(opts)
    }
}

// MARK: - Hotkey Recorder Row

private struct HotkeyRecorderRow: View {
    @State private var isRecording:   Bool   = false
    @State private var displayString: String = HotkeyManager.shared.displayString
    @State private var localMonitor:  Any?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Trigger Shortcut")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                Text("Press the shortcut to open emoji.key from anywhere.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Recorder button
            Button {
                if isRecording { stopRecording() } else { startRecording() }
            } label: {
                Text(isRecording ? "Type shortcut…" : displayString)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isRecording ? .red : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isRecording
                                  ? Color.red.opacity(0.1)
                                  : Color.primary.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(isRecording
                                            ? Color.red.opacity(0.3)
                                            : Color.primary.opacity(0.15),
                                            lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .animation(.easeOut(duration: 0.15), value: isRecording)
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording  = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Require at least one modifier key (avoid naked single keys)
            let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard !mods.isEmpty, event.keyCode != 53 else { // 53 = Escape cancels
                if event.keyCode == 53 { self.stopRecording() }
                return event
            }

            let carbonMods = HotkeyManager.carbonModifiers(from: event.modifierFlags)
            HotkeyManager.shared.update(keyCode: UInt32(event.keyCode),
                                        carbonModifiers: carbonMods)
            self.displayString = HotkeyManager.shared.displayString
            self.stopRecording()
            return nil // consume
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
    }
}

// MARK: - Paste Mode Row

private struct PasteModeRow: View {
    let mode: PasteMode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .font(.system(size: 16))
                .onTapGesture(perform: onTap)

            VStack(alignment: .leading, spacing: 2) {
                Text(mode.displayName)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                Text(mode.description)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Permissions Tab

private struct PermissionsTab: View {
    @State private var axGranted = AXIsProcessTrusted()
    @State private var pollTimer: Timer?

    var body: some View {
        Form {
            Section {
                PermissionRow(
                    icon:        "cursorarrow.rays",
                    title:       "Accessibility",
                    subtitle:    "Required for Auto-Paste (optional). emoji.key works without it — you'll just paste manually with ⌘V.",
                    isGranted:   axGranted,
                    buttonTitle: axGranted ? "Granted ✓" : "Open System Settings"
                ) {
                    if !axGranted { openAccessibilitySettings() }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
        .onAppear { startPolling() }
        .onDisappear { pollTimer?.invalidate() }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            let now = AXIsProcessTrusted()
            if now != axGranted { axGranted = now }
        }
    }

    private func openAccessibilitySettings() {
        let opts: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        AXIsProcessTrustedWithOptions(opts)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct PermissionRow: View {
    let icon:        String
    let title:       LocalizedStringKey
    let subtitle:    LocalizedStringKey
    let isGranted:   Bool
    let buttonTitle: LocalizedStringKey
    let action:      () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isGranted ? Color.green.opacity(0.12) : Color.accentColor.opacity(0.10))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isGranted ? .green : .accentColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .disabled(isGranted)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 6)
    }
}
// MARK: - Keywords Tab

private struct KeywordsTab: View {
    // Local copy so the list refreshes when we mutate
    @State private var keywords: [String: String] = EmojiStore.shared.customKeywords
    @State private var newKeyword: String = ""
    @State private var newEmoji:   String = ""
    @State private var errorMsg:   String = ""

    var body: some View {
        VStack(spacing: 0) {
            // ── Existing mappings ──────────────────────────────────────────
            if keywords.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "keyboard.badge.ellipsis")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("No custom keywords yet")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("Type any keyword and it will always show that emoji first.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(keywords.sorted(by: { $0.key < $1.key }), id: \.key) { kw, emoji in
                        HStack(spacing: 12) {
                            Text(emoji)
                                .font(.system(size: 22))
                                .frame(width: 34)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(kw)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                Text("Always ranks \(emoji) first when you type \"\(kw)\"")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                EmojiStore.shared.removeCustomKeyword(kw)
                                keywords = EmojiStore.shared.customKeywords
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red.opacity(0.7))
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // ── Add new keyword ────────────────────────────────────────────
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    // Keyword field
                    TextField("Keyword (e.g. lit)", text: $newKeyword)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .rounded))
                        .frame(maxWidth: .infinity)

                    Text("→")
                        .foregroundStyle(.tertiary)

                    // Emoji field — user types/pastes emoji character directly
                    TextField("Emoji", text: $newEmoji)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 18))
                        .frame(width: 64)
                        .multilineTextAlignment(.center)
                        .onChange(of: newEmoji) { _, val in
                            // Keep only the first emoji scalar cluster
                            if let first = val.unicodeScalars.first,
                               first.properties.isEmoji {
                                let cluster = String(val.prefix(2)) // handles skin tones etc.
                                if cluster != val { newEmoji = cluster }
                            } else if !val.isEmpty {
                                newEmoji = String(val.suffix(1))
                            }
                        }

                    Button("Add") {
                        addKeyword()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newKeyword.trimmingCharacters(in: .whitespaces).isEmpty || newEmoji.isEmpty)
                    .controlSize(.regular)
                }

                if !errorMsg.isEmpty {
                    Text(errorMsg)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.red)
                }

                Text("Works for English and Japanese. The keyword is case-insensitive.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .onAppear { keywords = EmojiStore.shared.customKeywords }
    }

    private func addKeyword() {
        let kw = newKeyword.trimmingCharacters(in: .whitespaces)
        let em = newEmoji.trimmingCharacters(in: .whitespaces)

        guard !kw.isEmpty else { errorMsg = "Keyword cannot be empty."; return }
        guard !em.isEmpty else { errorMsg = "Please enter an emoji.";   return }

        // Validate that the emoji field contains an actual emoji
        guard em.unicodeScalars.contains(where: { $0.properties.isEmoji && $0.value > 127 }) else {
            errorMsg = "That doesn't look like an emoji. Paste one in."
            return
        }

        EmojiStore.shared.addCustomKeyword(kw, for: em)
        keywords   = EmojiStore.shared.customKeywords
        newKeyword = ""
        newEmoji   = ""
        errorMsg   = ""
    }
}
