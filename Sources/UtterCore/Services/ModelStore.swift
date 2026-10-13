import Foundation
import Combine
import CryptoKit
import os

/// Downloads and tracks the optional speech models.
///
/// The `small.en` model ships inside the app bundle, so Utter always works with
/// no network at all. Anything else is an explicit, user-initiated download  - 
/// this is the one place the app touches the network, and only when asked.
@MainActor
package final class ModelStore: ObservableObject {
    package static let shared = ModelStore()

    package enum State: Equatable {
        case bundled                 // ships with the app
        case notDownloaded
        case downloading(Double)     // 0...1
        case installed
        case failed(String)
    }

    @Published package private(set) var states: [SpeechModel.Tier: State] = [:]
    /// The tier currently selected for transcription.
    @Published package private(set) var active: SpeechModel.Tier

    private var tasks: [SpeechModel.Tier: URLSessionDownloadTask] = [:]
    private var observers: [SpeechModel.Tier: NSKeyValueObservation] = [:]
    private var downloadIDs: [SpeechModel.Tier: UUID] = [:]

    private static let activeKey = "selectedSpeechModel"
    nonisolated private static let purgedKey = "purgedBundledModels"

    /// Bundled tiers the user chose to delete, so they stay hidden.
    nonisolated static var purgedBundledTiers: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: purgedKey) ?? [])
    }

    private init() {
        // On first run pick what suits this Mac. Both `small` and `medium` are
        // bundled, so the recommendation is usually available immediately - fall
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

    /// Downloaded models live in Application Support, not the bundle - the bundle
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

    package func state(for tier: SpeechModel.Tier) -> State {
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
    package func select(_ tier: SpeechModel.Tier) {
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
    @Published package private(set) var pendingSelection: SpeechModel.Tier?

    // MARK: - Download

    package func download(_ tier: SpeechModel.Tier) {
        guard !SpeechModel.isBundled(tier), tasks[tier] == nil else { return }
        let model = SpeechModel.model(for: tier)
        // Pin the repository snapshot as well as the artifact digest. A changed
        // upstream `main` can no longer silently change what this app installs.
        guard let remote = URL(
            string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/0b364b566045a405be7225ee1e415a073e04da77/\(model.filename)"
        ) else {
            states[tier] = .failed("Bad download address")
            return
        }

        states[tier] = .downloading(0)
        let destination = Self.downloadDirectory.appendingPathComponent(model.filename)
        let filename = model.filename
        let expectedBytes = model.sizeMB * 1_048_576
        let expectedSHA256 = model.sha256
        let downloadID = UUID()
        downloadIDs[tier] = downloadID

        let task = URLSession.shared.downloadTask(with: remote) { [weak self] temp, response, error in
            // Hashing 500+ MB on MainActor would freeze the menu-bar UI. URLSession
            // invokes this completion off the main actor, so verify the temporary
            // file here and hop to MainActor only for observable state changes.
            var stagedFile: URL?
            let validationFailure: String?
            if let error {
                validationFailure = error.localizedDescription
            } else if (response as? HTTPURLResponse)?.statusCode != 200 {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                validationFailure = "Download failed (HTTP \(code))"
            } else if let temp {
                do {
                    stagedFile = try Self.verifyAndStage(
                        temp,
                        expectedBytes: expectedBytes,
                        expectedSHA256: expectedSHA256,
                        filename: filename
                    )
                    validationFailure = nil
                } catch {
                    validationFailure = error.localizedDescription
                }
            } else {
                validationFailure = "Download failed (no file received)"
            }

            Task { @MainActor in
                guard let self else {
                    if let stagedFile { try? FileManager.default.removeItem(at: stagedFile) }
                    return
                }
                guard self.downloadIDs[tier] == downloadID,
                      case .downloading = self.state(for: tier) else {
                    if let stagedFile { try? FileManager.default.removeItem(at: stagedFile) }
                    return
                }
                self.downloadIDs[tier] = nil
                self.tasks[tier] = nil
                self.observers[tier] = nil

                if let validationFailure {
                    self.states[tier] = .failed(validationFailure)
                    return
                }
                guard let stagedFile else {
                    self.states[tier] = .failed("Download failed (no verified file received)")
                    return
                }
                do {
                    defer { try? FileManager.default.removeItem(at: stagedFile) }
                    if FileManager.default.fileExists(atPath: destination.path) {
                        _ = try FileManager.default.replaceItemAt(destination, withItemAt: stagedFile)
                    } else {
                        try FileManager.default.moveItem(at: stagedFile, to: destination)
                    }
                    self.states[tier] = .installed
                    // The user chose this model before it existed; honour that now.
                    if self.pendingSelection == tier { self.select(tier) }
                } catch {
                    self.states[tier] = .failed(error.localizedDescription)
                }
            }
        }

        let throttle = OSAllocatedUnfairLock(initialState: ProgressThrottle())
        observers[tier] = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            let fraction = progress.fractionCompleted
            let now = ProcessInfo.processInfo.systemUptime
            guard throttle.withLock({ $0.shouldSend(fraction, at: now) }) else { return }
            Task { @MainActor in
                guard let self,
                      self.downloadIDs[tier] == downloadID,
                      case .downloading = self.state(for: tier) else { return }
                self.states[tier] = .downloading(fraction)
            }
        }

        tasks[tier] = task
        task.resume()
    }

    /// At most one progress update per `interval`; 100% always passes. Failures and completion
    /// come through the download's completion handler, which is not throttled.
    struct ProgressThrottle {
        let interval: TimeInterval = 0.1
        private var lastSent = -TimeInterval.infinity

        mutating func shouldSend(_ fraction: Double, at now: TimeInterval) -> Bool {
            guard fraction >= 1 || now - lastSent >= interval else { return false }
            lastSent = now
            return true
        }
    }

    private nonisolated static func sha256(fileAt url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var hasher = SHA256()
        while let chunk = try file.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func verifyAndStage(
        _ temporaryFile: URL,
        expectedBytes: Int,
        expectedSHA256: String,
        filename: String
    ) throws -> URL {
        let size = (try temporaryFile.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size >= expectedBytes / 2 else { throw ModelDownloadError.incomplete }
        guard try sha256(fileAt: temporaryFile) == expectedSHA256 else {
            throw ModelDownloadError.checksumMismatch
        }
        try FileManager.default.createDirectory(
            at: downloadDirectory,
            withIntermediateDirectories: true
        )
        let staged = downloadDirectory.appendingPathComponent(
            ".\(filename).\(UUID().uuidString).download"
        )
        try FileManager.default.moveItem(at: temporaryFile, to: staged)
        return staged
    }

    package func cancelDownload(_ tier: SpeechModel.Tier) {
        if pendingSelection == tier { pendingSelection = nil }
        downloadIDs[tier] = nil
        tasks[tier]?.cancel()
        tasks[tier] = nil
        observers[tier] = nil
        states[tier] = .notDownloaded
    }

    /// Whether a model can be removed right now.
    ///
    /// Anything downloaded can go. The bundled model can go too - it's 181 MB of
    /// dead weight once you've downloaded a better one - but only while another
    /// model is available, so the app is never left unable to transcribe.
    package func canRemove(_ tier: SpeechModel.Tier) -> Bool {
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
    /// preference (`purgedKey`) that hides it - the ~181 MB stays on disk but no
    /// longer loads or lists. A reinstall or update clears the preference so the
    /// user isn't left with a model they can't see.
    package func remove(_ tier: SpeechModel.Tier) {
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
    package static let speechModelChanged = Notification.Name("speechModelChanged")
}

private enum ModelDownloadError: LocalizedError {
    case incomplete
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .incomplete: "The downloaded model is incomplete. Try again."
        case .checksumMismatch: "The downloaded model failed its integrity check."
        }
    }
}
