import AppKit
import SwiftUI
import Testing

@testable import UtterKit

/// Renders every Mixtape component and state to `.build/screen-snapshots/mixtape-kit-{light,dark}.png`.
@Suite("Mixtape kit", .serialized, .enabled(if: ProcessInfo.processInfo.environment["UTTER_SCREEN_SNAPSHOTS"] == "1"))
struct ZZMixtapeKitSnapshots {
    @MainActor
    @Test func kitSheet() throws {
        for dark in [false, true] {
            try SnapshotCanvas.write(KitSheet(), "mixtape-kit", size: CGSize(width: 900, height: 860), dark: dark, settle: 1.2)
        }
    }
}

private struct KitSheet: View {
    @State private var empty = ""
    @State private var query = "milk"

    private let words = [11, 13, 8, 64, 10, 20, 16, 13, 8, 8, 7, 18]
    private var segments: [TapeSegment<Int>] {
        words.enumerated().map { TapeSegment(id: $0 + 1, words: $1, label: "Track \($0 + 1)") }
    }

    private let swatches: [(String, Color)] = [
        ("paper", Mixtape.paper), ("spine", Mixtape.spine), ("fold", Mixtape.fold), ("rule", Mixtape.rule),
        ("ink", Mixtape.ink), ("ink2", Mixtape.ink2), ("ink3", Mixtape.ink3), ("pen", Mixtape.pen),
        ("red", Mixtape.red), ("gold", Mixtape.gold), ("navy", Mixtape.navy), ("note", Mixtape.note),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            VStack(alignment: .leading, spacing: 18) {
                SideHeader("Tokens", detail: "light and dark")
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(88), spacing: 8), count: 4), alignment: .leading, spacing: 8) {
                    ForEach(swatches, id: \.0) { name, color in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 18, height: 18)
                                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Mixtape.edge))
                            Text(name).font(Mixtape.mono(11)).foregroundStyle(Mixtape.ink2)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tuesday 13 October").mixtapeCaps(30, tracking: 0.02).foregroundStyle(Mixtape.ink)
                    Text("12 tracks · 32 min 54 s of talk, all on this Mac").font(Mixtape.body(13)).foregroundStyle(Mixtape.ink3)
                    Text("Track 06 · 1:02 PM · 0:08 · 20 words").font(Mixtape.mono(11.5, .semibold)).foregroundStyle(Mixtape.ink3)
                }
                SideHeader("Tape stripe", detail: "ready, setup, recording")
                VStack(spacing: 8) {
                    TapeStripe("Ready · hold fn", segments: segments, goal: 500)
                    TapeStripe("One thing left", status: .setup, segments: segments, goal: 500)
                    TapeStripe("Recording", status: .recording, segments: segments, goal: 500)
                    TapeStripe(segments: segments, goal: 500, selected: 6)
                    TapeStripe("Daily tape", segments: segments + [TapeSegment(id: 13, words: 420, label: "Long")], goal: 500)
                }
                SideHeader("Pen buttons", detail: "outline, fill, ghost")
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Button("Paste again") {}.buttonStyle(.pen(.fill))
                        Button("Copy") {}.buttonStyle(.pen())
                        Button("Hands-free") {}.buttonStyle(.pen(.ghost))
                        Button("Off") {}.buttonStyle(.pen()).disabled(true)
                    }
                    HStack(spacing: 8) {
                        Button("Add to Words") {}.buttonStyle(.pen(.fill, .small))
                        Button("Save as note") {}.buttonStyle(.pen(.outline, .small))
                        Button("Not now") {}.buttonStyle(.pen(.ghost, .small))
                        Button {} label: { Image(systemName: "ellipsis") }.buttonStyle(.inkIcon).accessibilityLabel("More")
                    }
                }
                SideHeader("Deck keys", detail: "hands-free on")
                DeckKeys([
                    DeckKey("Hands-free", systemImage: "lock.fill", isOn: true) {},
                    DeckKey("New note", systemImage: "note.text") {},
                    DeckKey("Record meeting", systemImage: "record.circle", accent: Mixtape.red) {},
                ])
            }
            .frame(width: 400)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 0) {
                    SideHeader("Side B", detail: "afternoon and evening · 8")
                    VStack(spacing: 0) {
                        TrackRow(number: 12, title: "Hi Sam, the slides look great. One small thing: can we swap slides four and five?",
                                 time: "0:08", selected: true) {
                            Button {} label: { Image(systemName: "doc.on.doc") }.buttonStyle(.inkIcon).accessibilityLabel("Copy")
                            Button {} label: { Image(systemName: "arrow.turn.down.left") }.buttonStyle(.inkIcon).accessibilityLabel("Paste")
                        }
                        TrackRow(number: 11, title: "Thanks everyone, great work today. Talk tomorrow.", time: "0:03", ticked: true)
                        TrackRow(number: 10, title: "Book idea", time: "0:03")
                        TrackRow(number: 4, title: "Design sync", time: "32:00", emphasized: true)
                        TrackRow(number: 6, title: "Dear Ms Okafor, thank you for the quick reply.", time: "0:08", selected: true)
                        TrackRow(number: 8, title: "Can you pick up milk and something for dinner on the way home?", time: "0:05", highlight: query)
                    }
                    .frame(height: Mixtape.ruleSpacing * 7, alignment: .top)
                    .background(alignment: .top) { RuledBackground() }
                }
                SideHeader("Line field", detail: "empty, typed")
                LineField("Search what you said", text: $empty)
                LineField("Search what you said", text: $query)
                SideHeader("Ink note")
                InkNote(Text("Utter heard a new name, ") + Text("Okafor").bold().foregroundStyle(Mixtape.ink)
                        + Text(". Add it to Words so it’s always spelled right?")) {
                    Button("Add to Words") {}.buttonStyle(.pen(.fill, .small))
                    Button("Not now") {}.buttonStyle(.pen(.ghost, .small))
                }
                SideHeader("Shapes", detail: "HandCircle, InkTick")
                HStack(spacing: 24) {
                    HandCircle().stroke(Mixtape.pen, style: StrokeStyle(lineWidth: 2, lineCap: .round)).frame(width: 96, height: 72)
                    InkTick().stroke(Mixtape.pen, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)).frame(width: 48, height: 40)
                }
            }
            .frame(width: 400)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Mixtape.paper)
    }
}
