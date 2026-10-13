import os

/// Points of Interest intervals for one dictation turn, read with Instruments' os_signpost.
package enum Signposts {
    package static let poster = OSSignposter(subsystem: "utter.dictation.app", category: .pointsOfInterest)

    /// Begun when a capture trigger arrives, ended when the pill applies a recording state. Main thread only.
    static var keyDownToPill: OSSignpostIntervalState?

    package static func beginKeyDownToPill() {
        keyDownToPill = poster.beginInterval("KeyDownToPill")
    }

    package static func endKeyDownToPill() {
        guard let state = keyDownToPill else { return }
        keyDownToPill = nil
        poster.endInterval("KeyDownToPill", state)
    }

    static func interval<T>(_ name: StaticString, _ body: () async throws -> T) async rethrows -> T {
        let state = poster.beginInterval(name)
        defer { poster.endInterval(name, state) }
        return try await body()
    }
}
