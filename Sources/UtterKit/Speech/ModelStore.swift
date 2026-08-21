import Foundation
import Combine

/// Downloads and tracks the optional speech models.
///
/// The `small.en` model ships inside the app bundle, so Utter always works with
/// no network at all. Anything else is an explicit, user-initiated download —
/// this is the one place the app touches the network, and only when asked.
@MainActor
final class ModelStore: ObservableObject {
    static let shared = ModelStore()

    enum State: Equatable {
        case bundled                 // ships with the app
        case notDownloaded
        case downloading(Double)     // 0...1
        case installed
        case failed(String)
    }

    @Published private(set) var states: [SpeechModel.Tier: State] = [:]
    /// The tier currently selected for transcription.
    @Published private(set) var active: SpeechModel.Tier

    private var tasks: [SpeechModel.Tier: URLSessionDownloadTask] = [:]
    private var observers: [SpeechModel.Tier: NSKeyValueObservation] = [:]

    private static let activeKey = "selectedSpeechModel"
    nonisolated private static let purgedKey = "purgedBundledModels"

    /// Bundled tiers the user chose to delete, so they stay hidden.
    nonisolated static var purgedBundledTiers: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: purgedKey) ?? [])
    }

    private init() {
        // On first run pick what suits this Mac. Both `small` and `medium` are
        // bundled, so the recommendation is usually available immediately — fall
        // back only if it somehow isn't on disk.
        if let stored = UserDefaults.standard.string(forKey: Self.activeKey),
           let tier = SpeechModel.Tier(rawValue: stored),
           Self.url(for: tier) != nil {
            active = tier
        } else {
            let suggested = Device.current().recommended.tier
            active = Self.url(for: suggested) != nil ? suggested : SpeechModel.fallback
            UserDefaults.standard.set(active.rawValue, forKey: Self.activeKey)
        }
        refreshStates()
    }

    // MARK: - Locations

    /// Downloaded models live in Application Support, not the bundle — the bundle
    /// is code-signed and read-only once installed.
    nonisolated static var downloadDirectory: URL {
        AppDirectory.subdirectory("Models")
    }

    /// Resolve a tier to a file on disk, or nil if it isn't available.
    ///
    /// Deliberately non-isolated: the transcription queue calls this off the main
    /// actor, and it only touches the filesystem.
    nonisolated static func url(for tier: SpeechModel.Tier) -> URL? {
        let model = SpeechModel.model(for: tier)
        if SpeechModel.isBundled(tier), !purgedBundledTiers.contains(tier.rawValue),
           let bundled = LocalWhisperProvider.bundledModelURL(named: model.filename) {
            return bundled
        }
        // A purged bundled model may also have been re-downloaded.
        let downloaded = downloadDirectory.appendingPathComponent(model.filename)
        return FileManager.default.fileExists(atPath: downloaded.path) ? downloaded : nil
    }

    func state(for tier: SpeechModel.Tier) -> State {
        states[tier] ?? .notDownloaded
    }

    private func refreshStates() {
        for model in SpeechModel.all {
            if SpeechModel.isBundled(model.tier), Self.url(for: model.tier) != nil {
                states[model.tier] = .bundled
            } else if Self.url(for: model.tier) != nil {
                states[model.tier] = .installed
            } else if case .downloading = states[model.tier] ?? .notDownloaded {
                // leave an in-flight download alone
            } else {
                states[model.tier] = .notDownloaded
            }
        }
    }

    // MARK: - Selection

    /// Choose a model.
    ///
    /// If it isn't on disk yet this starts the download and remembers the intent,
    /// so the model activates by itself once it finishes. Previously this bailed
    /// out silently for anything not already present, which made the larger
    /// models look unselectable.
    func select(_ tier: SpeechModel.Tier) {
        guard Self.url(for: tier) != nil else {
            pendingSelection = tier
            download(tier)
            return
        }
        pendingSelection = nil
        active = tier
        UserDefaults.standard.set(tier.rawValue, forKey: Self.activeKey)
        // The engine caches a loaded context, so it has to be rebuilt.
        NotificationCenter.default.post(name: .speechModelChanged, object: nil)
    }

    /// A model the user picked that still had to download first.
    @Published private(set) var pendingSelection: SpeechModel.Tier?

    // MARK: - Download

    func download(_ tier: SpeechModel.Tier) {
        guard !SpeechModel.isBundled(tier), tasks[tier] == nil else { return }
        let model = SpeechModel.model(for: tier)
        // SECURITY: `resolve/main` is a *mutable* ref — whatever `main` points at the
        // moment of download — and the file is validated only by the size heuristic
        // below before being handed to the in-process GGML parser. There is no
        // integrity check on the bytes. The fix is to pin an immutable revision
        // (`resolve/<commit-sha>/...`) and verify a per-model SHA-256 before
        // `moveItem`, exactly as `Package.swift` pins the whisper xcframework by
        // checksum. That is not done here because the expected hashes are not carried
        // in the model catalog; adding them (measured once from a trusted download)
        // is the outstanding work — do not invent them, and do not fetch them over
        // the same untrusted channel.
        guard let remote = URL(
            string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(model.filename)"
        ) else {
            states[tier] = .failed("Bad download address")
            return
        }

        states[tier] = .downloading(0)
        let destination = Self.downloadDirectory.appendingPathComponent(model.filename)

        let task = URLSession.shared.downloadTask(with: remote) { [weak self] temp, response, error in
            Task { @MainActor in
                guard let self else { return }
                self.tasks[tier] = nil
                self.observers[tier] = nil

                if let error {
                    self.states[tier] = .failed(error.localizedDescription)
                    return
                }
                guard let http = response as? HTTPURLResponse, http.statusCode == 200, let temp else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    self.states[tier] = .failed("Download failed (HTTP \(code))")
                    return
                }
                do {
                    // Sanity-check the size before trusting it: a captive-portal
                    // HTML page would otherwise be saved as a "model".
                    let size = (try temp.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    let expected = model.sizeMB * 1_048_576
                    guard Double(size) > Double(expected) * 0.5 else {
                        self.states[tier] = .failed("Download looks incomplete — try again")
                        return
                    }
                    try? FileManager.default.removeItem(at: destination)
                    try FileManager.default.moveItem(at: temp, to: destination)
                    self.states[tier] = .installed
                    // The user chose this model before it existed; honour that now.
                    if self.pendingSelection == tier { self.select(tier) }
                } catch {
                    self.states[tier] = .failed(error.localizedDescription)
                }
            }
        }

        observers[tier] = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor in
                guard let self, case .downloading = self.state(for: tier) else { return }
                self.states[tier] = .downloading(progress.fractionCompleted)
            }
        }

        tasks[tier] = task
        task.resume()
    }

    func cancelDownload(_ tier: SpeechModel.Tier) {
        if pendingSelection == tier { pendingSelection = nil }
        tasks[tier]?.cancel()
        tasks[tier] = nil
        observers[tier] = nil
        states[tier] = .notDownloaded
    }

    /// Whether a model can be removed right now.
    ///
    /// Anything downloaded can go. The bundled model can go too — it's 181 MB of
    /// dead weight once you've downloaded a better one — but only while another
    /// model is available, so the app is never left unable to transcribe.
    func canRemove(_ tier: SpeechModel.Tier) -> Bool {
        guard Self.url(for: tier) != nil else { return false }
        let others = SpeechModel.all
            .map(\.tier)
            .filter { $0 != tier && Self.url(for: $0) != nil }
        return !others.isEmpty
    }

    /// Delete a model to reclaim disk.
    ///
    /// For a downloaded model this removes the file from Application Support. The
    /// bundled model lives inside the signed app bundle, which the app must never
    /// write to: deleting a file from `Contents/Resources/` breaks the code
    /// signature and can silently revoke the app's TCC grants (Accessibility, mic,
    /// Screen Recording). So "removing" a bundled model is recorded purely as a
    /// preference (`purgedKey`) that hides it — the ~181 MB stays on disk but no
    /// longer loads or lists. A reinstall or update clears the preference so the
    /// user isn't left with a model they can't see.
    func remove(_ tier: SpeechModel.Tier) {
        guard canRemove(tier) else { return }
        let model = SpeechModel.model(for: tier)

        if SpeechModel.isBundled(tier) {
            var purged = Self.purgedBundledTiers
            purged.insert(tier.rawValue)
            UserDefaults.standard.set(Array(purged), forKey: Self.purgedKey)
            // Deliberately do NOT delete the bundled file: it is inside the signed
            // bundle, and a write there invalidates the signature. The preference
            // above hides it, which is all "remove" needs to do.
        } else {
            let path = Self.downloadDirectory.appendingPathComponent(model.filename)
            try? FileManager.default.removeItem(at: path)
        }

        // Move off it before it disappears from under the engine.
        if active == tier,
           let replacement = SpeechModel.all.map(\.tier).first(where: { $0 != tier && Self.url(for: $0) != nil }) {
            select(replacement)
        }
        states[tier] = .notDownloaded
    }
}

extension Notification.Name {
    /// Posted when the user switches speech models, so the engine reloads.
    static let speechModelChanged = Notification.Name("speechModelChanged")
}
