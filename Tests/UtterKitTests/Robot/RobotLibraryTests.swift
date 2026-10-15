import Foundation
import Testing
@testable import UtterKit

@Suite("Robot library")
struct RobotLibraryTests {
    private static let src = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Windows and Linux/src")

    private struct Table: Decodable {
        struct Case: Decodable { let name: String; let steps: [Step] }
        struct Step: Decodable { let signal: String; let detail: [String: RobotValue]?; let now, random: Double?; let expect: String? }
        struct Clock: Decodable { let date: String; let expect: [String: RobotValue] }
        let route: [Case]
        let clock: [Clock]
    }

    private static let tableURL = src.appendingPathComponent("companion-routes.test.json")

    private static func table() throws -> Table {
        try JSONDecoder().decode(Table.self, from: Data(contentsOf: tableURL))
    }

    private static func localDate(_ text: String) throws -> Date {
        let n = text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        let parts = DateComponents(year: n[0], month: n[1], day: n[2], hour: n[3], minute: n[4], second: n.count > 5 ? n[5] : 0)
        return try #require(Calendar(identifier: .gregorian).date(from: parts))
    }

    @Test("The shared route table gives the same picks as the web player")
    func routeTable() throws {
        let library = try RobotLibrary.load(from: Self.tableURL)
        for c in try Self.table().route {
            var memory = RobotRouteMemory()
            for (i, step) in c.steps.enumerated() {
                let now = step.now ?? Date().timeIntervalSince1970 * 1000
                let picked = library.route(step.signal, step.detail ?? [:], memory: &memory, now: now, random: { step.random ?? 0 })
                #expect(picked == step.expect, "\(c.name), step \(i + 1)")
            }
        }
    }

    @Test("The shared clock table reads local time and the times of day")
    func clockTable() throws {
        let library = try RobotLibrary.load(from: Self.tableURL)
        for c in try Self.table().clock {
            #expect(library.clock(try Self.localDate(c.date)) == c.expect, "\(c.date)")
        }
    }

    @Test("The real library loads and every route target exists")
    func realLibrary() throws {
        let library = try RobotLibrary.load(from: Self.src.appendingPathComponent("companion-moments.json"))
        #expect(!library.moments.isEmpty && !library.routes.isEmpty && !library.times.isEmpty)
        #expect(Set(library.finishOrder) == Set(library.finishes.keys) && library.finishOrder.count == library.finishes.count)
        #expect(Set(library.accessoryOrder) == Set(library.accessories.keys) && library.accessoryOrder.count == library.accessories.count)
        #expect(library.defaults["finish"].flatMap { library.finishes[$0] } != nil)
        for (i, r) in library.routes.enumerated() {
            let targets = r.moments ?? r.moment.map { [$0] } ?? []
            #expect(!targets.isEmpty, "route \(i) has no moment")
            for id in targets { #expect(library.moments[id] != nil, "route \(i) plays missing \(id)") }
        }
        for (id, moment) in library.moments {
            for acc in moment.accessories + moment.reduced.compactMap(\.on) {
                #expect(library.accessories[acc] != nil, "\(id) wears missing \(acc)")
            }
        }
    }

    @Test("Shared falls back to the source tree during development")
    func sharedLoads() {
        #expect(RobotLibrary.shared?.moments.isEmpty == false)
    }

    @Test("Decodes the merged shape: wear, unwired, list is, pools, frames, unknown keys")
    func mergedShape() throws {
        let json = #"""
        { "version": 2, "credit": "Robot by CX ArtLab", "box": 240,
          "defaults": { "finish": "zinc", "time": "day" },
          "finishes": { "zinc": { "name": "Zinc", "body": "#000000", "eyes": "#FFFFFF", "askFirst": true },
                        "amber": { "name": "Amber \"A\"", "body": "#F1B632", "eyes": "#1C2A5E", "swap": { "gold": "red" },
                                   "shapes": [{ "el": "rect", "x": 0, "y": 176, "width": 240, "height": 10, "fill": "red" }] } },
          "times": { "night": { "name": "Late night", "from": 22, "to": 5, "speed": 0.8, "lid": 9, "blink": 1.4 },
                     "all": { "name": "All", "from": 0, "to": 24, "speed": 1, "lid": 0, "blink": 1 } },
          "accessories": { "scarf": { "name": "Scarf", "slot": "ears", "layer": "head", "enter": "drop", "wear": true,
                                      "shapes": [{ "el": "g", "transform": "translate(1 2)", "kids": [
                                        { "el": "path", "d": "M0 0 H4", "stroke-width": 2.5, "fill": "none",
                                          "anim": { "frames": ["rotate(0deg)", { "transform": "rotate(4deg)", "opacity": 0, "offset": 0.3, "strokeDashoffset": 10 }],
                                                    "ms": 900, "delay": -300, "once": true, "ease": "inOut", "origin": "50% 0%" } }] }] },
                           "bell": { "name": "Bell", "slot": "air", "layer": "front", "enter": "pop", "shapes": [] } },
          "moments": { "wave": { "group": "play", "name": "Wave", "trigger": "When poked", "unwired": "later",
                                 "steps": [{ "on": "scarf" }, { "pose": "happy", "ms": 320, "set": { "w": 60, "rx": 30 } },
                                           { "gaze": [[1, 0, 200]], "speed": 1.5 }, { "on": "bell", "instant": true }, { "on": "scarf" },
                                           { "head": ["rotate(0deg)", "rotate(9deg)"], "times": 2, "origin": "120px 204px" },
                                           { "fx": "wink", "amp": 3 }, { "off": "bell", "exit": "lift" }, { "wait": 400 }],
                                 "reduced": [{ "pose": "happy" }, { "wait": 400 }], "loopFrom": 2 } },
          "routes": [{ "signal": "ambient", "is": { "weekday": [0, 6], "time": "night" }, "moments": ["wave"], "cooldown": 600000 },
                     { "signal": "poke", "atLeast": { "count": 5 }, "moment": "wave", "every": 10 }] }
        """#
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("robot-library-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let library = try RobotLibrary.load(from: url)

        #expect(library.finishOrder == ["zinc", "amber"])
        #expect(library.accessoryOrder == ["scarf", "bell"])
        #expect(library.timeOrder == ["night", "all"])
        #expect(library.timeOfDay(try Self.localDate("2026-10-15T23:00")) == "night")
        #expect(library.finishes["amber"]?.swap == ["gold": "red"] && library.finishes["zinc"]?.shapes == nil)
        #expect(library.accessories["scarf"]?.wear == true && library.accessories["bell"]?.wear == nil)

        let path = try #require(library.accessories["scarf"]?.shapes.first?.kids.first)
        #expect(path.el == "path" && path.attributes["d"] == .string("M0 0 H4") && path.attributes["stroke-width"] == .number(2.5))
        #expect(path.attributes["anim"] == nil && path.attributes["kids"] == nil)
        let anim = try #require(path.anim)
        #expect(anim.frames.map(\.transform) == ["rotate(0deg)", "rotate(4deg)"])
        #expect(anim.frames[1].opacity == 0 && anim.frames[1].offset == 0.3 && anim.frames[1].strokeDashoffset == 10)
        #expect(anim.delay == -300 && anim.once == true && anim.origin == "50% 0%")

        let wave = try #require(library.moments["wave"])
        #expect(wave.accessories == ["scarf", "bell"])
        #expect(wave.unwired == "later" && wave.loopFrom == 2)
        #expect(wave.steps[1].set == ["w": 60, "rx": 30] && wave.steps[2].gaze == [[1, 0, 200]] && wave.steps[5].times == 2)

        let route = library.routes[0]
        #expect(route.is?["weekday"] == .list([.number(0), .number(6)]) && route.moments == ["wave"])
        var memory = RobotRouteMemory()
        #expect(library.route("ambient", ["weekday": .number(6), "time": .string("night")], memory: &memory, now: 0) == "wave")
        #expect(library.route("ambient", ["weekday": .bool(true), "time": .string("night")], memory: &memory, now: 1e9) == nil)
    }
}
