import Foundation

// Dead: the pet-era API that files outside Companion/ still name. Each block lists its last callers;
// delete the block when they stop, and the file when it is empty. Nothing here draws a pet or runs a clock.

// UserData (`companionObject`, stored on disk).
enum CompanionObject: String, CaseIterable, Identifiable {
    case none, ball, box, yarn, cushion

    var id: String { rawValue }

    var reward: CompanionReward? {
        switch self {
        case .none: nil
        case .ball: .ball
        case .box: .box
        case .yarn: .yarn
        case .cushion: .cushion
        }
    }
}

// UserData (`companionProgress.unlocked`, stored on disk), SoundPlayer, App.swift.
package enum CompanionReward: String, CaseIterable, Identifiable {
    case ball, yarn, curiousTrill, grooming, box, doubleMeow, rolling, cushion, warmPurr, loaf

    package var id: String { rawValue }

    var wordRequirement: Int {
        switch self {
        case .ball: 250
        case .yarn, .curiousTrill: 1_000
        case .grooming: 2_500
        case .box, .doubleMeow: 5_000
        case .rolling: 10_000
        case .cushion, .warmPurr: 20_000
        case .loaf: 50_000
        }
    }
}
