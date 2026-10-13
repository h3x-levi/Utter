import Foundation
import Testing
@testable import UtterKit
@testable import UtterCore

@Suite("App identity and data directory")
struct AppIdentityTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func plist(_ relativePath: String) throws -> [String: Any] {
        let data = try Data(contentsOf: root.appendingPathComponent(relativePath))
        return try #require(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
    }

    @Test("The data folder name and its legacy names, in order, are pinned")
    func appDirectoryNames() {
        #expect(AppDirectory.name == "Utter")
        #expect(AppDirectory.legacyNames == ["Lumen", "AWSFlow"])
        #expect(AppDirectory.legacySupportDirectories.map(\.lastPathComponent) == ["Lumen", "AWSFlow"])
    }

    @Test("Info.plist keeps the bundle id and the keys the permission flows depend on")
    func infoPlistKeys() throws {
        let info = try plist("Utter/Info.plist")
        #expect(info["CFBundleIdentifier"] as? String == "utter.dictation.app")
        #expect(info["LSUIElement"] as? Bool == true)
        #expect(info["LSMinimumSystemVersion"] as? String == "14.0")
        for key in ["NSMicrophoneUsageDescription", "NSAudioCaptureUsageDescription"] {
            #expect((info[key] as? String)?.isEmpty == false)
        }
    }

    @Test("The audio-input entitlement is present")
    func entitlements() throws {
        let entitlements = try plist("Utter/Utter.entitlements")
        #expect(entitlements["com.apple.security.device.audio-input"] as? Bool == true)
    }

    @Test("UtterCore never imports SwiftUI")
    func coreHasNoSwiftUI() throws {
        let core = root.appendingPathComponent("Sources/UtterCore")
        let files = try #require(FileManager.default.enumerator(at: core, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty)
        for file in files {
            let imports = try String(contentsOf: file, encoding: .utf8).split(separator: "\n")
                .filter { $0.contains("import ") && $0.contains("SwiftUI") }
            #expect(imports.isEmpty, "\(file.lastPathComponent) imports SwiftUI")
        }
    }
}
