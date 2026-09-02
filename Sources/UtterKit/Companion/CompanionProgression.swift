import Foundation

enum CompanionReward: String, CaseIterable, Identifiable {
    case ball
    case yarn
    case curiousTrill
    case grooming
    case box
    case doubleMeow
    case rolling
    case cushion
    case warmPurr
    case loaf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ball: return "Play ball"
        case .yarn: return "Yarn"
        case .curiousTrill: return "Curious trill"
        case .grooming: return "Grooming"
        case .box: return "Cardboard box"
        case .doubleMeow: return "Double meow"
        case .rolling: return "Roll over"
        case .cushion: return "Sleeping cushion"
        case .warmPurr: return "Warm purr"
        case .loaf: return "Cozy loaf"
        }
    }

    var detail: String {
        switch self {
        case .ball, .yarn, .box, .cushion:
            return "Interactive object"
        case .curiousTrill, .doubleMeow, .warmPurr:
            return "Companion sound"
        case .grooming, .rolling, .loaf:
            return "Companion animation"
        }
    }

    var wordRequirement: Int {
        switch self {
        case .ball: return 250
        case .yarn, .curiousTrill: return 1_000
        case .grooming: return 2_500
        case .box, .doubleMeow: return 5_000
        case .rolling: return 10_000
        case .cushion, .warmPurr: return 20_000
        case .loaf: return 50_000
        }
    }

    var systemImage: String {
        switch self {
        case .ball: return "circle.fill"
        case .yarn: return "scribble"
        case .curiousTrill, .doubleMeow, .warmPurr: return "speaker.wave.2.fill"
        case .grooming: return "comb.fill"
        case .box: return "shippingbox.fill"
        case .rolling: return "arrow.triangle.2.circlepath"
        case .cushion: return "bed.double.fill"
        case .loaf: return "sparkles"
        }
    }
}

extension CompanionObject {
    var reward: CompanionReward? {
        switch self {
        case .none: return nil
        case .ball: return .ball
        case .box: return .box
        case .yarn: return .yarn
        case .cushion: return .cushion
        }
    }
}
