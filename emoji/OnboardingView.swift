// OnboardingView.swift
// emoji.key — First-launch onboarding (4 steps)
//
//  Step 0 · Welcome
//  Step 1 · How It Works  (hotkey demo)
//  Step 2 · Paste Mode    (clipboard vs auto-paste / Accessibility)
//  Step 3 · Login & Done

import SwiftUI
import AppKit
import ApplicationServices
import ServiceManagement

// MARK: - Root

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var step: Int = 0

    private let totalSteps = 4

    var body: some View {
        ZStack {
            // Background only shows on steps 1–3; step 0 is fully hero-image-driven
            if step > 0 {
                OnboardingBackground()
                    .transition(.opacity)
            }

            Group {
                switch step {
                case 0:
                    WelcomeStep(onNext: advance)
                        .transition(slideTransition)
                case 1:
                    HowItWorksStep(onNext: advance)
                        .transition(slideTransition)
                case 2:
                    PasteModeStep(onNext: advance)
                        .transition(slideTransition)
                case 3:
                    LaunchStep(onDone: onComplete)
                        .transition(slideTransition)
                default:
                    EmptyView()
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: step)

            VStack {
                Spacer()
                StepDots(current: step, total: totalSteps)
                    .padding(.bottom, 28)
            }
        }
        .frame(width: 520, height: 580)
    }

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion:  .move(edge: .trailing).combined(with: .opacity),
            removal:    .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advance() { withAnimation { step += 1 } }
}

// MARK: - Step 0 · Welcome

private struct WelcomeStep: View {
    let onNext: () -> Void

    @State private var heroAppeared    = false
    @State private var contentAppeared = false

    // Window is 520 × 580 pt.
    // The image is square — to show it fully without any crop, it must
    // render at exactly 520 × 520 pt (matching the window width).
    // That leaves 60 pt at the bottom for the button.
    private let windowWidth:  CGFloat = 520
    private let windowHeight: CGFloat = 580
    private var heroSize:     CGFloat { windowWidth }          // 520 × 520, no crop
    private var buttonZoneH:  CGFloat { windowHeight - heroSize } // 60 pt

    var body: some View {
        ZStack(alignment: .top) {

            // ── Full-width square hero ────────────────────────────────────────
            HeroImage(appeared: heroAppeared)
                .frame(width: windowWidth, height: heroSize)
                // Fade the bottom portion into the window background so the
                // text and button float cleanly over it.
                // Fade starts at 78% so the keyboard subject is fully visible.
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black,            location: 0.0),
                            .init(color: .black,            location: 0.72),
                            .init(color: .black.opacity(0), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint:   .bottom
                    )
                )
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0), location: 0.0),
                            .init(color: .black,            location: 0.1),
                            .init(color: .black,            location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint:   .bottom
                    )
                )

            // ── Content overlaid over the faded bottom of the hero ────────────
            VStack(spacing: 0) {
                Spacer()   // pushes content down toward the faded region

                Text("emoji.key")
                    .font(.system(size: 38, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 10)

                Text("The fastest way to type emojis.")
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundStyle(.secondary)
                    .padding(.top, 5)
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 8)

                Text("System-wide  ·  Smart search  ·  Instant")
                    .font(.system(size: 11, design: .default))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 3)
                    .opacity(contentAppeared ? 1 : 0)

                PillButton(title: "Get Started", icon: "arrow.right", action: onNext)
                    .padding(.top, 20)
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 12)
                    .padding(.bottom, 48)
            }
            .frame(width: windowWidth, height: windowHeight)
        }
        .frame(width: windowWidth, height: windowHeight)
        .onAppear {
            // Hero fades + Ken Burns settle starts immediately
            withAnimation(.easeOut(duration: 0.50)) {
                heroAppeared = true
            }
            // Content staggers in after the hero is visible
            withAnimation(.spring(response: 0.52, dampingFraction: 0.78).delay(0.20)) {
                contentAppeared = true
            }
        }
    }
}

// ── Hero image — Ken Burns scale settle ──────────────────────────────────────
private struct HeroImage: View {
    let appeared: Bool

    var body: some View {
        Image("heroimage_light")
            .resizable()
            // .fit keeps the full square visible — no cropping whatsoever.
            // The frame is already square (520×520) so .fit and .fill are
            // equivalent here, but .fit makes the intent explicit.
            .aspectRatio(contentMode: .fit)
            // Ken Burns: start slightly zoomed in, settle to 1:1
            .scaleEffect(appeared ? 1.0 : 1.05, anchor: .center)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 1.5), value: appeared)
    }
}

// MARK: - Step 1 · How It Works

private struct HowItWorksStep: View {
    let onNext: () -> Void
    @State private var appeared = false
    @State private var demoPhase: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("How It Works")
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .opacity(appeared ? 1 : 0)

            Text("One shortcut. Anywhere.")
                .font(.system(size: 16, design: .default))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .opacity(appeared ? 1 : 0)

            // Animated shortcut demo
            HotkeyDemoWidget(phase: demoPhase)
                .padding(.top, 32)
                .opacity(appeared ? 1 : 0)

            // Step bubbles
            VStack(alignment: .leading, spacing: 10) {
                StepBubble(number: "1", text: "Press \(HotkeyManager.shared.displayString) from any app")
                StepBubble(number: "2", text: "Type to search — results appear instantly")
                StepBubble(number: "3", text: "Press ↩ — emoji lands where you were typing")
            }
            .padding(.top, 64)
            .opacity(appeared ? 1 : 0)

            Spacer()

            PillButton(title: "Next", icon: "arrow.right", action: onNext)
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, 56)
        }
        .padding(.horizontal, 60)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.05)) {
                appeared = true
            }
            runLoop()
        }
    }

    private func runLoop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)  { demoPhase = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4)  { demoPhase = 2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6)  { demoPhase = 3 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5)  { demoPhase = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { runLoop() }
        }
    }
}

private struct HotkeyDemoWidget: View {
    let phase: Int

    var body: some View {
        ZStack(alignment: .top) {
            // Fake app window
            VStack(alignment: .leading, spacing: 0) {
                // Fake traffic lights + title bar
                HStack(spacing: 6) {
                    Circle().fill(Color(nsColor: .systemRed)).frame(width: 10, height: 10)
                    Circle().fill(Color(nsColor: .systemYellow)).frame(width: 10, height: 10)
                    Circle().fill(Color(nsColor: .systemGreen)).frame(width: 10, height: 10)
                    Spacer()
                    Text("Notes").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04))

                Divider().opacity(0.15)

                // Fake text content
                HStack(spacing: 0) {
                    Text("Meeting notes: the team was ")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary.opacity(0.7))
                    // Blinking caret OR emoji result
                    if phase == 0 {
                        BlinkingCaret()
                    } else if phase == 3 {
                        Text("🔥")
                            .font(.system(size: 16))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        BlinkingCaret()
                    }
                    Spacer()
                }
                .padding(12)
                .frame(height: 60)
            }
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .frame(maxWidth: 360)

            // Keyboard shortcut badge floating above
            if phase == 1 || phase == 2 {
                HStack(spacing: 6) {
                    Text(HotkeyManager.shared.displayString)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("pressed")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.accentColor))
                .shadow(color: Color.accentColor.opacity(0.4), radius: 8, y: 4)
                .offset(y: -18)
                .transition(.scale(scale: 0.7, anchor: .bottom).combined(with: .opacity))
            }

            // Mini picker floating below
            if phase == 2 {
                MiniPickerBadge()
                    .offset(y: 100)
                    .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: phase)
        .frame(height: 120)
    }
}

private struct MiniPickerBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            ForEach(["🔥","💥","☀️","🌶️"], id: \.self) { e in
                VStack(spacing: 1) {
                    Text(e).font(.system(size: 20))
                    Text(e == "🔥" ? "fire" : "")
                        .font(.system(size: 8)).foregroundStyle(.white.opacity(0.8))
                }
                .frame(width: 40, height: 44)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(e == "🔥" ? Color.accentColor.opacity(0.85) : Color.clear))
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5))
    }
}

private struct StepBubble: View {
    let number: String
    let text:   LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 26, height: 26)
                Text(number)
                    .font(.system(size: 12, weight: .bold, design: .default))
                    .foregroundStyle(Color.accentColor)
            }
            Text(text)
                .font(.system(size: 13, design: .default))
                .foregroundStyle(.primary.opacity(0.85))
        }
    }
}

// MARK: - Step 2 · Paste Mode

private struct PasteModeStep: View {
    let onNext: () -> Void

    @State private var appeared     = false
    @State private var selectedMode = PasteMode.clipboard
    @State private var axGranted    = AXIsProcessTrusted()
    @State private var pollTimer:   Timer?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.accentColor)
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, 16)

            Text("Choose Paste Mode")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .opacity(appeared ? 1 : 0)

            Text("You can always change this in Settings.")
                .font(.system(size: 14, design: .default))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .opacity(appeared ? 1 : 0)

            // Mode cards
            VStack(spacing: 10) {
                PasteModeCard(
                    mode:        .clipboard,
                    selected:    selectedMode == .clipboard,
                    axGranted:   axGranted,
                    onSelect:    { selectedMode = .clipboard }
                )
                PasteModeCard(
                    mode:        .autoPaste,
                    selected:    selectedMode == .autoPaste,
                    axGranted:   axGranted,
                    onSelect:    {
                        if axGranted {
                            selectedMode = .autoPaste
                        } else {
                            openAccessibilitySettings()
                        }
                    }
                )
            }
            .padding(.top, 20)
            .opacity(appeared ? 1 : 0)

            Spacer()

            PillButton(title: "Continue", icon: "arrow.right") {
                PasteManager.shared.mode = selectedMode
                UserDefaults.standard.set(selectedMode.rawValue, forKey: "fm_pasteMode")
                onNext()
            }
            .opacity(appeared ? 1 : 0)
            .padding(.bottom, 56)
        }
        .padding(.horizontal, 48)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.05)) {
                appeared = true
            }
            startPolling()
        }
        .onDisappear { pollTimer?.invalidate() }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            axGranted = AXIsProcessTrusted()
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

private struct PasteModeCard: View {
    let mode:     PasteMode
    let selected: Bool
    let axGranted:Bool
    let onSelect: () -> Void

    private var needsPermission: Bool { mode == .autoPaste && !axGranted }

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? Color.accentColor : Color.primary.opacity(0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: mode == .clipboard ? "doc.on.clipboard" : "bolt.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(selected ? .white : .secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(mode.displayName)
                            .font(.system(size: 14, weight: .semibold, design: .default))
                        if mode == .clipboard {
                            Text("Recommended")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green.opacity(0.12)))
                        }
                        if needsPermission {
                            Text("Needs Accessibility")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange.opacity(0.12)))
                        }
                        if mode == .autoPaste && axGranted {
                            Text("Ready ✓")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green.opacity(0.12)))
                        }
                    }
                    Text(mode.description)
                        .font(.system(size: 12, design: .default))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? Color.accentColor : Color.primary.opacity(0.2))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selected ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.1),
                                    lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 3 · Launch at Login + Done

private struct LaunchStep: View {
    let onDone: () -> Void

    @State private var appeared      = false
    @State private var launchAtLogin = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Checkmark
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 90, height: 90)
                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.green)
            }
            .scaleEffect(appeared ? 1 : 0.4)
            .opacity(appeared ? 1 : 0)
            .padding(.bottom, 20)

            Text("You're All Set!")
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .opacity(appeared ? 1 : 0)

            Text("emoji.key lives in your menu bar and fires up with \(HotkeyManager.shared.displayString).")
                .font(.system(size: 14, design: .default))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)

            // Launch at login card
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor.opacity(0.10))
                            .frame(width: 36, height: 36)
                        Image(systemName: "sunrise.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open at Login")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                        Text("emoji.key starts automatically when you log in.")
                            .font(.system(size: 12, design: .default))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: launchAtLogin) { _, enabled in
                            if #available(macOS 13.0, *) {
                                try? enabled
                                    ? SMAppService.mainApp.register()
                                    : SMAppService.mainApp.unregister()
                            }
                        }
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.top, 28)
            .opacity(appeared ? 1 : 0)

            Spacer()

            PillButton(title: "Start Using emoji.key", icon: "bolt.fill", action: onDone)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .padding(.bottom, 56)
        }
        .padding(.horizontal, 52)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.05)) {
                appeared = true
            }
        }
    }
}

// MARK: - Shared Components (identical to v1)

struct PillButton: View {
    let title:  LocalizedStringKey
    let icon:   String
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.accentColor)
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity,
                            pressing: { isPressed = $0 }, perform: {})
    }
}

private struct StepDots: View {
    let current: Int
    let total:   Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.accentColor : Color.primary.opacity(0.2))
                    .frame(width: i == current ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: current)
            }
        }
    }
}

private struct OnboardingBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark
             ? Color(nsColor: NSColor(calibratedWhite: 0.12, alpha: 1))
             : Color(nsColor: NSColor(calibratedWhite: 0.97, alpha: 1)))
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.accentColor.opacity(scheme == .dark ? 0.07 : 0.05), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 300
            )
            .ignoresSafeArea()
        }
    }
}

private struct BlinkingCaret: View {
    @State private var visible = true
    var body: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(width: 2, height: 16)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}
