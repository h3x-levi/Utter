import SwiftUI

/// Loads and displays the custom Utter app icon.
/// Falls back to SF Symbol if the icon file isn't found.
struct AppIconView: View {
    let size: CGFloat

    private var iconImage: NSImage? {
        let binaryPath = ProcessInfo.processInfo.arguments[0]
        let candidates = [
            // .app bundle: Contents/Resources/AppIcon.icns
            URL(fileURLWithPath: binaryPath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources/AppIcon.icns"),
            // Dev: project root
            URL(fileURLWithPath: binaryPath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("AppIcon.icns"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("AppIcon.icns"),
        ]

        for url in candidates {
            if let img = NSImage(contentsOf: url) {
                return img
            }
        }
        return nil
    }

    var body: some View {
        if let nsImage = iconImage {
            // No clip shape.
            //
            // The .icns already carries its own rounded silhouette with
            // transparent corners (see scripts/generate_icon.py). Clipping again
            // shaved a second, *circular* radius off a squircle that was already
            // the right shape — visible as flattened corners at larger sizes.
            Image(nsImage: nsImage)
                .resizable()
                .frame(width: size, height: size)
        } else {
            // Fallback for a dev build with no .icns yet. `waveform` rather than
            // the old `lightbulb.fill`, which was drawn from the previous icon
            // design and no longer resembles the artwork.
            Image(systemName: "waveform")
                .font(.system(size: size * 0.62, weight: .medium))
                .foregroundStyle(Tint.accent)
                .frame(width: size, height: size)
                .background(Radius.rect(size * 0.22).fill(Surface.raised))
        }
    }
}
