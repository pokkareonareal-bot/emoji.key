// AppDelegate.swift

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let searchController = SearchWindowController()
    private var statusItem: NSStatusItem?
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        HotkeyManager.shared.register()
        // First launch gate
        if UserDefaults.standard.bool(forKey: "fm_onboardingComplete") {
            bootHotkey()
        } else {
            presentOnboarding()
        }
    }

    private func bootHotkey() {
        HotkeyManager.shared.onHotkeyPressed = { [weak self] in
            self?.searchController.toggle()
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Load your custom asset by the name you gave it in Assets.xcassets
            if let customIcon = NSImage(named: "menubaritem") {
                // Force template mode just in case it wasn't set in the Asset Catalog
                customIcon.isTemplate = true
                button.image = customIcon
            } else {
                // Fallback if the file is missing
                button.image = NSImage(systemSymbolName: "face.smiling", accessibilityDescription: "emoji.key")
            }
        }

        let menu = NSMenu()

        // 1. Show Search (The Emoji Picker)
        let title1 = NSLocalizedString("Search Emojis", comment: "")
        menu.addItem(withTitle: title1, action: #selector(openPicker), keyEquivalent: "")
        
        menu.addItem(NSMenuItem.separator())

        // 2. Settings
        let title2 = NSLocalizedString("Settings...", comment: "")
        menu.addItem(withTitle: title2, action: #selector(openSettings), keyEquivalent: ",")
        
        // 3. Onboarding / Tutorial
        let title3 = NSLocalizedString("Show Tutorial", comment: "")
        menu.addItem(withTitle: title3, action: #selector(openOnboarding), keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())

        // 4. Quit
        let title4 = NSLocalizedString("Quit emoji.key", comment: "")
        menu.addItem(withTitle: title4, action: #selector(quitApp), keyEquivalent: "q")

        // Crucial: Setting the menu property makes it show on LEFT click automatically.
        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func openPicker() {
        // Bring app to front so the search field gets focus immediately
        NSApp.activate(ignoringOtherApps: true)
        searchController.show()
    }

    @objc private func openSettings() {
        // 1. If it's already open, just bring it to the front
        if settingsWindow != nil {
            settingsWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // 2. Initialize your SwiftUI Settings View
        let contentView = SettingsView()

        // 3. Create the Window
        // Notice the width: 480, height: 380 to match your SettingsView frame
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.titled, .closable], // Standard settings windows have titles and close buttons
            backing: .buffered,
            defer: false
        )
        
        // 4. Configure the window
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false // Keeps it in memory for faster reopening
        
        
        window.contentView = NSHostingView(rootView: contentView)
        
        // 5. Save reference and present
        self.settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func openOnboarding() {
        NSApp.activate(ignoringOtherApps: true)
        presentOnboarding()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Onboarding Window Logic

    private func presentOnboarding() {
        if onboardingWindow != nil {
            onboardingWindow?.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = OnboardingView { [weak self] in
            UserDefaults.standard.set(true, forKey: "fm_onboardingComplete")
            self?.bootHotkey()
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 580),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false)
        
        window.center()
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentView = NSHostingView(rootView: contentView)
        
        self.onboardingWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
