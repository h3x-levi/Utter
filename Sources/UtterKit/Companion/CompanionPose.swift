import SwiftUI

// MARK: - Mood
//
// The companion has two layers of behaviour, and keeping them apart is what stops
// it feeling like a looping GIF:
//
//   * `CompanionMood` is *reactive* — derived from what dictation is actually
//     doing, so the character is never emoting about nothing.
//   * `CompanionPose` is the frame currently on screen. Ambient fidgets (stretches,
//     hops) only ever change the pose, never the mood.

/// What the character is reacting to. Derived from `PillState`, never invented.
enum CompanionMood: Equatable {
    /// Nothing happening. The only mood that permits ambient wandering.
    case resting
    /// The microphone is live. The character watches, and its bounce is driven by
    /// the real input level.
    case alert
    /// Transcribing, rewriting or typing.
    case thinking
    /// A turn just finished successfully. Deliberately short-lived — a character
    /// that celebrates forever is celebrating nothing.
    case delighted
    /// Something failed.
    case startled
    /// A long stretch of `resting`. Curls up and stops moving, which is also how
    /// the behaviour loop stops costing anything.
    case sleepy

    // MARK: Pet moods
    //
    // The six above are *dictation* moods: they say what Utter is doing. The five below
    // are what the character does with the user's hands when Utter is idle — driven only
    // by local input (cursor position, keystroke timing, scroll deltas, drag velocity),
    // never by anything off the machine.
    //
    // They are moods rather than overlays because each one is a different drawing: a cat
    // kneading is not a cat sitting with a symbol next to it. The pack loader falls back
    // to `resting` for any state a pack does not provide, so adding these does not oblige
    // the existing four character packs to grow new art — they simply keep sitting.

    /// The user is typing, so the character works its paws.
    case kneading
    /// The user is typing hard enough to fluster it. Goes warm and steams.
    case overheating
    /// The pointer is being stroked over the character.
    case purring
    /// The cursor was flicked, and the character is stalking it.
    case hunting
    /// The character is being dragged, and hangs from the pointer.
    case held

    /// Whether ambient wandering is allowed.
    ///
    /// Only at rest, for the original reason — a character that strolls off mid-recording
    /// stops reading as attentive — and now also not while it is reacting to the user's
    /// hands. A cat that wanders away while being stroked is a cat that is not being
    /// stroked.
    var allowsWandering: Bool { self == .resting }

    /// Whether this mood is driven by the user's hands rather than by Utter's work.
    ///
    /// The distinction earns its keep in one place: pet moods may only take hold while the
    /// dictation side is idle, so a recording in progress is never interrupted by the cat
    /// noticing the mouse.
    var isPetMood: Bool {
        switch self {
        case .kneading, .overheating, .purring, .hunting, .held: return true
        case .resting, .alert, .thinking, .delighted, .startled, .sleepy: return false
        }
    }
}

// MARK: - Pose

/// One rendered frame of the character.
///
/// A value type on purpose: the behaviour engine builds poses and the renderers
/// read them, so there is exactly one description of "what the character looks
/// like right now" and no renderer can invent state of its own.
struct CompanionPose: Equatable {
    /// Vertical squash-and-stretch. 1 is neutral; 0.86 is a landing compression,
    /// 1.10 a take-off stretch. Width compensates inversely so the character
    /// conserves volume, which is what makes the deformation read as soft rather
    /// than as a scaling bug.
    var squash: CGFloat = 1

    /// Body lean in degrees. Positive leans in the direction of travel.
    var lean: CGFloat = 0

    /// -1 faces left, +1 faces right.
    var facing: CGFloat = 1

    /// Where the eyes are looking, each axis -1...1, +x right and +y up.
    ///
    /// A *direction*, not a pixel offset, because only the art knows how far an iris can
    /// travel before it leaves the socket — a 32px sprite has about two pixels of room.
    /// The renderer multiplies this by the pack's own limit, which keeps that knowledge
    /// with the pack instead of hard-coding one sprite's anatomy into the engine.
    ///
    /// Zero means looking straight ahead, which is what every non-pixel pack gets: the
    /// photo-derived packs have their eyes painted into the frame and no separate layer to
    /// move, so they ignore this entirely.
    var eyeAim: CGVector = CGVector(dx: 0, dy: 0)

    /// How flustered the character is, 0...1. Drives a warm tint over the sprite.
    ///
    /// Continuous rather than a flag so the colour arrives with the effort instead of
    /// snapping on at a threshold — the character going gradually pink as you type faster
    /// is the joke, and a boolean cannot tell it.
    var heat: CGFloat = 0

    /// Which body animation the renderer should prefer, independent of mood.
    ///
    /// Mood says what the character is *reacting* to; gait says how it is *moving* right
    /// now. They are separate on purpose: a walking cat is still `resting`-mood — nothing
    /// is happening, the walk is an ambient act — so there is no mood to key the walk cycle
    /// on. Only the renderer needs to know to show the walk frames instead of the idle loop,
    /// and a pack with no `walk` art falls back to its resting frames, so this obliges no
    /// one to draw a walk (the four photo packs keep sitting, exactly as the stroll left
    /// them before).
    var gait: Gait = .idle

    /// How the character is travelling this frame.
    enum Gait: Equatable {
        /// Standing, sitting, fidgeting in place — the resting/idle art.
        case idle
        /// Crossing the desktop under its own steam — the `walk` art if the pack has it.
        case walking
    }

    /// How fast the character is actually crossing the screen, in points per second, signed.
    ///
    /// **The gait is derived from this rather than from which act is running, and that is a fix
    /// for a defect that shipped twice in opposite directions.**
    ///
    /// Two acts translate the character and they do it through different mechanisms: `.walk` moves
    /// the whole window via `walkStep`, while `.stroll` moves `offsetX`, an offset *inside* a panel
    /// 2.1x the character's own size. Keying the walk cycle off `act == .walk` meant a stroll slid
    /// a seated cat sideways — a decal on a conveyor. Keying it off `act == .walk || act ==
    /// .stroll` fixed that and broke the other way: a stroll then played a full stride while the
    /// character shuffled a few tens of points inside its own panel and came back, which reads as
    /// running on the spot. Both were reported by the user, in that order.
    ///
    /// A speed cannot be wrong in either direction: legs cycle when the animal covers ground, at a
    /// cadence matching how fast it covers it, and stop when it stops. It also gives a drawn
    /// character what it needs to keep its planted paws still relative to the floor, which is the
    /// whole difference between walking and skating.
    var travelSpeed: CGFloat = 0

    /// The resting pose. Everything else is expressed as a deviation from this.
    static let neutral = CompanionPose()
}
