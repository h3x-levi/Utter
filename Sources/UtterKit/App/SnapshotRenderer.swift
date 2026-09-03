import SwiftUI
import AppKit

public struct SnapshotRenderer {
    @MainActor
    public static func renderAll(outputDir: String = "/Volumes/SSD/Utter/Assets/screenshots") {
        let targets = [
            URL(fileURLWithPath: outputDir),
            URL(fileURLWithPath: "/Volumes/SSD/Utter/docs/assets/screenshots"),
            URL(fileURLWithPath: "/Users/skynet/.gemini/antigravity/brain/5c44a918-5999-4a98-8d05-0dcb8d51bed8/snapshots")
        ]
        for dir in targets {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        print("📸 Rendering full Mac screen snapshots to \(outputDir)...")

        func renderToTargets<V: View>(_ view: V, width: CGFloat, height: CGFloat, names: [String]) {
            for dir in targets {
                for name in names {
                    render(view, width: width, height: height, to: dir.appendingPathComponent(name))
                }
            }
        }

        let screenWidth: CGFloat = 1440
        let screenHeight: CGFloat = 900

        // 1. Hero Main Window on Mac Desktop (with Floating Pill and Cat Companion)
        print("Rendering 1. Hero Main on Mac Desktop...")
        renderToTargets(ThemedRoot {
            MacScreenContainer(
                windowTitle: "Utter — Dictation Workspace",
                windowWidth: 880,
                windowHeight: 620,
                showPill: true,
                pillState: .idle,
                companionStyle: .gray,
                companionMood: .alert,
                companionPose: CompanionPose(gait: .walking, travelSpeed: 1.0)
            ) {
                FlowContent()
            }
        }, width: screenWidth, height: screenHeight, names: ["hero-main.png", "03_main_dashboard.png"])

        // 2. Real Pill Lineup on Mac Screen with Code Editor & Active Recording
        print("Rendering 2. Real Pill Showcase on Mac Desktop...")
        renderToTargets(ThemedRoot {
            MacPillShowcaseDesktopView()
        }, width: screenWidth, height: screenHeight, names: ["feature-pill-lineup.png"])

        // 3. Notes Studio on Mac Desktop
        print("Rendering 3. Notes Studio on Mac Desktop...")
        renderToTargets(ThemedRoot {
            MacScreenContainer(
                windowTitle: "Utter Notes — Meeting Transcription & AI Notebook",
                windowWidth: 920,
                windowHeight: 640,
                showPill: true,
                pillState: .capturingNote,
                companionStyle: .orange,
                companionMood: .alert,
                companionPose: CompanionPose(gait: .idle)
            ) {
                NotesView()
            }
        }, width: screenWidth, height: screenHeight, names: ["feature-notes.png", "04_notes_studio.png"])

        // 4. AI Voice Transforms on Mac Desktop
        print("Rendering 4. AI Voice Transforms on Mac Desktop...")
        renderToTargets(ThemedRoot {
            MacScreenContainer(
                windowTitle: "Utter Transforms — Apple Intelligence AI Actions",
                windowWidth: 860,
                windowHeight: 640,
                showPill: true,
                pillState: .processing(.rewriting),
                companionStyle: .panda,
                companionMood: .thinking,
                companionPose: CompanionPose(gait: .idle)
            ) {
                ScrollView {
                    StyleView()
                        .padding(24)
                }
            }
        }, width: screenWidth, height: screenHeight, names: ["feature-transforms.png", "10_transforms_hub.png"])

        // 5. Speech Models Chooser on Mac Desktop
        print("Rendering 5. Speech Models on Mac Desktop...")
        renderToTargets(ThemedRoot {
            MacScreenContainer(
                windowTitle: "Utter — Speech Model Catalog",
                windowWidth: 860,
                windowHeight: 640,
                showPill: false
            ) {
                VStack {
                    ModelChooserView()
                        .padding(24)
                }
            }
        }, width: screenWidth, height: screenHeight, names: ["feature-speech-models.png", "06_model_chooser.png"])

        // 6. Custom Dictionary & Snippets on Mac Desktop
        print("Rendering 6. Custom Dictionary on Mac Desktop...")
        renderToTargets(ThemedRoot {
            MacScreenContainer(
                windowTitle: "Utter — Custom Vocabulary & Snippets",
                windowWidth: 860,
                windowHeight: 580,
                showPill: false
            ) {
                VStack {
                    DictionaryView()
                        .padding(24)
                }
            }
        }, width: screenWidth, height: screenHeight, names: ["feature-dictionary.png", "08_dictionary_studio.png"])

        print("Rendering 7. Voice Snippets Studio on Mac Desktop...")
        renderToTargets(ThemedRoot {
            MacScreenContainer(
                windowTitle: "Utter — Voice Snippets Studio",
                windowWidth: 860,
                windowHeight: 600,
                showPill: false
            ) {
                VStack {
                    SnippetsView()
                        .padding(24)
                }
            }
        }, width: screenWidth, height: screenHeight, names: ["feature-snippets.png", "09_snippets_studio.png"])

        // 7. General Settings & Themes on Mac Desktop
        print("Rendering 8. Settings & Appearance on Mac Desktop...")
        renderToTargets(ThemedRoot {
            MacScreenContainer(
                windowTitle: "Utter Settings — Appearance & Shortcuts",
                windowWidth: 760,
                windowHeight: 680,
                showPill: false
            ) {
                ScrollView {
                    GeneralSettingsContent()
                        .padding(24)
                }
            }
        }, width: screenWidth, height: screenHeight, names: ["feature-settings-general.png", "11_general_settings.png"])

        // 8. Articulated Quadruped Companion Showcase on Mac Desktop
        print("Rendering 9. Articulated Companion Showcase on Mac Desktop...")
        renderToTargets(ThemedRoot {
            MacCompanionShowcaseDesktopView()
        }, width: screenWidth, height: screenHeight, names: ["feature-companion-showcase.png", "feature-companion.png", "05b_companion_customize.png"])

        // 9. Login Screen & Onboarding on Mac Desktop
        print("Rendering 10. Login Screen on Mac Desktop...")
        renderToTargets(ThemedRoot {
            MacScreenContainer(
                windowTitle: "Welcome to Utter",
                windowWidth: 720,
                windowHeight: 560,
                showPill: false
            ) {
                LoginView { _ in }
            }
        }, width: screenWidth, height: screenHeight, names: ["01_login_screen.png"])

        print("Rendering 11. Onboarding Wizard on Mac Desktop...")
        renderToTargets(ThemedRoot {
            MacScreenContainer(
                windowTitle: "Utter Setup Wizard",
                windowWidth: 720,
                windowHeight: 560,
                showPill: false
            ) {
                OnboardingView { _ in }
            }
        }, width: screenWidth, height: screenHeight, names: ["02_onboarding_wizard.png"])

        // 10. Diagnostics Telemetry
        print("Rendering 12. Diagnostics Telemetry on Mac Desktop...")
        renderToTargets(ThemedRoot {
            MacScreenContainer(
                windowTitle: "Utter Diagnostics & Zero-Network Telemetry",
                windowWidth: 840,
                windowHeight: 640,
                showPill: false
            ) {
                ScrollView {
                    DiagnosticsSettingsContent()
                        .padding(24)
                }
            }
        }, width: screenWidth, height: screenHeight, names: ["07_diagnostics_telemetry.png"])

        print("✅ Finished rendering all full-screen Mac snapshots.")
    }

    @MainActor
    private static func render<V: View>(_ view: V, width: CGFloat, height: CGFloat, to url: URL) {
        let hosting = NSHostingView(rootView: view.frame(width: width, height: height))
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        hosting.layoutSubtreeIfNeeded()

        guard let bitmapRep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            print("❌ Failed to create bitmap rep for \(url.lastPathComponent)")
            return
        }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmapRep)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("❌ Failed to get PNG data for \(url.lastPathComponent)")
            return
        }
        do {
            try pngData.write(to: url)
            print("  ✓ Rendered \(url.lastPathComponent)")
        } catch {
            print("❌ Write error: \(error)")
        }
    }
}

// MARK: - Mac Screen Desktop Frame & Wallpaper

struct MacScreenContainer<Content: View>: View {
    let windowTitle: String
    let windowWidth: CGFloat
    let windowHeight: CGFloat
    var showPill: Bool = true
    var pillState: PillState = .idle
    var pillLevel: Float = 0.6
    var pillElapsed: Int = 3
    var companionStyle: CodePixelCatStyle? = .gray
    var companionMood: CompanionMood = .alert
    var companionPose: CompanionPose = CompanionPose(gait: .walking, travelSpeed: 1.0)
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            // Authentic macOS Colorful Gradient Wallpaper
            macOSWallpaper

            VStack(spacing: 0) {
                // Top macOS Menu Bar
                macOSMenuBar

                Spacer()

                // Center macOS Window
                VStack(spacing: 0) {
                    // Window Titlebar with Traffic Lights
                    HStack(spacing: 8) {
                        HStack(spacing: 7) {
                            Circle().fill(Color(red: 1.0, green: 0.38, blue: 0.36)).frame(width: 12, height: 12)
                            Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 12, height: 12)
                            Circle().fill(Color(red: 0.15, green: 0.78, blue: 0.25)).frame(width: 12, height: 12)
                        }
                        .padding(.leading, 14)

                        Spacer()

                        Text(windowTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.85))

                        Spacer()

                        Color.clear.frame(width: 50, height: 12)
                    }
                    .frame(height: 38)
                    .background(Color(red: 0.13, green: 0.14, blue: 0.18).opacity(0.95))
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1),
                        alignment: .bottom
                    )

                    // Window Content
                    content()
                        .background(Color(red: 0.11, green: 0.12, blue: 0.15))
                }
                .frame(width: windowWidth, height: windowHeight)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 32, x: 0, y: 16)

                Spacer()

                // Bottom Floating Pill and Companion
                if showPill {
                    HStack(alignment: .bottom, spacing: 14) {
                        RealPillSnapshotView(state: pillState, level: pillLevel, elapsed: pillElapsed)

                        if let style = companionStyle {
                            CodePixelCatView(
                                style: style,
                                mood: companionMood,
                                pose: companionPose,
                                size: 54,
                                elapsed: 0.8
                            )
                            .offset(y: 4)
                        }
                    }
                    .padding(.bottom, 24)
                } else {
                    Color.clear.frame(height: 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var macOSWallpaper: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.22),
                    Color(red: 0.18, green: 0.14, blue: 0.32),
                    Color(red: 0.65, green: 0.25, blue: 0.28),
                    Color(red: 0.90, green: 0.52, blue: 0.20),
                    Color(red: 0.28, green: 0.58, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.indigo.opacity(0.35), Color.clear],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 700
            )

            RadialGradient(
                colors: [Color.orange.opacity(0.25), Color.clear],
                center: .bottomLeading,
                startRadius: 50,
                endRadius: 800
            )
        }
    }

    private var macOSMenuBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("").font(.system(size: 14, weight: .bold))
                Text("Utter").font(.system(size: 13, weight: .bold))
                Text("File").font(.system(size: 13))
                Text("Edit").font(.system(size: 13))
                Text("View").font(.system(size: 13))
                Text("Window").font(.system(size: 13))
                Text("Help").font(.system(size: 13))
            }
            .foregroundStyle(Color.white.opacity(0.9))

            Spacer()

            HStack(spacing: 14) {
                // Utter menu bar indicator
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                    Text("Utter")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.18))
                .clipShape(Capsule())

                Image(systemName: "wifi").font(.system(size: 12))
                Image(systemName: "battery.100").font(.system(size: 12))
                Image(systemName: "magnifyingglass").font(.system(size: 12))
                Image(systemName: "switch.2").font(.system(size: 12))
                Text("Thu Sep 3  12:45 PM").font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Color.white.opacity(0.9))
        }
        .padding(.horizontal, 16)
        .frame(height: 28)
        .background(Color.black.opacity(0.3))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Dedicated Real Pill Desktop Showcase

struct MacPillShowcaseDesktopView: View {
    var body: some View {
        MacScreenContainer(
            windowTitle: "main.swift — Utter Project",
            windowWidth: 920,
            windowHeight: 560,
            showPill: false
        ) {
            ZStack {
                // Background Code Editor Mockup
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Sources/UtterKit/Speech/TranscriptionService.swift")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.5))
                        Spacer()
                        Text("UTF-8  Swift 5.9  Metal CoreML")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    .padding(.bottom, 6)

                    VStack(alignment: .leading, spacing: 6) {
                        codeLine("import UtterKit", num: "1")
                        codeLine("import whisper", num: "2")
                        codeLine("", num: "3")
                        codeLine("public final class TranscriptionService {", num: "4")
                        codeLine("    private let whisperContext: OpaquePointer", num: "5")
                        codeLine("    public func transcribe(pcmBuffer: [Float]) async -> String {", num: "6")
                        codeLine("        // 100% on-device Metal accelerated local Whisper inference", num: "7", comment: true)
                        codeLine("        return await localWhisper.process(samples: pcmBuffer)", num: "8")
                        codeLine("    }", num: "9")
                        codeLine("}", num: "10")
                    }
                    Spacer()
                }
                .padding(24)

                // 4 Real Pill States Showcase floating directly in the workspace
                VStack(spacing: 24) {
                    Text("Utter Liquid Glass Pill Lineup")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 20) {
                        // 1. Idle / Resting
                        PillCardWrapper(title: "Idle (Resting)") {
                            RealPillSnapshotView(state: .idle, level: 0, elapsed: 0)
                        }

                        // 2. Recording (Held Hotkey)
                        PillCardWrapper(title: "Recording (Hold Fn)") {
                            RealPillSnapshotView(state: .recording, level: 0.72, elapsed: 4)
                        }

                        // 3. Hands-Free Latched
                        PillCardWrapper(title: "Hands-Free (⌃⌥Space)") {
                            RealPillSnapshotView(state: .handsFree, level: 0.55, elapsed: 14)
                        }

                        // 4. Processing
                        PillCardWrapper(title: "Processing Phase") {
                            RealPillSnapshotView(state: .processing(.transcribing), level: 0, elapsed: 0)
                        }
                    }

                    // Articulated Companion walking beside the pill
                    HStack(spacing: 12) {
                        CodePixelCatView(
                            style: .gray,
                            mood: .alert,
                            pose: CompanionPose(gait: .walking, travelSpeed: 1.0),
                            size: 60,
                            elapsed: 0.8
                        )
                        Text("Companion dynamically reacts to audio metering, speech flow and typing cadence")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .padding(28)
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
        }
    }

    private func codeLine(_ text: String, num: String, comment: Bool = false) -> some View {
        HStack(spacing: 16) {
            Text(num)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.25))
                .frame(width: 20, alignment: .trailing)
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(comment ? Color.green.opacity(0.7) : Color.white.opacity(0.85))
        }
    }
}

private struct PillCardWrapper<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 10) {
            content()
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.65))
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Dedicated Articulated Companion Showcase on Mac Desktop

struct MacCompanionShowcaseDesktopView: View {
    var body: some View {
        MacScreenContainer(
            windowTitle: "Utter — Articulated Quadruped Desktop Pets",
            windowWidth: 920,
            windowHeight: 600,
            showPill: false
        ) {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("4-Limb Articulated Vector Companions")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Quadruped walk cycles, biscuit kneading, thinking chin-scratches & celebration poses rendered at 60 FPS")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.7))
                }

                HStack(spacing: 24) {
                    // Pixel Cat
                    CompanionShowcaseTile(
                        name: "Pixel Cat (Tabby Gray)",
                        action: "Walking & Kneading Biscuits",
                        badge: "4-LEG GAIT",
                        color: Tint.accent
                    ) {
                        CodePixelCatView(
                            style: .gray,
                            mood: .alert,
                            pose: CompanionPose(gait: .walking, travelSpeed: 1.0),
                            size: 120,
                            elapsed: 0.8
                        )
                    }

                    // Pixel Dog
                    CompanionShowcaseTile(
                        name: "Pixel Dog (Corgi)",
                        action: "Joyful 4-Leg Gallop & Wag",
                        badge: "SINUSOIDAL SWAY",
                        color: Color.orange
                    ) {
                        CodePixelCatView(
                            style: .dog,
                            mood: .delighted,
                            pose: CompanionPose(gait: .walking, travelSpeed: 1.2),
                            size: 120,
                            elapsed: 1.2
                        )
                    }

                    // Pixel Panda
                    CompanionShowcaseTile(
                        name: "Pixel Panda (Cub)",
                        action: "Thinking Chin-Scratch Tap",
                        badge: "ARTICULATED ARMS",
                        color: Color.green
                    ) {
                        CodePixelCatView(
                            style: .panda,
                            mood: .thinking,
                            pose: CompanionPose(gait: .idle, travelSpeed: 0.0),
                            size: 120,
                            elapsed: 0.4
                        )
                    }
                }
            }
            .padding(32)
        }
    }
}

private struct CompanionShowcaseTile<Content: View>: View {
    let name: String
    let action: String
    let badge: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 140, height: 140)
                content()
            }
            .frame(height: 140)

            VStack(spacing: 4) {
                Text(name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(action)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.65))
            }

            Text(badge)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Real Pill Snapshot Component

struct RealPillSnapshotView: View {
    let state: PillState
    let level: Float
    let elapsed: Int

    var body: some View {
        HStack(spacing: 10) {
            switch state {
            case .idle:
                // Real Resting Pill: Keycap + Prompt
                KeycapChip(text: UserData.shared.hotkeyName)
                Text("Hold to talk")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))

            case .recording:
                // Real Recording Pill: Red Dot + Timer + Live RMS Meter
                Circle()
                    .fill(Color(red: 1.0, green: 0.28, blue: 0.25))
                    .frame(width: 8, height: 8)
                Text(timeString(elapsed))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                realAudioMeter(level: level)

            case .handsFree:
                // Real Hands Free Pill: Lock + Timer + Stop Control
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Tint.handsFree)
                Text(timeString(elapsed))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                realAudioMeter(level: level)

            case .capturingNote:
                // Real Note Capture Pill: Note glyph + Destination
                Image(systemName: "note.text")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Tint.accent)
                Text("Dictating into Note")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                realAudioMeter(level: level)

            case .processing(let phase):
                // Real Processing Pill
                ProgressView()
                    .controlSize(.mini)
                Text(phase.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tint.accent)

            default:
                KeycapChip(text: "Fn")
                Text("Utter")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 32)
        .background(
            Color(red: 0.12, green: 0.13, blue: 0.17).opacity(0.85)
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 4)
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func realAudioMeter(level: Float) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                let factor = Float(i + 1) / 5.0
                let height: CGFloat = level >= factor ? CGFloat(8 + i * 3) : 3
                RoundedRectangle(cornerRadius: 1)
                    .fill(state == .handsFree ? Tint.handsFree : Color(red: 1.0, green: 0.28, blue: 0.25))
                    .frame(width: 2, height: height)
            }
        }
    }
}

private struct KeycapChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.9))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
    }
}
