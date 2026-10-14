import ApplicationServices
import AppKit
import AVFoundation

/// Utter's one route to the Accessibility permission, and the only place the system's own
/// prompt is allowed to be raised.
///
/// The permission is asked for in two places - the onboarding step and the launch check - and
/// they used to raise the prompt independently, which produced the thing this type exists to
/// stop: `OnboardingView` called `AXIsProcessTrustedWithOptions([prompt: true])` *and* opened the
/// Accessibility pane, so one button press put macOS's "would like to control this computer …
/// Grant access in Privacy & Security settings" dialog **on top of the Privacy & Security
/// settings it had just opened**, telling the user to do the thing that had already been done for
/// them, while covering the toggle they needed to reach. The onboarding call also skipped the
/// launch check's once-only flag, so finishing onboarding could raise a second prompt.
///
/// The rule now: **the app either opens the pane or raises the system dialog, never both.**
/// Onboarding and Settings open the pane, because they have their own explanation on screen and a
/// deep link is more useful than a modal. The launch check may raise the dialog, once ever, for a
/// returning user who has no onboarding screen in front of them.
package enum AccessibilityPermission {

    /// Records that the user has been asked, because macOS exposes no way to find out.
    ///
    /// `UserDefaults`, deliberately not `UserData`: it must survive being read before any store
    /// has loaded, and it is a fact about this machine rather than a preference worth syncing.
    private static let askedKey = "hasRequestedAccessibility"

    /// Whether the permission is granted. Free, and never prompts.
    package static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Whether the user has already been asked, by either route.
    static var hasAsked: Bool { UserDefaults.standard.bool(forKey: askedKey) }

    /// Record an ask without raising the system dialog - for the routes that show their own
    /// explanation and open the pane themselves.
    static func markAsked() {
        UserDefaults.standard.set(true, forKey: askedKey)
    }

    /// Open the Accessibility pane in System Settings.
    ///
    /// Counts as having asked: the user has been shown exactly where the switch is, so the
    /// system's dialog afterwards would be a second ask for the same thing.
    package static func openSettingsPane() {
        markAsked()
        openPrivacyPane("Privacy_Accessibility")
    }

    /// System Settings at Privacy & Security, scrolled to `pane` ("Privacy_Microphone", "Privacy_ScreenCapture").
    package static func openPrivacyPane(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// macOS asks for the microphone only while undecided; after a denial the switch is in System Settings.
    package static func requestMicrophone(granted: @escaping @Sendable (Bool) -> Void = { _ in }) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined: AVCaptureDevice.requestAccess(for: .audio, completionHandler: granted)
        case .authorized: granted(true)
        default: openPrivacyPane("Privacy_Microphone")
        }
    }

    /// Raise the system's own permission dialog, at most once for the life of the install.
    ///
    /// `kAXTrustedCheckOptionPrompt: true` shows the dialog on *every* call, and this used to run
    /// at every launch - so the app nagged on startup forever, including after the user had
    /// declined. Returns whether the dialog was raised, so callers can log honestly.
    @discardableResult
    package static func promptOnce() -> Bool {
        // Already granted: nothing to ask for, and a granted permission must never re-prompt.
        guard !isTrusted else { return false }
        guard !hasAsked else { return false }
        markAsked()
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        return true
    }
}
