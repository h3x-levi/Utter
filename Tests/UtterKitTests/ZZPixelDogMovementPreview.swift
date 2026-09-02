import AppKit
import SwiftUI
import Testing
@testable import UtterKit

@Suite("Pixel dog movement preview", .serialized)
@MainActor
struct ZZPixelDogMovementPreview {
    @Test("Render every code-drawn dog movement")
    func renderMovementAtlas() throws {
        guard ProcessInfo.processInfo.environment["UTTER_RENDER_DOG_MOVEMENTS"] == "1" else {
            return
        }

        let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("DesignPreviews", isDirectory: true)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        NSApplication.shared.setActivationPolicy(.accessory)
        let previousReduceMotion = MotionPreference.shared.reduceMotion
        MotionPreference.shared.reduceMotion = false
        defer { MotionPreference.shared.reduceMotion = previousReduceMotion }

        let renderer = ImageRenderer(content: PixelDogMovementAtlas())
        renderer.scale = 1
        renderer.isOpaque = true
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image)
                .representation(using: .png, properties: [:]) else {
            throw PixelDogPreviewError.renderFailed
        }

        try png.write(
            to: outputDirectory.appendingPathComponent("pixel-dog-movements.png")
        )
    }
}

private enum PixelDogPreviewError: Error {
    case renderFailed
}

private enum PixelDogMovement: String, CaseIterable, Identifiable {
    case idle = "Idle"
    case listening = "Listening"
    case thinking = "Thinking"
    case celebrating = "Celebrating"
    case startled = "Startled"
    case sleeping = "Sleeping"
    case pawing = "Pawing"
    case panting = "Panting"
    case enjoyingPets = "Enjoying pets"
    case stalking = "Stalking"
    case held = "Held"
    case grooming = "Grooming"
    case rolling = "Rolling"
    case lyingDown = "Lying down"
    case walking = "Walking"

    var id: Self { self }

    var mood: CompanionMood {
        switch self {
        case .idle: .resting
        case .listening: .alert
        case .thinking: .thinking
        case .celebrating: .delighted
        case .startled: .startled
        case .sleeping: .sleepy
        case .pawing: .kneading
        case .panting: .overheating
        case .enjoyingPets: .purring
        case .stalking: .hunting
        case .held: .held
        case .grooming: .grooming
        case .rolling: .rolling
        case .lyingDown: .loaf
        case .walking: .resting
        }
    }

    var pose: CompanionPose {
        self == .walking
            ? CompanionPose(gait: .walking, travelSpeed: 96)
            : .neutral
    }
}

private struct PixelDogMovementAtlas: View {
    private let sampleTimes = [0.0, 0.14, 1.55]
    private let columns = Array(repeating: GridItem(.fixed(292), spacing: 18), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("PIXEL DOG")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                Text("Code-drawn movement atlas")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
            }

            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(PixelDogMovement.allCases) { movement in
                    VStack(spacing: 10) {
                        HStack(spacing: 2) {
                            ForEach(sampleTimes, id: \.self) { elapsed in
                                CodePixelCatView(
                                    style: .dog,
                                    mood: movement.mood,
                                    pose: movement.pose,
                                    size: 88,
                                    elapsed: elapsed
                                )
                            }
                        }

                        Text(movement.rawValue)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.vertical, 14)
                    .background(
                        Color.white.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                }
            }
        }
        .padding(32)
        .foregroundStyle(.white)
        .background(Color(red: 0.055, green: 0.06, blue: 0.075))
    }
}
