import SwiftUI
import AppKit

enum GlassSupport {
    /// True when the OS can render Liquid Glass at all.
    static var available: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }

    /// The one policy for whether glass is drawn: supported and not Reduce Transparency.
    /// Call sites still need their own `#available(macOS 26.0, *)` to name `glassEffect`.
    static func active(reduceTransparency: Bool) -> Bool {
        available && !reduceTransparency
    }
}

/// A live translucent backing so the glass chrome above it has something real to sample.
struct WindowBacking: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
