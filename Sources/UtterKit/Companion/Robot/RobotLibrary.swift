import Foundation
import os

enum RobotValue: Decodable, Equatable {
    case number(Double), string(String), bool(Bool), list([RobotValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else { self = .list(try c.decode([RobotValue].self)) }
    }
}

struct RobotRouteMemory {
    var at: [Int: Double] = [:]
    var last: [Int: String] = [:]
}

struct RobotLibrary: Decodable {
    let defaults: [String: String]
    let palette: [String: [String]]
    let groups: [String: String]
    let finishes: [String: RobotFinish]
    let times: [String: RobotTime]
    let accessories: [String: RobotAccessory]
    let moments: [String: RobotMoment]
    let routes: [RobotRoute]
    let finishOrder: [String]
    let accessoryOrder: [String]
    let timeOrder: [String]

    private static let log = Logger(subsystem: "utter.dictation.app", category: "companion")
    private static let keyOrder = CodingUserInfoKey(rawValue: "RobotLibrary.keyOrder")!

    static let shared: RobotLibrary? = {
        let file = "Windows and Linux/src/companion-moments.json"
        let binary = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        let candidates = [
            Bundle.main.url(forResource: "companion-moments", withExtension: "json"),
            binary.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent(file),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(file),
        ].compactMap { $0 }
        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            log.error("companion-moments.json not found; the robot plays upstream states only")
            return nil
        }
        do {
            return try load(from: url)
        } catch {
            log.error("companion-moments.json is invalid, the robot plays upstream states only: \(String(describing: error), privacy: .public)")
            return nil
        }
    }()

    static func load(from url: URL) throws -> RobotLibrary {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.userInfo[keyOrder] = memberOrder(data)
        return try decoder.decode(RobotLibrary.self, from: data)
    }

    private enum CodingKeys: String, CodingKey {
        case defaults, palette, groups, finishes, times, accessories, moments, routes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        defaults = try c.decodeIfPresent([String: String].self, forKey: .defaults) ?? [:]
        palette = try c.decodeIfPresent([String: [String]].self, forKey: .palette) ?? [:]
        groups = try c.decodeIfPresent([String: String].self, forKey: .groups) ?? [:]
        finishes = try c.decodeIfPresent([String: RobotFinish].self, forKey: .finishes) ?? [:]
        times = try c.decodeIfPresent([String: RobotTime].self, forKey: .times) ?? [:]
        accessories = try c.decodeIfPresent([String: RobotAccessory].self, forKey: .accessories) ?? [:]
        moments = try c.decodeIfPresent([String: RobotMoment].self, forKey: .moments) ?? [:]
        routes = try c.decodeIfPresent([RobotRoute].self, forKey: .routes) ?? []
        let order = decoder.userInfo[Self.keyOrder] as? [String: [String]] ?? [:]
        finishOrder = order["finishes"] ?? finishes.keys.sorted()
        accessoryOrder = order["accessories"] ?? accessories.keys.sorted()
        timeOrder = order["times"] ?? times.keys.sorted()
    }

    // JSONDecoder drops key order; pickers and timeOfDay follow the order written in the file.
    private static func memberOrder(_ data: Data) -> [String: [String]] {
        let bytes = [UInt8](data)
        var order: [String: [String]] = [:]
        var objects: [Bool] = []
        var expectKey = false
        var member = ""
        var i = 0
        while i < bytes.count {
            switch bytes[i] {
            case UInt8(ascii: "\""):
                var j = i + 1
                while j < bytes.count, bytes[j] != UInt8(ascii: "\"") { j += bytes[j] == UInt8(ascii: "\\") ? 2 : 1 }
                if expectKey, let key = String(bytes: bytes[(i + 1)..<min(j, bytes.count)], encoding: .utf8) {
                    if objects.count == 1 { member = key } else if objects.count == 2 { order[member, default: []].append(key) }
                }
                expectKey = false
                i = j
            case UInt8(ascii: "{"): objects.append(true); expectKey = true
            case UInt8(ascii: "["): objects.append(false); expectKey = false
            case UInt8(ascii: "}"), UInt8(ascii: "]"): _ = objects.popLast(); expectKey = false
            case UInt8(ascii: ","): expectKey = objects.last == true
            default: break
            }
            i += 1
        }
        return order
    }

    func timeOfDay(_ date: Date) -> String {
        let h = Self.calendar.component(.hour, from: date)
        return timeOrder.first { id in
            guard let t = times[id] else { return false }
            return t.from < t.to ? h >= t.from && h < t.to : h >= t.from || h < t.to
        } ?? defaults["time"] ?? "day"
    }

    // The web player reads Gregorian dates, so seasons match whatever calendar the Mac is set to.
    private static var calendar: Calendar { Calendar(identifier: .gregorian) }

    func clock(_ date: Date) -> [String: RobotValue] {
        let c = Self.calendar.dateComponents([.hour, .weekday, .month, .day], from: date)
        return [
            "time": .string(timeOfDay(date)),
            "hour": .number(Double(c.hour ?? 0)),
            "weekday": .number(Double((c.weekday ?? 1) - 1)),
            "month": .number(Double(c.month ?? 1)),
            "day": .number(Double(c.day ?? 1)),
        ]
    }

    func route(_ signal: String, _ detail: [String: RobotValue], memory: inout RobotRouteMemory, now: Double,
               random: () -> Double = { .random(in: 0..<1) }) -> String? {
        for (i, r) in routes.enumerated() where r.signal == signal {
            if let wanted = r.is, !wanted.allSatisfy({ key, want in
                guard let value = detail[key] else { return false }
                if case .list(let options) = want { return options.contains(value) }
                return value == want
            }) { continue }
            if let floors = r.atLeast, !floors.allSatisfy({ key, floor in
                guard case .number(let value)? = detail[key] else { return false }
                return value >= floor
            }) { continue }
            if let every = r.every {
                guard case .number(let total)? = detail["total"], case .number(let words)? = detail["words"],
                      (total / every).rounded(.down) > ((total - words) / every).rounded(.down) else { continue }
            }
            if let cooldown = r.cooldown, now - (memory.at[i] ?? -.infinity) < cooldown { continue }
            let pool = r.moments ?? r.moment.map { [$0] } ?? []
            let choices = pool.count > 1 ? pool.filter { $0 != memory.last[i] } : pool
            guard !choices.isEmpty else { return nil }
            let id = choices[min(Int(random() * Double(choices.count)), choices.count - 1)]
            memory.at[i] = now
            memory.last[i] = id
            return id
        }
        return nil
    }
}

struct RobotFinish: Decodable {
    let name, body, eyes: String
    let outline: String?
    let swap: [String: String]?
    let shapes: [RobotShapeSpec]?
}

struct RobotTime: Decodable {
    let name: String
    let from, to: Int
    let speed, lid, blink: Double
}

struct RobotAccessory: Decodable {
    let name, slot, layer, enter: String
    let wear: Bool?
    let shapes: [RobotShapeSpec]
}

struct RobotShapeSpec: Decodable {
    let el: String
    let attributes: [String: RobotValue]
    let kids: [RobotShapeSpec]
    let anim: RobotAnim?
}

extension RobotShapeSpec {
    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        var attributes: [String: RobotValue] = [:]
        for key in c.allKeys where !["el", "kids", "anim"].contains(key.stringValue) {
            attributes[key.stringValue] = try c.decode(RobotValue.self, forKey: key)
        }
        self.init(
            el: try c.decode(String.self, forKey: Key(stringValue: "el")),
            attributes: attributes,
            kids: try c.decodeIfPresent([RobotShapeSpec].self, forKey: Key(stringValue: "kids")) ?? [],
            anim: try c.decodeIfPresent(RobotAnim.self, forKey: Key(stringValue: "anim"))
        )
    }
}

struct RobotAnim: Decodable {
    let frames: [RobotAnimFrame]
    let ms: Double
    let delay: Double?
    let once: Bool?
    let ease: String?
    let origin: String?
}

struct RobotAnimFrame: Decodable {
    let transform: String?
    let opacity, offset, strokeDashoffset: Double?
}

extension RobotAnimFrame {
    private enum CodingKeys: String, CodingKey { case transform, opacity, offset, strokeDashoffset }

    init(from decoder: Decoder) throws {
        if let transform = try? decoder.singleValueContainer().decode(String.self) {
            self.init(transform: transform, opacity: nil, offset: nil, strokeDashoffset: nil)
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            transform: try c.decodeIfPresent(String.self, forKey: .transform),
            opacity: try c.decodeIfPresent(Double.self, forKey: .opacity),
            offset: try c.decodeIfPresent(Double.self, forKey: .offset),
            strokeDashoffset: try c.decodeIfPresent(Double.self, forKey: .strokeDashoffset)
        )
    }
}

struct RobotMoment: Decodable {
    let group, name, trigger: String
    let steps, reduced: [RobotStep]
    let loopFrom: Int?
    let unwired: String?

    var accessories: [String] {
        var seen = Set<String>()
        return steps.compactMap(\.on).filter { seen.insert($0).inserted }
    }
}

struct RobotStep: Decodable {
    let lock, unlock, instant: Bool?
    let pose, ease, origin, fx, on, off, exit: String?
    let ms, speed, amp, wait: Double?
    let set: [String: Double]?
    let gaze: [[Double]]?
    let head: [String]?
    let times: Int?
}

struct RobotRoute: Decodable {
    let signal: String
    let moment: String?
    let moments: [String]?
    let `is`: [String: RobotValue]?
    let atLeast: [String: Double]?
    let every, cooldown: Double?
}
