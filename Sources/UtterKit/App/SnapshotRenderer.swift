import SwiftUI
import AppKit

public struct SnapshotRenderer {
    @MainActor
    public static func renderAll(outputDir: String? = nil) {
        if !SnapshotPreviewMode.isActive {
            SnapshotPreviewMode.enable()
        }
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // App
            .deletingLastPathComponent() // UtterKit
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // repository root
        let primaryOutput = outputDir.map(URL.init(fileURLWithPath:))
            ?? projectRoot.appendingPathComponent("Assets/screenshots", isDirectory: true)
        let targets = [
            primaryOutput.standardizedFileURL,
            projectRoot.appendingPathComponent("docs/assets/screenshots", isDirectory: true)
        ].reduce(into: [URL]()) { result, url in
            if !result.contains(url) { result.append(url) }
        }
        for dir in targets {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        print("📸 Rendering full Mac screen snapshots to \(primaryOutput.path)...")

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
                windowTitle: "Utter - Voice Workspace",
                windowWidth: 1140,
                windowHeight: 700,
                showPill: true,
                pillState: .idle,
                companionStyle: .gray,
                companionMood: .alert,
                companionPose: CompanionPose(gait: .walking, travelSpeed: 1.0)
            ) {
                HStack(spacing: 0) {
                    WorkspaceSidebarSnapshot()
                        .frame(width: 180)
                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 1)
                    FlowContent()
                }
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
                windowTitle: "Utter Notes - Meeting Transcription & AI Notebook",
                windowWidth: 920,
                windowHeight: 640,
                showPill: true,
                pillState: .recording,
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
                windowTitle: "Utter Transforms - Apple Intelligence AI Actions",
                windowWidth: 860,
                windowHeight: 640,
                showPill: true,
                pillState: .processing(.transcribing),
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
                windowTitle: "Utter - Speech Model Catalog",
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
                windowTitle: "Utter - Custom Vocabulary & Snippets",
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
                windowTitle: "Utter - Voice Snippets Studio",
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
                windowTitle: "Utter Settings - Appearance & Shortcuts",
                windowWidth: 960,
                windowHeight: 700,
                showPill: false
            ) {
                HStack(spacing: 0) {
                    SettingsSidebarSnapshot()
                        .frame(width: 176)
                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 1)
                    SettingsDetail()
                }
            }
        }, width: screenWidth, height: screenHeight, names: ["feature-settings-general.png", "11_general_settings.png"])

        // 8. Articulated Quadruped Companion Showcase on Mac Desktop
        print("Rendering 9. Articulated Companion Showcase on Mac Desktop...")
        renderToTargets(ThemedRoot {
            MacCompanionShowcaseDesktopView()
        }, width: screenWidth, height: screenHeight, names: ["feature-companion-showcase.png", "feature-companion.png", "05b_companion_customize.png"])

        // 9. First-run introduction and essential setup states
        print("Rendering 10. First-run introduction on Mac Desktop...")
        renderToTargets(ThemedRoot {
            MacScreenContainer(
                windowTitle: "Welcome to Utter",
                windowWidth: 720,
                windowHeight: 560,
                showPill: false
            ) {
                OnboardingView(onFinish: { _ in }, previewStep: 0)
            }
        }, width: screenWidth, height: screenHeight, names: ["01_first_run.png"])

        print("Rendering 11. Required-access setup on Mac Desktop...")
        renderToTargets(ThemedRoot {
            MacScreenContainer(
                windowTitle: "Set up dictation",
                windowWidth: 720,
                windowHeight: 560,
                showPill: false
            ) {
                OnboardingView(onFinish: { _ in }, previewStep: 1)
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

// MARK: - Snapshot navigation

/// NSHostingView is not attached to a window in the snapshot tool, so SwiftUI's
/// AppKit-backed `List` rows do not receive their normal table-view lifecycle.
/// These static rows represent the same labels and grouping in marketing previews;
/// the running app continues to use the real `.sidebar` Lists above.
private struct WorkspaceSidebarSnapshot: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "waveform")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Utter").font(.system(size: 15, weight: .semibold))
                    Text("Private voice workspace").font(.system(size: 10))
                        .foregroundStyle(Ink.secondary)
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 16)
            .padding(.bottom, 22)

            ForEach(SidebarItem.primary) { item in
                HStack(spacing: 9) {
                    Image(systemName: item.icon)
                        .frame(width: 17)
                        .foregroundStyle(item == .capture ? Color.accentColor : Ink.secondary)
                    Text(item.rawValue)
                        .font(.system(size: 12, weight: item == .capture ? .semibold : .regular))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 9)
                .frame(height: 27)
                .background {
                    if item == .capture {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.14))
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 12)
            Text("\(TranscriptionHistory.shared.totalWords) words dictated")
                .font(.system(size: 10))
                .foregroundStyle(Ink.secondary)
                .padding(.horizontal, 15)
                .padding(.bottom, 13)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.5))
    }
}

private struct SettingsSidebarSnapshot: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Utter").font(.system(size: 14, weight: .semibold))
                    Text("Preferences").font(.system(size: 10))
                        .foregroundStyle(Ink.secondary)
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 17)
            .padding(.bottom, 22)
            group("Experience", items: SettingsGroup.settingsGroup)
            group("Trust & support", items: SettingsGroup.aboutGroup)
            Spacer(minLength: 16)
            Text("Utter \(ConfigManager.shared.appVersion)")
                .font(.system(size: 10))
                .foregroundStyle(Ink.secondary)
                .padding(14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.5))
    }

    private func group(_ title: String, items: [SettingsGroup]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Ink.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
            ForEach(items) { item in
                HStack(spacing: 9) {
                    Image(systemName: item.icon)
                        .frame(width: 17)
                        .foregroundStyle(item == .general ? Color.accentColor : Ink.secondary)
                    Text(item.title)
                        .font(.system(size: 12, weight: item == .general ? .semibold : .regular))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 9)
                .frame(height: 27)
                .background {
                    if item == .general {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.14))
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.bottom, 8)
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

                // Bottom Floating Pill and Companion (100% Real Pill, NO text)
                if showPill {
                    HStack(alignment: .bottom, spacing: 14) {
                        RealPillSnapshotView(state: pillState)

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
            windowTitle: "main.swift - Utter Project",
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
                        Text("Swift 5  Local Whisper")
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
                        codeLine("        // Local inference; Metal is requested where supported", num: "7", comment: true)
                        codeLine("        return await localWhisper.process(samples: pcmBuffer)", num: "8")
                        codeLine("    }", num: "9")
                        codeLine("}", num: "10")
                    }
                    Spacer()
                }
                .padding(24)

                // 4 Real Pill States Showcase floating directly in the workspace (NO TEXT in pills)
                VStack(spacing: 24) {
                    Text("Utter Liquid Glass Pill Lineup")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 28) {
                        // 1. Idle / Resting (Pure mic glyph)
                        PillCardWrapper(title: "Resting") {
                            RealPillSnapshotView(state: .idle)
                        }

                        // 2. Recording (Pure live waveform bars)
                        PillCardWrapper(title: "Recording") {
                            RealPillSnapshotView(state: .recording)
                        }

                        // 3. Hands-Free Latched (Waveform + Lock)
                        PillCardWrapper(title: "Hands-Free") {
                            RealPillSnapshotView(state: .handsFree)
                        }

                        // 4. Processing Phase (Writing pen)
                        PillCardWrapper(title: "Typing") {
                            RealPillSnapshotView(state: .processing(.typing))
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
        VStack(spacing: 12) {
            content()
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.65))
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Dedicated Articulated Companion Showcase on Mac Desktop

struct MacCompanionShowcaseDesktopView: View {
    var body: some View {
        MacScreenContainer(
            windowTitle: "Utter - Articulated Quadruped Desktop Pets",
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

// MARK: - Real Pill Snapshot Component (100% Genuine, Pure Glyphs & Waveform, NO TEXT)

struct RealPillSnapshotView: View {
    let state: PillState

    var body: some View {
        HStack(spacing: 8) {
            switch state {
            case .idle:
                // Real Resting Pill: Centered microphone glyph
                Image(systemName: "mic.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

            case .recording:
                // Real Recording Pill: 7 audio waveform bars dancing
                realWaveformBars(color: .white)

            case .handsFree:
                // Real Hands-Free Pill: Waveform bars + green lock icon
                HStack(spacing: 5) {
                    realWaveformBars(color: .white)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Tint.handsFree)
                }

            case .processing:
                // Real Processing / Typing Pill: Writing pen glyph
                Image(systemName: "pencil.and.scribble")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tint.accent)

            case .notice:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tint.accent)

            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tint.danger)

            default:
                Image(systemName: "mic.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, state == .idle ? 18 : 14)
        .frame(height: 28)
        .background(
            ZStack {
                Capsule()
                    .fill(Color.black.opacity(0.38))
                Capsule()
                    .fill(state == .handsFree ? Tint.handsFree.opacity(0.2) : Color.white.opacity(0.12))
            }
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.65), .white.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 4)
    }

    private func realWaveformBars(color: Color) -> some View {
        let barHeights: [CGFloat] = [5, 11, 16, 13, 18, 9, 6]
        return HStack(spacing: 2.5) {
            ForEach(0..<barHeights.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(color.opacity(0.85))
                    .frame(width: 3, height: barHeights[i])
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
            }
        }
        .frame(height: 20)
    }
}
