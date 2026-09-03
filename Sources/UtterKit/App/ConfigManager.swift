import Foundation

/// App-level configuration.
///
/// Utter runs entirely on this Mac: speech recognition uses the bundled Whisper
/// model and AI commands use Apple's on-device language model. There are no
/// accounts, endpoints, API keys, or credentials of any kind — so this type
/// deliberately holds nothing secret, and there is nothing to persist to disk.
final class ConfigManager {
    static let shared = ConfigManager()

    /// Marketing version, read from the bundle at launch.
    private(set) var appVersion: String = "1.1.55"

    private init() {}

    func load() {
        loadVersion()
        purgeLegacyCredentialStore()
        print("📋 Utter \(appVersion) — fully on-device, no network services configured")
    }

    private func loadVersion() {
        if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !bundleVersion.isEmpty {
            appVersion = bundleVersion
            return
        }
        // Running from a build directory rather than a bundle (development).
        let binaryPath = ProcessInfo.processInfo.arguments[0]
        let candidates = [
            URL(fileURLWithPath: binaryPath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(".version"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(".version"),
        ]
        for url in candidates {
            if let version = try? String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines), !version.isEmpty {
                appVersion = version
                return
            }
        }
    }

    /// Remove the credential store written by earlier versions of Utter, which
    /// kept AWS keys in plaintext. Runs once at launch so users upgrading from
    /// 2.0.14 or earlier stop carrying a secret the app no longer has any use for.
    ///
    /// Only the user-writable Application Support copy is deleted. Builds up to
    /// 2.0.14 also shipped a `.env` *inside the app bundle*, but the app must never
    /// write to (or delete from) its own bundle: any change to `Contents/` breaks
    /// the code signature and can silently revoke the app's TCC grants. That stale
    /// in-bundle `.env` is harmless — it holds nothing the current app reads — and
    /// it disappears on its own when the user replaces the old app with this one.
    private func purgeLegacyCredentialStore() {
        let fm = FileManager.default
        // Looked for under the *current* name, because `AppDirectory` renames the whole folder on
        // first launch — so a credential file that was in `AWSFlow/` has already moved into
        // `Utter/` by the time this runs.
        let legacy = AppDirectory.file("config.json")
        guard fm.fileExists(atPath: legacy.path) else { return }
        do {
            try fm.removeItem(at: legacy)
            print("🧹 Removed legacy credential file: \(legacy.lastPathComponent)")
        } catch {
            // Non-fatal: report rather than failing launch.
            print("⚠️ Could not remove \(legacy.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
