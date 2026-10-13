import Foundation

/// App-level configuration.
///
/// Utter runs entirely on this Mac: speech recognition uses the bundled Whisper
/// model and AI commands use Apple's on-device language model. There are no
/// accounts, endpoints, API keys, or credentials of any kind - so this type
/// deliberately holds nothing secret, and there is nothing to persist to disk.
package final class ConfigManager {
    package static let shared = ConfigManager()

    /// Marketing version, read from the bundle at launch.
    package private(set) var appVersion: String = "1.2.0"

    private init() {}

    package func load() {
        loadVersion()
        print("📋 Utter \(appVersion) - fully on-device, no network services configured")
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
}
