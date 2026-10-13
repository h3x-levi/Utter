// swift-tools-version: 5.9
import PackageDescription

// Naming: everything is **Utter**, inside and out.
//
// The package, the executable, the bundle identifier and the log subsystem
// are all `Utter` / `utter.dictation.app`; `scripts/build-app.sh` derives the executable
// name and `CFBundleExecutable` from one variable so the bundle cannot point at a
// binary that is not there.
//
// `AppDirectory.legacyNames` (`Sources/UtterCore/Services/AppDirectory.swift`)
// migrates `Application Support/Lumen` into `Utter`.
let sdkStamp = LinkerSetting.unsafeFlags(["-Xlinker", "-platform_version", "-Xlinker", "macos",
                                           "-Xlinker", "14.0", "-Xlinker", "26.0"])

let package = Package(
    name: "Utter",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Swift Testing.
        //
        // Declared as a dependency rather than taken from the toolchain because this
        // machine has only the Command Line Tools, which ship neither `XCTest` nor a
        // built-in `Testing` module — both fail with "no such module". The package
        // build works on exactly this setup, which is what matters: the tests have to
        // run here, not only under a full Xcode.
        //
        // The compiler notes that Swift 6 bundles Testing and that this dependency is
        // therefore deprecated. Once Xcode is installed, drop this line and the
        // `.product` entry below; the test sources need no change either way.
        //
        // `exact:`, not `from:`. This was `from: "0.10.0"`, and the open upper bound moved on
        // its own: clearing `.build/workspace-state.json` while bumping whisper re-resolved it
        // and it jumped 0.10.0 -> 0.99.0 in a build nobody asked to change. The suite happened
        // to pass, which is the problem — a test dependency that can silently change version
        // means a green run proves less than it looks like it does. Pinned to the version the
        // 316 tests are known to pass on; bump it deliberately or not at all.
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "0.99.0"),
    ],
    targets: [
        // Prebuilt whisper.cpp (Metal + Core ML enabled, minOS 13.3).
        // Pinned by checksum so a tampered or swapped archive fails the build.
        .binaryTarget(
            name: "WhisperFramework",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/v1.9.2/whisper-v1.9.2-xcframework.zip",
            checksum: "af74fed13ea7f2d5ca2a39d9f58ec177713fafd7cab63aef4e27b79f3ceca80b"
        ),

        // Cactus's prebuilt Whistle engine (arm64) plus an x86_64 stub; see Vendor/Needle/build-xcframework.sh.
        .binaryTarget(name: "Needle", path: "Vendor/Needle/Needle.xcframework"),

        // Everything that is not UI, in layer folders: SDKs, Services, Features.
        // It must not import SwiftUI; `AppIdentityTests` fails the suite if a file does.
        .target(
            name: "UtterCore",
            dependencies: ["WhisperFramework", "Needle"],
            path: "Sources/UtterCore",
            linkerSettings: [.linkedLibrary("c++")]
        ),

        // The app layer (windows, screens, pill, companion), as a library.
        //
        // A library so that it can be tested: SwiftPM cannot attach a test
        // target to an executable target, so while the app *was* a single executable
        // target, none of it was reachable from a test — `import XCTest` fails to
        // resolve and `@testable import` has no module to enter. Verified on this
        // machine before restructuring.
        .target(
            name: "UtterKit",
            dependencies: ["UtterCore"],
            path: "Sources/UtterKit",
            // Documentation, not a compilable source or a runtime resource.
            exclude: ["README.md"]
        ),

        // The executable: a two-line shim that calls `UtterApp.main()`.
        // SwiftPM links with the deployment target as the SDK version, which makes AppKit draw the
        // pre-26 compatibility design; stamping the real SDK turns on Liquid Glass.
        .executableTarget(
            name: "Utter",
            dependencies: ["UtterKit"],
            path: "Sources/Utter",
            linkerSettings: [sdkStamp]
        ),

        .testTarget(
            name: "UtterKitTests",
            dependencies: [
                "UtterKit",
                "UtterCore",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/UtterKitTests",
            linkerSettings: [sdkStamp]
        ),
    ]
)
