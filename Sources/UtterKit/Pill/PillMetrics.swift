import AppKit
import SwiftUI

/// What the pill draws: the capture state plus the pointer, a message the user has not seen yet,
/// and the short celebration after a delivered turn.
enum PillLook: Equatable {
    case rest
    case hover(handsFree: Bool)
    case listening(PillGlyph?)
    case thinking
    case done
    case message(String, PillTone)
    case dot(PillTone)
    case island(String)

    static func derive(state: PillState, revealed: Bool, unseen: PillMessage?, celebrating: Bool,
                       offersHandsFree: Bool) -> PillLook {
        switch state {
        case .preparing:
            return revealed ? .hover(handsFree: false) : .rest
        case .idle:
            if celebrating { return .done }
            if let unseen { return revealed ? .message(unseen.text, unseen.tone) : .dot(unseen.tone) }
            return revealed ? .hover(handsFree: offersHandsFree) : .rest
        case .recording: return .listening(nil)
        case .handsFree: return .listening(.lock)
        case .capturingNote: return .listening(.note)
        case .capturingMemory: return .listening(.memory)
        case .processing: return .thinking
        case .error(let text): return .message(text, .error)
        case .notice(let text): return .message(text, .notice)
        case .island(let transcript): return .island(transcript)
        }
    }

    /// The looks the pill may hide in when "Always show the pill" is off.
    var isResting: Bool {
        switch self {
        case .rest, .hover: return true
        default: return false
        }
    }

    var isListening: Bool {
        if case .listening = self { return true }
        return false
    }

    var bars: PillBarMode {
        switch self {
        case .rest, .dot, .island, .done, .message(_, .error): return .hidden
        case .hover: return .rest
        case .listening: return .voice
        case .thinking: return .thinking
        case .message: return .flat
        }
    }

    /// A lock or glyph square at the trailing end, which the bars stand clear of.
    var hasTrailingGlyph: Bool {
        switch self {
        case .hover(handsFree: true), .listening(.some): return true
        default: return false
        }
    }
}

enum PillTone: Equatable { case error, notice }
enum PillGlyph: Equatable { case lock, note, memory }

struct PillMessage: Equatable {
    var text: String
    var tone: PillTone
}

/// The pill's springs. Opening may overshoot a little; closing never does.
enum PillMotion: Equatable {
    case open, close, hover

    static func between(_ old: PillLook, _ new: PillLook) -> PillMotion {
        if old == .rest, case .hover = new { return .hover }
        let from = PillMetrics.shellSize(for: old), to = PillMetrics.shellSize(for: new)
        return to.width > from.width || to.height > from.height ? .open : .close
    }

    var spring: Spring {
        switch self {
        case .open: return Spring(duration: 0.42, bounce: 0.2)
        case .close: return Spring(duration: 0.36, bounce: 0)
        case .hover: return Spring(duration: 0.3, bounce: 0.15)
        }
    }

    func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.18) : .spring(spring)
    }

    /// How long the shell takes to come to rest, so the panel never shrinks under a moving shape.
    func settle(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0.18 : spring.settlingDuration
    }
}

/// The pill's geometry. The panel is the shell plus `margin` on every side, anchored at the shell's
/// bottom centre, so nothing transparent sits beside the pill taking clicks.
enum PillMetrics {
    static let restSize = CGSize(width: 32, height: 6)
    static let hoverSize = CGSize(width: 48, height: 16)
    /// The listening height. `CompanionWindow` and `MeetingOfferPanel` place themselves against it.
    static let capsuleHeight: CGFloat = 20
    static let listeningWidth: CGFloat = 64
    static let handsFreeWidth: CGFloat = 80
    static let dotSide: CGFloat = 8
    static let messagePadding: CGFloat = 10
    static let messageGap: CGFloat = 6
    static let messageMaxWidth: CGFloat = 260
    static let islandWidth: CGFloat = 360
    static let islandPadding: CGFloat = 12
    static let islandSpacing: CGFloat = 6
    static let islandFooterHeight: CGFloat = 24
    static let islandCornerRadius: CGFloat = 22
    static let islandLines = 6
    /// The island's words wait for the shape to lead, then cross-fade in.
    static let islandTextDelay: TimeInterval = 0.18
    /// How long "Copied" or "Saved" shows before the island puts itself away.
    static let copiedHold: TimeInterval = 0.7
    /// A pointer passing over the pill does not open it.
    static let hoverIntent: TimeInterval = 0.1
    /// The done tick holds this long before the pill springs home.
    static let doneHold: TimeInterval = 0.45
    /// The tick starts drawing as the bars finish fading, and is whole well inside `doneHold`.
    static let tickDelay: TimeInterval = 0.08
    static let tickDraw: TimeInterval = 0.3
    /// Room for the shadow and a spring's overshoot.
    static let margin: CGFloat = 14
    static let captionGap: CGFloat = 6
    static let captionMaxWidth: CGFloat = 300

    static let capsuleCentreAboveBottom: CGFloat = margin + capsuleHeight / 2

    static var messageFont: NSFont {
        .systemFont(ofSize: NSFont.preferredFont(forTextStyle: .callout).pointSize, weight: .semibold)
    }

    static var captionHeight: CGFloat {
        let font = NSFont.preferredFont(forTextStyle: .callout)
        return ceil(NSLayoutManager().defaultLineHeight(for: font)) * 2 + 12
    }

    static func shellSize(for look: PillLook) -> CGSize {
        switch look {
        case .rest: return restSize
        case .hover: return hoverSize
        case .listening(nil), .thinking, .done: return CGSize(width: listeningWidth, height: capsuleHeight)
        case .listening: return CGSize(width: handsFreeWidth, height: capsuleHeight)
        case .message(let text, _): return CGSize(width: messageWidth(text), height: capsuleHeight)
        case .dot: return CGSize(width: dotSide, height: dotSide)
        case .island(let transcript): return CGSize(width: islandWidth, height: islandHeight(for: transcript))
        }
    }

    /// Flat bars and just enough room for a short message; a long one truncates and keeps its full
    /// text in the tooltip.
    static func messageWidth(_ text: String) -> CGFloat {
        let width = ceil((text as NSString).size(withAttributes: [.font: messageFont]).width)
        let content = messagePadding * 2 + PillBarGeometry.span + messageGap + width
        return min(max(ceil(content), listeningWidth), messageMaxWidth)
    }

    /// Where the bars' centre sits, from the shell's centre: beside a trailing glyph, before a message.
    static func barsOffset(for look: PillLook) -> CGFloat {
        let shell = shellSize(for: look)
        if look.hasTrailingGlyph { return -shell.height / 2 }
        if case .message = look { return messagePadding + PillBarGeometry.span / 2 - shell.width / 2 }
        return 0
    }

    /// A capsule until the shell is taller than the island's corners, so the radius springs with the size.
    static func cornerRadius(for size: CGSize) -> CGFloat {
        min(islandCornerRadius, size.height / 2, size.width / 2)
    }

    static func islandTextHeight(for transcript: String) -> CGFloat {
        let font = NSFont.preferredFont(forTextStyle: .body)
        let line = ceil(NSLayoutManager().defaultLineHeight(for: font))
        let text = (transcript as NSString).boundingRect(
            with: CGSize(width: islandWidth - islandPadding * 2, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font])
        return min(max(ceil(text.height), line), line * CGFloat(islandLines))
    }

    static func islandHeight(for transcript: String) -> CGFloat {
        let header = ceil(NSLayoutManager().defaultLineHeight(for: .preferredFont(forTextStyle: .caption1)))
        return islandPadding * 2 + header + islandSpacing * 2 + islandTextHeight(for: transcript)
            + islandFooterHeight
    }

    static func contentSize(for look: PillLook, caption: Bool) -> CGSize {
        let shell = shellSize(for: look)
        guard caption else { return shell }
        return CGSize(width: max(shell.width, captionMaxWidth), height: shell.height + captionGap + captionHeight)
    }

    static func panelSize(for look: PillLook, caption: Bool) -> CGSize {
        let content = contentSize(for: look, caption: caption)
        let width = ceil(content.width + margin * 2)
        return CGSize(width: width + width.truncatingRemainder(dividingBy: 2), height: ceil(content.height + margin * 2))
    }

    static func panelFrame(anchor: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: anchor.x - size.width / 2, y: anchor.y - margin, width: size.width, height: size.height)
    }

    /// Where the shell is drawn inside a panel of `bounds`, in the hosting view's flipped space.
    static func shellRect(for look: PillLook, in bounds: CGSize) -> CGRect {
        let shell = shellSize(for: look)
        return CGRect(x: (bounds.width - shell.width) / 2, y: bounds.height - margin - shell.height,
                      width: shell.width, height: shell.height)
    }

    /// What takes the mouse: the shell, with the sliver and the dot grown to a reachable size.
    static func hitRect(for look: PillLook, in bounds: CGSize) -> CGRect {
        var rect = shellRect(for: look, in: bounds)
        switch look {
        case .rest: rect = rect.insetBy(dx: -4, dy: -4)
        case .dot: rect = rect.insetBy(dx: -8, dy: -8)
        default: break
        }
        return rect.intersection(CGRect(origin: .zero, size: bounds))
    }

    /// The trailing square a lock or glyph sits in, the shell's own height.
    static func glyphRect(for look: PillLook, in bounds: CGSize) -> CGRect? {
        guard look.hasTrailingGlyph else { return nil }
        let shell = shellRect(for: look, in: bounds)
        return CGRect(x: shell.maxX - shell.height, y: shell.minY, width: shell.height, height: shell.height)
    }

    /// The lock button's square, where a press belongs to the button rather than to the long press.
    static func lockRect(for look: PillLook, in bounds: CGSize) -> CGRect? {
        switch look {
        case .hover(handsFree: true), .listening(.lock): return glyphRect(for: look, in: bounds)
        default: return nil
        }
    }
}
