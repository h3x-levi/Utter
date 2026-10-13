import SwiftUI
import AppKit

enum Space {
    static let x2: CGFloat = 8
    static let x3: CGFloat = 12
    static let x4: CGFloat = 16
}

enum Layout {
    static let windowMinWidth: CGFloat = 1000
    static let windowMinHeight: CGFloat = 680
    static let windowIdealWidth: CGFloat = 1380
    static let windowIdealHeight: CGFloat = 960

    /// Settings is the mock's 780 pt column; only its height follows the user.
    static let settingsMinWidth: CGFloat = 780
    static let settingsMinHeight: CGFloat = 420
    static let settingsIdealWidth: CGFloat = 780
    static let settingsIdealHeight: CGFloat = 700

    /// Onboarding is a fixed 700 x 520 window, so no step can resize it mid-flow.
    static let onboardingMinWidth: CGFloat = 700
    static let onboardingMinHeight: CGFloat = 520
    static let onboardingIdealWidth: CGFloat = 700
    static let onboardingIdealHeight: CGFloat = 520

    /// `setFrameUsingName` replays an autosaved frame without consulting `contentMinSize`,
    /// so a frame stored while the window was collapsed reopens collapsed.
    static func size(_ content: NSSize, atLeast minimum: NSSize) -> NSSize {
        NSSize(width: max(content.width, minimum.width),
               height: max(content.height, minimum.height))
    }
}

/// Tracks the system Reduce Motion and Reduce Transparency settings.
///
/// The pill lives in an `NSPanel` via `NSHostingView`, so SwiftUI environment
/// propagation isn't reliable there - read AppKit directly and observe changes.
final class MotionPreference: ObservableObject {
    static let shared = MotionPreference()

    @Published var reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    @Published var reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency

    private var observer: NSObjectProtocol?

    private init() {
        // `NSWorkspace.shared.notificationCenter`, not `NotificationCenter.default`.
        //
        // Every notification declared on NSWorkspace is posted to the workspace's own
        // centre, so registering on the default centre meant this observer never fired:
        // turning Reduce Motion or Reduce Transparency on had no effect until the app was
        // relaunched. The pill kept spring-morphing, the companion kept hopping, and glass
        // kept sampling the wallpaper - for exactly the users who had asked it not to.
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let workspace = NSWorkspace.shared
            self?.reduceMotion = workspace.accessibilityDisplayShouldReduceMotion
            self?.reduceTransparency = workspace.accessibilityDisplayShouldReduceTransparency
        }
    }
}
