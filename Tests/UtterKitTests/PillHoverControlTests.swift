import Testing
import AppKit
@testable import UtterKit

@Suite("Pill hover control")
struct PillHoverControlTests {
    private static let states: [PillState] = [.preparing, .idle, .recording, .handsFree, .capturingNote,
                                              .capturingMemory, .processing(.transcribing), .error("x"),
                                              .notice("x"), .island("x")]

    @Test("The resting pill starts hands-free, a latched pill stops it, nothing else offers it")
    func offeredStates() {
        for state in Self.states {
            #expect(PillHoverControl.isOffered(in: state) == (state == .idle || state == .handsFree), "\(state)")
        }
        #expect(!PillHoverControl.stops(in: .idle))
        #expect(PillHoverControl.stops(in: .handsFree))
        #expect(PillHoverControl.actionName(in: .idle) == "Start hands-free dictation")
        #expect(PillHoverControl.actionName(in: .handsFree) == "Stop hands-free dictation")
    }

    @Test("A long press opens Utter unless it started on the lock")
    func longPress() {
        #expect(PillHoverControl.longPressOpensUtter(in: .idle, pointerOnControl: false))
        #expect(!PillHoverControl.longPressOpensUtter(in: .idle, pointerOnControl: true))
        #expect(PillHoverControl.longPressOpensUtter(in: .recording, pointerOnControl: true),
                "a stale flag in a state with no lock cannot disable it")
    }

    @Test("The lock sits inside the shell's trailing end wherever it is shown")
    func lockPlacement() throws {
        for look: PillLook in [.hover(handsFree: true), .listening(.lock)] {
            let bounds = PillMetrics.panelSize(for: look, caption: false)
            let shell = PillMetrics.shellRect(for: look, in: bounds)
            let lock = try #require(PillMetrics.lockRect(for: look, in: bounds))
            #expect(shell.contains(lock), "\(look)")
            #expect(abs(lock.midY - shell.midY) < 0.01)
            #expect(lock.maxX == shell.maxX && lock.width == shell.height)
        }
        for look: PillLook in [.rest, .hover(handsFree: false), .listening(nil), .listening(.note), .thinking] {
            #expect(PillMetrics.lockRect(for: look, in: CGSize(width: 200, height: 60)) == nil, "\(look)")
        }
    }
}
