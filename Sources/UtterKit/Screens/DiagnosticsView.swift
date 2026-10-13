import SwiftUI
import AppKit
import UtterCore

// MARK: - Report model

/// One crash report, with the facts worth a list row lifted out of it. The signal handler writes
/// `Signal:` and the exception handler `Name:`; both mean what killed the process.
struct CrashLogSummary: Identifiable {
    let url: URL
    let date: Date
    let content: String
    /// Signal name (`SIGABRT`) or exception class (`NSInvalidArgumentException`).
    let cause: String
    /// The app version that crashed, when the report records one.
    let version: String?

    var id: URL { url }

    init(url: URL, date: Date, content: String) {
        self.url = url
        self.date = date
        self.content = content

        var cause = ""
        var version: String?

        // Header keys only. `prefix(12)` stops the scan before the stack trace,
        // whose symbol lines can run to thousands of entries and cannot contain a
        // header key anyway - and a report truncated mid-write is exactly the case
        // where scanning the whole body would be slowest and least useful.
        for line in content.split(separator: "\n", omittingEmptySubsequences: false).prefix(12) {
            let line = line.trimmingCharacters(in: .whitespaces)
            if cause.isEmpty, let value = Self.value(of: "Signal", in: line) ?? Self.value(of: "Name", in: line) {
                cause = value
            } else if version == nil, let value = Self.value(of: "Version", in: line) {
                version = value
            }
        }

        self.cause = cause
        self.version = version
    }

    /// `key: value` on one line, or nil if this line isn't that key.
    private static func value(of key: String, in line: String) -> String? {
        let prefix = key + ":"
        guard line.hasPrefix(prefix) else { return nil }
        let value = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    /// The row subtitle: cause and version, whichever of them the report has.
    var subtitle: String {
        [cause, version.map { "version \($0)" }]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}


// MARK: - Help

/// Help, crash reports and About, at the foot of General.
struct HelpSettingsContent: View {
    let model: SettingsModel
    @ObservedObject private var userData: UserData
    @ObservedObject private var models: ModelStore

    init(model: SettingsModel? = nil) {
        let model = model ?? .shared
        self.model = model
        userData = model.userData
        models = model.models
    }

    var body: some View {
        SettingsSection("Help", detail: "something not working?") {
            SettingsRow("Report an issue", "Opens a short form that fills in a GitHub issue for you.") {
                Button("Report an Issue\u{2026}") { model.reportIssue() }
                    .buttonStyle(.pen(.outline, .small))
            }
            MicTestRow(model: model, hotkey: userData.hotkeyName)
        }

        SettingsSection("Crash reports", detail: "the ten most recent") {
            if model.lastRunCrashed {
                SettingsRow("Utter\u{2019}s last run ended in a crash", "The newest report below is from that run.") {
                    SettingsStatus(text: "Crashed", kind: .warn)
                }
            }
            if model.crashLogs.isEmpty {
                SettingsRow("Utter hasn\u{2019}t crashed on this Mac.", "If it ever does, the report appears here.") {
                    SettingsStatus(text: "None", kind: .ok)
                }
            }
            ForEach(model.crashLogs) { log in
                CrashReportRow(log: log, model: model)
            }
            if let problem = model.revealProblem {
                SettingsRow(problem)
                    .foregroundStyle(Mixtape.red)
            }
            SettingsRow("macOS crash reports", "macOS keeps a fuller report of the same crash. Attach it when you can.") {
                Button("Show in Finder") { model.reveal(SettingsModel.systemReportsFolder, isDirectory: true) }
                    .buttonStyle(.pen(.ghost, .small))
                    .accessibilityLabel("Show macOS crash reports in Finder")
            }
        }

        let device = model.device
        let speech = SpeechModel.model(for: models.active)
        SettingsSection("About", detail: "this Mac") {
            SettingsRow("Version") {
                value(model.appVersion).textSelection(.enabled)
            }
            SettingsRow("Processor") { value(device.chipName) }
            SettingsRow("Memory") { value("\(device.ramGB) GB") }
            SettingsRow("macOS") { value(ProcessInfo.processInfo.operatingSystemVersionString) }
            SettingsRow("Speech model") { value("\(speech.displayName)  \(speech.sizeMB) MB") }
            SettingsRow("Acknowledgements",
                        "Utter is built on whisper.cpp and OpenAI\u{2019}s Whisper speech model. Their licences are listed in THIRD_PARTY_NOTICES.md, which ships with the source code.")
        }
        .onAppear {
            model.loadCrashReports()
            model.startMicTest()
        }
        .onDisappear { model.stopMicTest() }
    }

    private func value(_ text: String) -> some View {
        Text(verbatim: text)
            .font(Mixtape.mono(12))
            .foregroundStyle(Mixtape.ink2)
    }
}

/// Reads only the level, so the 30 Hz updates redraw this row and nothing else.
private struct MicTestRow: View {
    let model: SettingsModel
    let hotkey: String

    var body: some View {
        let level = model.micLevel
        SettingsRow("Microphone test", "Hold \(hotkey) and speak. The line moves while Utter hears you.") {
            HStack(spacing: 8) {
                SettingsMeter(value: Double(level), width: 140)
                Text(verbatim: level > 0 ? "\(Int((level * 45 - 50).rounded())) dB" : "-- dB")
                    .font(Mixtape.mono(12))
                    .foregroundStyle(Mixtape.ink2)
                    .frame(width: 48, alignment: .trailing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Microphone level")
            .accessibilityValue(level > 0 ? "\(Int(level * 100)) percent" : "silent")
        }
    }
}

private struct CrashReportRow: View {
    let log: CrashLogSummary
    let model: SettingsModel

    var body: some View {
        let when = log.date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        SettingsRow(minHeight: 68) {
            Text(log.cause.isEmpty ? "Crash" : log.cause)
            Text(verbatim: [when, log.version.map { "version \($0)" }].compactMap { $0 }.joined(separator: "  "))
                .font(Mixtape.mono(11.5))
                .foregroundStyle(Mixtape.ink3)
        } trailing: {
            HStack(spacing: 6) {
                Button("Report") { model.reportIssue(crashLog: log.content) }
                    .buttonStyle(.pen(.fill, .small))
                    .accessibilityLabel("Report the crash from \(when)")
                Button("Show") { model.reveal(log.url) }
                    .buttonStyle(.pen(.ghost, .small))
                    .accessibilityLabel("Show the crash report from \(when) in Finder")
                Button("Copy") { model.copy(log) }
                    .buttonStyle(.pen(.ghost, .small))
                    .accessibilityLabel("Copy the crash report from \(when)")
            }
        }
    }
}
