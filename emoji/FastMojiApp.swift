// FastMojiApp.swift
// FastMoji — @main entry point
//
// Architecture:
//   • @NSApplicationDelegateAdaptor bridges to AppDelegate for full AppKit control.
//   • Settings scene provides the standard ⌘, preferences window.
//   • Activation policy (.accessory) is set in AppDelegate — no Dock icon.

import SwiftUI

@main
struct FastMojiApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Standard macOS Settings window (Cmd+,)
        Settings {
            SettingsView()
        }
    }
}
