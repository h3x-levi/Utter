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
        print("📸 Rendering screen snapshots to \(outputDir)...")

        func renderToTargets<V: View>(_ view: V, width: CGFloat, height: CGFloat, names: [String]) {
            for dir in targets {
                for name in names {
                    render(view, width: width, height: height, to: dir.appendingPathComponent(name))
                }
            }
        }

        // 1. Hero Main Window (Home Dashboard)
        print("Rendering 1. Hero Main...")
        renderToTargets(ThemedRoot {
            FlowContent()
                .background(Color(nsColor: .windowBackgroundColor))
        }, width: 780, height: 620, names: ["hero-main.png", "03_main_dashboard.png"])

        // 2. Notes Studio
        print("Rendering 2. Notes Studio...")
        renderToTargets(ThemedRoot {
            NotesView()
                .background(Color(nsColor: .windowBackgroundColor))
        }, width: 800, height: 600, names: ["feature-notes.png", "04_notes_studio.png"])

        // 3. AI Voice Transforms
        print("Rendering 3. AI Voice Transforms...")
        renderToTargets(ThemedRoot {
            ScrollView {
                StyleView()
                    .padding(24)
            }
            .frame(width: 740, height: 620)
            .background(Color(nsColor: .windowBackgroundColor))
        }, width: 740, height: 620, names: ["feature-transforms.png", "10_transforms_hub.png"])

        // 4. Custom Dictionary
        print("Rendering 4. Custom Dictionary...")
        renderToTargets(ThemedRoot {
            VStack {
                DictionaryView()
                    .padding(24)
            }
            .frame(width: 720, height: 520)
            .background(Color(nsColor: .windowBackgroundColor))
        }, width: 720, height: 520, names: ["feature-dictionary.png", "08_dictionary_studio.png"])

        // 5. Snippets Studio
        print("Rendering 5. Snippets Studio...")
        renderToTargets(ThemedRoot {
            VStack {
                SnippetsView()
                    .padding(24)
            }
            .frame(width: 720, height: 560)
            .background(Color(nsColor: .windowBackgroundColor))
        }, width: 720, height: 560, names: ["feature-snippets.png", "09_snippets_studio.png"])

        // 6. Speech Models Chooser
        print("Rendering 6. Speech Models Chooser...")
        renderToTargets(ThemedRoot {
            VStack {
                ModelChooserView()
                    .padding(24)
            }
            .frame(width: 720, height: 620)
            .background(Color(nsColor: .windowBackgroundColor))
        }, width: 720, height: 620, names: ["feature-speech-models.png", "06_model_chooser.png"])

        // 7. General Settings & Themes
        print("Rendering 7. General Settings & Themes...")
        renderToTargets(ThemedRoot {
            GeneralSettingsContent()
                .frame(width: 680, height: 920)
                .background(Color(nsColor: .windowBackgroundColor))
        }, width: 680, height: 920, names: ["feature-settings-general.png", "11_general_settings.png"])

        // 8. Companion Studio & Customizer
        print("Rendering 8. Companion Studio...")
        renderToTargets(ThemedRoot {
            CompanionCustomizeView()
                .padding(24)
                .frame(width: 760, height: 650)
                .background(Color(nsColor: .windowBackgroundColor))
        }, width: 760, height: 650, names: ["feature-companion.png", "05b_companion_customize.png"])

        // 9. Articulated Quadruped Companion Showcase Card
        print("Rendering 9. Articulated Companion Showcase...")
        renderToTargets(ThemedRoot {
            CompanionShowcaseSnapshotView()
        }, width: 840, height: 420, names: ["feature-companion-showcase.png"])

        // 10. Dynamic Pill Lineup
        print("Rendering 10. Dynamic Pill Lineup...")
        renderToTargets(ThemedRoot {
            PillLineupSnapshotView()
        }, width: 840, height: 380, names: ["feature-pill-lineup.png"])

        // 11. Login Screen
        print("Rendering 11. Login Screen...")
        renderToTargets(ThemedRoot {
            LoginView { _ in }
        }, width: 700, height: 540, names: ["01_login_screen.png"])

        // 12. Onboarding Wizard
        print("Rendering 12. Onboarding Wizard...")
        renderToTargets(ThemedRoot {
            OnboardingView { _ in }
        }, width: 700, height: 540, names: ["02_onboarding_wizard.png"])

        // 13. Diagnostics Telemetry
        print("Rendering 13. Diagnostics Telemetry...")
        renderToTargets(ThemedRoot {
            ScrollView {
                DiagnosticsSettingsContent()
                    .padding(24)
            }
            .frame(width: 720, height: 620)
            .background(Color(nsColor: .windowBackgroundColor))
        }, width: 720, height: 620, names: ["07_diagnostics_telemetry.png"])

        print("✅ Finished rendering all snapshots to all targets.")
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

// MARK: - Dedicated Snapshot Showcase Views

struct CompanionShowcaseSnapshotView: View {
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("Articulated Quadruped Desktop Pets")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Full 4-limb anatomy, realistic walk cycles, biscuit kneading & interactive gestures")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.65))
                }

                HStack(spacing: 20) {
                    // Cat
                    CompanionCard(
                        title: "Pixel Cat",
                        subtitle: "Tabby Gray · Kneading",
                        tag: "WALK & KNEAD",
                        color: Tint.accent
                    ) {
                        CodePixelCatView(
                            style: .gray,
                            mood: .alert,
                            pose: CompanionPose(gait: .walking, travelSpeed: 1.0),
                            size: 110,
                            elapsed: 0.8
                        )
                    }

                    // Dog (Corgi)
                    CompanionCard(
                        title: "Pixel Dog",
                        subtitle: "Corgi · Joyful Wag",
                        tag: "4-LEG GAIT",
                        color: Color.orange
                    ) {
                        CodePixelCatView(
                            style: .dog,
                            mood: .delighted,
                            pose: CompanionPose(gait: .walking, travelSpeed: 1.2),
                            size: 110,
                            elapsed: 1.2
                        )
                    }

                    // Panda
                    CompanionCard(
                        title: "Pixel Panda",
                        subtitle: "Panda Cub · Thinking",
                        tag: "CHIN SCRATCH",
                        color: Color.green
                    ) {
                        CodePixelCatView(
                            style: .panda,
                            mood: .thinking,
                            pose: CompanionPose(gait: .idle, travelSpeed: 0.0),
                            size: 110,
                            elapsed: 0.4
                        )
                    }
                }
            }
            .padding(32)
        }
    }
}

private struct CompanionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let tag: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 120, height: 120)
                content()
            }
            .frame(height: 130)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.6))
            }

            Text(tag)
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
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct PillLineupSnapshotView: View {
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text("Liquid Glass Floating Pill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Non-intrusive HUD with real-time waveform metering and smooth state morphing")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.65))
                }

                HStack(spacing: 24) {
                    // 1. Resting Pill
                    PillStateItem(label: "Resting") {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Tint.accent)
                                .frame(width: 8, height: 8)
                            Text("Hold Fn")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }

                    // 2. Recording
                    PillStateItem(label: "Recording") {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("Listening...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                            HStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 1).fill(Color.red).frame(width: 2, height: 6)
                                RoundedRectangle(cornerRadius: 1).fill(Color.red).frame(width: 2, height: 14)
                                RoundedRectangle(cornerRadius: 1).fill(Color.red).frame(width: 2, height: 18)
                                RoundedRectangle(cornerRadius: 1).fill(Color.red).frame(width: 2, height: 10)
                                RoundedRectangle(cornerRadius: 1).fill(Color.red).frame(width: 2, height: 4)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.red.opacity(0.4), lineWidth: 1))
                    }

                    // 3. Hands Free
                    PillStateItem(label: "Hands-Free") {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.green)
                            Text("Latched (⌃⌥Space)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.green.opacity(0.4), lineWidth: 1))
                    }

                    // 4. Processing
                    PillStateItem(label: "Transcribing") {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Tint.accent)
                                .frame(width: 8, height: 8)
                            Text("Local Whisper...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Tint.accent.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Tint.accent.opacity(0.4), lineWidth: 1))
                    }
                }
            }
            .padding(32)
        }
    }
}

private struct PillStateItem<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 12) {
            content()
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.5))
        }
    }
}

