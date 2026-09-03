import SwiftUI
import AppKit

public struct SnapshotRenderer {
    @MainActor
    public static func renderAll(outputDir: String = "/Users/skynet/.gemini/antigravity/brain/5c44a918-5999-4a98-8d05-0dcb8d51bed8/snapshots") {
        let outURL = URL(fileURLWithPath: outputDir)
        try? FileManager.default.createDirectory(at: outURL, withIntermediateDirectories: true)
        print("📸 Rendering screen snapshots to \(outputDir)...")

        // 1. Login View
        render(ThemedRoot { LoginView { _ in } }, width: 700, height: 540, to: outURL.appendingPathComponent("01_login_screen.png"))

        // 2. Onboarding View
        render(ThemedRoot { OnboardingView { _ in } }, width: 700, height: 540, to: outURL.appendingPathComponent("02_onboarding_wizard.png"))

        // 3. Main Dashboard Flow (Home / Dictation)
        render(ThemedRoot {
            FlowContent()
                .background(Color(nsColor: .windowBackgroundColor))
        }, width: 700, height: 600, to: outURL.appendingPathComponent("03_main_dashboard.png"))

        // 4. Notes Studio
        render(ThemedRoot {
            NotesView()
                .background(Color(nsColor: .windowBackgroundColor))
        }, width: 800, height: 600, to: outURL.appendingPathComponent("04_notes_studio.png"))

        // 5. Companion Studio
        render(ThemedRoot {
            ScrollView {
                CompanionSettingsContent()
                    .padding(24)
            }
            .frame(width: 750, height: 600)
            .background(Color(nsColor: .windowBackgroundColor))
        }, width: 750, height: 600, to: outURL.appendingPathComponent("05_companion_studio.png"))

        render(ThemedRoot {
            CompanionCustomizeView()
                .padding(24)
                .frame(width: 750, height: 650)
                .background(Color(nsColor: .windowBackgroundColor))
        }, width: 750, height: 650, to: outURL.appendingPathComponent("05b_companion_customize.png"))

        // 6. Model Chooser View
        render(ThemedRoot {
            VStack {
                ModelChooserView()
                    .padding(24)
            }
            .frame(width: 700, height: 620)
            .background(Color(nsColor: .windowBackgroundColor))
        }, width: 700, height: 620, to: outURL.appendingPathComponent("06_model_chooser.png"))

        // 7. Diagnostics Telemetry View
        render(ThemedRoot {
            ScrollView {
                DiagnosticsSettingsContent()
                    .padding(24)
            }
            .frame(width: 700, height: 620)
            .background(Color(nsColor: .windowBackgroundColor))
        }, width: 700, height: 620, to: outURL.appendingPathComponent("07_diagnostics_telemetry.png"))

        // 8. Custom Dictionary View
        render(ThemedRoot {
            VStack {
                DictionaryView()
                    .padding(24)
            }
            .frame(width: 700, height: 500)
            .background(Color(nsColor: .windowBackgroundColor))
        }, width: 700, height: 500, to: outURL.appendingPathComponent("08_dictionary_studio.png"))

        // 9. Snippets View
        render(ThemedRoot {
            VStack {
                SnippetsView()
                    .padding(24)
            }
            .frame(width: 700, height: 550)
            .background(Color(nsColor: .windowBackgroundColor))
        }, width: 700, height: 550, to: outURL.appendingPathComponent("09_snippets_studio.png"))

        // 10. Transforms (Custom AI Commands)
        render(ThemedRoot {
            ScrollView {
                StyleView()
                    .padding(24)
            }
            .frame(width: 700, height: 600)
            .background(Color(nsColor: .windowBackgroundColor))
        }, width: 700, height: 600, to: outURL.appendingPathComponent("10_transforms_hub.png"))

        // 11. General Settings
        render(ThemedRoot {
            GeneralSettingsContent()
                .frame(width: 650, height: 900)
                .background(Color(nsColor: .windowBackgroundColor))
        }, width: 650, height: 900, to: outURL.appendingPathComponent("11_general_settings.png"))

        print("✅ Finished rendering all snapshots.")
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
