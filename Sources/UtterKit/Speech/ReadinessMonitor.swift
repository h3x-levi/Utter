import Foundation
import AVFoundation
import ApplicationServices

/// Centralized, cached readiness state for the Home panel and Settings.
///
/// The previous implementation computed each value inside `body` — `modelPresent`
/// stat'd the filesystem and `LocalAIEngine.availability` queried the system
/// model, several times per render, on a 1.5 s timer. That work landed in the
/// render path and made every animation stutter.
///
/// Here the expensive checks run off the main thread, publish only when a value
/// actually changes, and stop entirely while no view is observing.
@MainActor
final class ReadinessMonitor: ObservableObject {
    static let shared = ReadinessMonitor()

    @Published private(set) var micGranted = false
    @Published private(set) var axGranted = false
    @Published private(set) var modelPresent = false
    /// Screen Recording, needed only for meeting capture.
    ///
    /// Tracked here with the others so it can be shown in the Permissions card and
    /// on the onboarding checklist — a permission the app needs but never surfaces
    /// is one the user only discovers when a feature mysteriously fails.
    @Published private(set) var screenRecordingGranted = false
    @Published private(set) var aiState: LocalAIEngine.Availability = .unsupportedOS
    /// Mirrors the speech engine's load lifecycle so the UI can show progress
    /// during the first cold load rather than claiming to be ready.
    @Published var modelLoad: LocalWhisperProvider.LoadState = .idle

    private var timer: Timer?
    private var observerCount = 0
    /// The model is bundled and immutable at runtime, so one check per launch is
    /// enough — no reason to keep hitting the filesystem.
    private var modelChecked = false

    private init() {}

    /// Begin polling. Reference-counted so several views can observe safely.
    func startPolling() {
        observerCount += 1
        refresh()
        guard timer == nil else { return }
        // 2 s is plenty for "did the user just grant a permission in System
        // Settings", and it never coincides with an animation frame budget.
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopPolling() {
        observerCount = max(0, observerCount - 1)
        guard observerCount == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        // Cheap and main-thread-safe.
        let mic = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let ax = AXIsProcessTrusted()
        if mic != micGranted { micGranted = mic }
        if ax != axGranted {
            let wasDenied = !axGranted
            axGranted = ax
            // Re-register the global hotkeys the moment Accessibility is granted.
            //
            // `NSEvent.addGlobalMonitorForEvents` returns a non-nil token even when
            // the process is untrusted — the handler is simply never called. So a
            // monitor installed at launch without Accessibility is inert *forever*,
            // and nothing previously told `KeyMonitor` that the permission had
            // arrived. The hotkeys only started working after a relaunch, with no
            // hint that a relaunch was needed.
            //
            // This is the common path, not an edge case: the app replaces an older
            // copy, macOS invalidates the old TCC grant, the user re-grants — and
            // without this the app stays deaf until quit.
            if ax, wasDenied {
                NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
            }
        }

        // `CGPreflightScreenCaptureAccess` under the hood: a cheap check that does
        // not trigger the prompt, so polling it is safe.
        let screen = SystemAudioCapture.permissionState() == .granted
        if screen != screenRecordingGranted { screenRecordingGranted = screen }

        // Filesystem + system-model queries move off the main thread.
        let needsModelCheck = !modelChecked
        Task.detached(priority: .utility) {
            let model = needsModelCheck ? (LocalWhisperProvider.modelURL() != nil) : nil
            let ai = LocalAIEngine.availability
            await MainActor.run {
                if let model {
                    self.modelChecked = true
                    if model != self.modelPresent { self.modelPresent = model }
                }
                if ai != self.aiState { self.aiState = ai }
            }
        }
    }
}
