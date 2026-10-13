import SwiftUI

/// The pointer route into hands-free dictation: hover the resting pill and press the open lock; while
/// a session is latched the closed lock stops it. The chord still works from every state.
enum PillHoverControl {
    /// Idle and latched hands-free only. Preparing would queue behind the model load, push-to-talk is
    /// already in the user's hand, note and memory capture end on their chord, and processing refuses.
    static func isOffered(in state: PillState) -> Bool {
        state == .idle || state == .handsFree
    }

    static func stops(in state: PillState) -> Bool {
        state == .handsFree
    }

    static func actionName(in state: PillState) -> String {
        stops(in: state) ? "Stop hands-free dictation" : "Start hands-free dictation"
    }

    /// A completed long press opens Utter, unless it started on the lock, which owns its own press.
    static func longPressOpensUtter(in state: PillState, pointerOnControl: Bool) -> Bool {
        guard isOffered(in: state) else { return true }
        return !pointerOnControl
    }
}

struct PillLockButton: View {
    let stops: Bool
    let ink: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: stops ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(ink.opacity(0.92))
                .symbolEffect(.bounce, value: stops)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(PillHoverControl.actionName(in: stops ? .handsFree : .idle))
        .accessibilityHidden(true)
    }
}

/// The hands-free action on the pill's accessibility element, present only where a pointer is offered it.
struct HandsFreeAccessibilityAction: ViewModifier {
    let start: (() -> Void)?
    let name: String

    func body(content: Content) -> some View {
        if let start {
            content.accessibilityAction(named: Text(name), start)
        } else {
            content
        }
    }
}
