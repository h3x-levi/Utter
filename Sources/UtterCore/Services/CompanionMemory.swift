import Foundation
import UserNotifications

package enum CompanionNotificationPayload {
    package static let memoryIDKey = "memoryID"
}

package enum CompanionMemorySource: String, Codable, CaseIterable {
    case typed
    case spoken

    var label: String {
        switch self {
        case .typed: return "Typed"
        case .spoken: return "Spoken"
        }
    }
}

package struct CompanionMemory: Identifiable, Codable, Equatable {
    package let id: UUID
    package var text: String
    let createdAt: Date
    package var remindAt: Date?
    let source: CompanionMemorySource
    var deliveredAt: Date?
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        remindAt: Date? = nil,
        source: CompanionMemorySource,
        deliveredAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.remindAt = remindAt
        self.source = source
        self.deliveredAt = deliveredAt
        self.completedAt = completedAt
    }

    package var isCompleted: Bool { completedAt != nil }

    var isPending: Bool {
        guard let remindAt else { return false }
        return !isCompleted && remindAt > Date()
    }
}

package struct CompanionMemoryProposal: Equatable {
    package var text: String
    package var remindAt: Date?
}

enum CompanionMemoryError: LocalizedError, Equatable {
    case empty
    case tooLong
    case invalidDate
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Write what you want Utter to remember."
        case .tooLong:
            return "A memory can be at most 1,000 characters."
        case .invalidDate:
            return "Choose a reminder time in the future."
        case .persistenceFailed(let detail):
            return "The memory could not be saved: \(detail)"
        }
    }
}

package enum CompanionMemoryParser {
    private struct ModelAnswer: Decodable {
        let text: String
        let remindAt: String?
    }

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let wholeSecondISO8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    package static func parse(_ input: String, now: Date = Date()) async throws -> CompanionMemoryProposal {
        let cleaned = try validatedText(input)
        if LocalAIEngine.availability.isReady {
            do {
                return try await parseWithModel(cleaned, now: now)
            } catch {
                // A memory is still useful without AI. Fall back to the system date detector
                // instead of turning a transient model failure into lost user input.
                return try deterministic(cleaned, now: now)
            }
        }
        return try deterministic(cleaned, now: now)
    }

    static func deterministic(_ input: String, now: Date = Date()) throws -> CompanionMemoryProposal {
        let cleaned = try validatedText(input)
        let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
        let detector = try NSDataDetector(
            types: NSTextCheckingResult.CheckingType.date.rawValue
        )
        let match = detector.matches(in: cleaned, options: [], range: range)
            .first(where: { ($0.date ?? .distantPast) > now })

        var memoryText = cleaned
        var remindAt: Date?
        if let match, let date = match.date, let swiftRange = Range(match.range, in: cleaned) {
            remindAt = date
            memoryText.removeSubrange(swiftRange)
        }
        memoryText = stripCommandWords(from: memoryText)
        if memoryText.isEmpty {
            memoryText = stripCommandWords(from: cleaned)
        }
        return CompanionMemoryProposal(text: memoryText, remindAt: remindAt)
    }

    private static func parseWithModel(
        _ input: String,
        now: Date
    ) async throws -> CompanionMemoryProposal {
        let timezone = TimeZone.current.identifier
        let nowText = iso8601.string(from: now)
        let response = try await LocalAIEngine.rewrite(
            instructions: """
            Extract one private reminder or memory. Return only JSON with exactly two keys:
            "text" is the concise thing to remember, preserving names and meaning.
            "remindAt" is an ISO 8601 timestamp with timezone, or null when no time was requested.
            Never invent a time. Resolve relative dates from the supplied current time and timezone.
            """,
            prompt: """
            Current time: \(nowText)
            Timezone: \(timezone)
            User input: \(input)
            """
        )
        guard let data = jsonObjectData(in: response),
              let answer = try? JSONDecoder().decode(ModelAnswer.self, from: data)
        else {
            throw AIEngineError.emptyResponse
        }
        let text = try validatedText(answer.text)
        let date = answer.remindAt.flatMap(parseISO8601)
        if answer.remindAt != nil, date == nil {
            throw CompanionMemoryError.invalidDate
        }
        if let date, date <= now {
            throw CompanionMemoryError.invalidDate
        }
        return CompanionMemoryProposal(text: text, remindAt: date)
    }

    private static func jsonObjectData(in response: String) -> Data? {
        guard let open = response.firstIndex(of: "{"),
              let close = response.lastIndex(of: "}"),
              open <= close
        else { return nil }
        return String(response[open...close]).data(using: .utf8)
    }

    private static func parseISO8601(_ text: String) -> Date? {
        iso8601.date(from: text) ?? wholeSecondISO8601.date(from: text)
    }

    private static func validatedText(_ input: String) throws -> String {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw CompanionMemoryError.empty }
        guard text.count <= 1_000 else { throw CompanionMemoryError.tooLong }
        return text
    }

    private static func stripCommandWords(from input: String) -> String {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "remind me to ", "remind me that ", "remember to ", "remember that ",
            "remember ", "please remind me to ", "please remember to ",
            "please remember that ", "please remember ",
        ]
        let lower = text.lowercased()
        if let prefix = prefixes.first(where: { lower.hasPrefix($0) }) {
            text.removeFirst(prefix.count)
        }
        return text
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines
                .union(CharacterSet(charactersIn: ",.-")))
    }
}

@MainActor
package final class CompanionMemoryStore: ObservableObject {
    private static let live = CompanionMemoryStore(
        notifications: .shared,
        onCreated: { UserData.shared.recordCompanionMemoryCreated() },
        onCompleted: { UserData.shared.recordCompanionMemoryCompleted() }
    )
    static var preview: CompanionMemoryStore?
    package static var shared: CompanionMemoryStore { preview ?? live }

    @Published package private(set) var memories: [CompanionMemory] = []
    @Published private(set) var lastError: String?

    private let storageDir: URL?
    private let notifications: CompanionNotificationScheduler?
    private let onCreated: () -> Void
    private let onCompleted: () -> Void

    private var fileURL: URL? { storageDir?.appendingPathComponent("companion-memories.json") }
    private var previousURL: URL? {
        storageDir?.appendingPathComponent("companion-memories.previous.json")
    }

    init(
        storageDir: URL? = AppDirectory.support,
        notifications: CompanionNotificationScheduler? = nil,
        onCreated: @escaping () -> Void = {},
        onCompleted: @escaping () -> Void = {},
        seed: [CompanionMemory] = []
    ) {
        self.storageDir = storageDir
        self.notifications = notifications
        self.onCreated = onCreated
        self.onCompleted = onCompleted
        load()
        if !seed.isEmpty { memories = seed }
    }

    package var active: [CompanionMemory] {
        memories
            .filter { !$0.isCompleted }
            .sorted {
                switch ($0.remindAt, $1.remindAt) {
                case let (left?, right?): return left < right
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return $0.createdAt > $1.createdAt
                }
            }
    }

    package var completed: [CompanionMemory] {
        memories
            .filter(\.isCompleted)
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    @discardableResult
    package func add(
        proposal: CompanionMemoryProposal,
        source: CompanionMemorySource,
        now: Date = Date()
    ) throws -> CompanionMemory {
        let text = proposal.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw CompanionMemoryError.empty }
        guard text.count <= 1_000 else { throw CompanionMemoryError.tooLong }
        if let remindAt = proposal.remindAt, remindAt <= now {
            throw CompanionMemoryError.invalidDate
        }
        let memory = CompanionMemory(
            text: text,
            createdAt: now,
            remindAt: proposal.remindAt,
            source: source
        )
        memories.insert(memory, at: 0)
        do {
            try persist()
        } catch {
            memories.removeAll { $0.id == memory.id }
            throw error
        }
        lastError = nil
        onCreated()
        if memory.remindAt != nil { schedule(memory) }
        return memory
    }

    func update(_ memory: CompanionMemory, now: Date = Date()) throws {
        let text = memory.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw CompanionMemoryError.empty }
        guard text.count <= 1_000 else { throw CompanionMemoryError.tooLong }
        if let remindAt = memory.remindAt, remindAt <= now, memory.completedAt == nil {
            throw CompanionMemoryError.invalidDate
        }
        guard let index = memories.firstIndex(where: { $0.id == memory.id }) else { return }
        let original = memories[index]
        var updated = memory
        updated.text = text
        updated.deliveredAt = nil
        memories[index] = updated
        do {
            try persist()
        } catch {
            memories[index] = original
            throw error
        }
        lastError = nil
        notifications?.cancel(id: memory.id)
        if updated.remindAt != nil, !updated.isCompleted { schedule(updated) }
    }

    package func complete(id: UUID, at date: Date = Date()) {
        guard let index = memories.firstIndex(where: { $0.id == id }),
              memories[index].completedAt == nil
        else { return }
        let original = memories[index]
        memories[index].completedAt = date
        do {
            try persist()
            lastError = nil
            notifications?.cancel(id: id)
            onCompleted()
        } catch {
            memories[index] = original
            lastError = error.localizedDescription
        }
    }

    package func snooze(id: UUID, minutes: Int = 10, from date: Date = Date()) {
        guard let index = memories.firstIndex(where: { $0.id == id }),
              memories[index].completedAt == nil
        else { return }
        let original = memories[index]
        memories[index].remindAt = date.addingTimeInterval(TimeInterval(max(1, minutes) * 60))
        memories[index].deliveredAt = nil
        do {
            try persist()
            lastError = nil
            schedule(memories[index])
        } catch {
            memories[index] = original
            lastError = error.localizedDescription
        }
    }

    package func markDelivered(id: UUID, at date: Date = Date()) -> CompanionMemory? {
        guard let index = memories.firstIndex(where: { $0.id == id }),
              memories[index].completedAt == nil
        else { return nil }
        let original = memories[index]
        memories[index].deliveredAt = date
        do {
            try persist()
            lastError = nil
        } catch {
            memories[index] = original
            lastError = error.localizedDescription
            return nil
        }
        return memories[index]
    }

    package func delete(id: UUID) {
        guard let index = memories.firstIndex(where: { $0.id == id }) else { return }
        let removed = memories[index]
        memories.removeAll { $0.id == id }
        do {
            try persist()
            lastError = nil
            notifications?.cancel(id: id)
        } catch {
            memories.insert(removed, at: min(index, memories.count))
            lastError = error.localizedDescription
        }
    }

    package func deleteAll() {
        let removed = memories
        memories.removeAll()
        do {
            try persist()
            lastError = nil
            removed.forEach { notifications?.cancel(id: $0.id) }
        } catch {
            memories = removed
            lastError = error.localizedDescription
        }
    }

    package func restoreScheduledNotifications() {
        guard let notifications else { return }
        Task {
            await notifications.restore(
                active.filter { $0.remindAt.map { $0 > Date() } == true }
            )
        }
    }

    private func schedule(_ memory: CompanionMemory) {
        guard let notifications else { return }
        Task {
            do {
                try await notifications.schedule(memory)
            } catch {
                await MainActor.run { self.lastError = error.localizedDescription }
            }
        }
    }

    private func persist() throws {
        guard let fileURL, let previousURL else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // Seconds are encoded as a JSON Double, which round-trips Date's stored
        // precision. The original millisecond strategy truncated completion times
        // and made a save/load cycle observably change the value.
        encoder.dateEncodingStrategy = .secondsSince1970
        let data: Data
        do {
            data = try encoder.encode(memories)
        } catch {
            throw CompanionMemoryError.persistenceFailed(error.localizedDescription)
        }
        if let existing = try? Data(contentsOf: fileURL), existing != data {
            try? existing.write(to: previousURL, options: .atomic)
        }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw CompanionMemoryError.persistenceFailed(error.localizedDescription)
        }
    }

    private func load() {
        guard let fileURL, let previousURL, let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = decode(data) {
            memories = decoded
            return
        }

        let recovered = (try? Data(contentsOf: previousURL)).flatMap(decode)
        preserveUnreadablePrimary(fileURL)
        if let recovered {
            memories = recovered
            do {
                try encode(recovered).write(to: fileURL, options: .atomic)
                lastError = "The newest memory file was damaged. Utter restored the previous saved copy."
            } catch {
                lastError = "The newest memory file was damaged. The previous copy is loaded but could not be restored to disk."
            }
        }
    }

    private func decode(_ data: Data) -> [CompanionMemory]? {
        let decoder = JSONDecoder()
        // Read both generations. Values above 100 billion are the original
        // milliseconds-since-1970 representation; new files use seconds.
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(Double.self)
            return Date(timeIntervalSince1970: value > 100_000_000_000 ? value / 1_000 : value)
        }
        return try? decoder.decode([CompanionMemory].self, from: data)
    }

    private func encode(_ value: [CompanionMemory]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(value)
    }

    private func preserveUnreadablePrimary(_ fileURL: URL) {
        let salvage = fileURL.deletingLastPathComponent().appendingPathComponent(
            "companion-memories-unreadable-\(Int(Date().timeIntervalSince1970)).json"
        )
        do {
            try FileManager.default.moveItem(at: fileURL, to: salvage)
            lastError = "An unreadable memory file was preserved as \(salvage.lastPathComponent)."
        } catch {
            lastError = "The memory file is unreadable and could not be preserved."
        }
    }
}

@MainActor
package final class CompanionNotificationScheduler: ObservableObject {
    package static let shared = CompanionNotificationScheduler()

    package enum AuthorizationState: Equatable {
        case unknown
        case authorized
        case denied
        case failed(String)

        package var message: String {
            switch self {
            case .unknown: return "Notification access is checked when you schedule a reminder."
            case .authorized: return "Reminders can appear when Utter is closed."
            case .denied: return "Notifications are off, so reminders appear only while Utter is open."
            case .failed(let detail): return "Notification scheduling failed: \(detail)"
            }
        }
    }

    static let categoryIdentifier = "UTTER_COMPANION_MEMORY"
    package static let doneAction = "UTTER_MEMORY_DONE"
    package static let snoozeAction = "UTTER_MEMORY_SNOOZE"
    static let identifierPrefix = "utter.companion.memory."
    static let memoryIDKey = CompanionNotificationPayload.memoryIDKey

    @Published package private(set) var state: AuthorizationState = .unknown

    private let center: UNUserNotificationCenter?

    init() {
        center = Self.defaultCenter()
    }

    init(center: UNUserNotificationCenter?) {
        self.center = center
    }

    package func registerCategory() {
        guard let center else { return }
        let done = UNNotificationAction(
            identifier: Self.doneAction,
            title: "Done",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: Self.snoozeAction,
            title: "Snooze 10 Minutes",
            options: []
        )
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.categoryIdentifier,
                actions: [done, snooze],
                intentIdentifiers: [],
                options: []
            ),
        ])
    }

    package func refreshState() async {
        guard let center else { return }
        let settings = await center.notificationSettings()
        updateState(from: settings.authorizationStatus)
    }

    func schedule(_ memory: CompanionMemory) async throws {
        guard let remindAt = memory.remindAt, remindAt > Date(), !memory.isCompleted else {
            throw CompanionMemoryError.invalidDate
        }
        guard let center else { throw CompanionNotificationError.unavailable }
        let settings = await center.notificationSettings()
        var status = settings.authorizationStatus
        if status == .notDetermined {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            status = granted ? .authorized : .denied
        }
        updateState(from: status)
        guard status == .authorized || status == .provisional else {
            throw CompanionNotificationError.denied
        }

        let content = UNMutableNotificationContent()
        content.title = "Utter reminder"
        content.body = memory.text
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = [Self.memoryIDKey: memory.id.uuidString]

        let interval = max(1, remindAt.timeIntervalSinceNow)
        let request = UNNotificationRequest(
            identifier: identifier(for: memory.id),
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        try await center.add(request)
    }

    func restore(_ memories: [CompanionMemory]) async {
        guard let center else { return }
        let settings = await center.notificationSettings()
        updateState(from: settings.authorizationStatus)
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
        else { return }
        for memory in memories {
            try? await schedule(memory)
        }
    }

    func cancel(id: UUID) {
        center?.removePendingNotificationRequests(withIdentifiers: [identifier(for: id)])
    }

    private static func defaultCenter() -> UNUserNotificationCenter? {
        guard supportsSystemNotifications(bundleURL: Bundle.main.bundleURL) else { return nil }
        return .current()
    }

    static func supportsSystemNotifications(bundleURL: URL) -> Bool {
        bundleURL.pathExtension == "app"
    }

    private func identifier(for id: UUID) -> String {
        Self.identifierPrefix + id.uuidString
    }

    private func updateState(from status: UNAuthorizationStatus) {
        switch status {
        case .authorized, .provisional, .ephemeral:
            state = .authorized
        case .denied:
            state = .denied
        case .notDetermined:
            state = .unknown
        @unknown default:
            state = .failed("macOS returned an unknown authorization state.")
        }
    }
}

enum CompanionNotificationError: LocalizedError {
    case denied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .denied:
            return "Notifications are disabled for Utter. The reminder is saved and remains visible in the app."
        case .unavailable:
            return "Notifications are unavailable. The reminder is saved and remains visible in the app."
        }
    }
}
