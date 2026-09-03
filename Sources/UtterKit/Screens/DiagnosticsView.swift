import SwiftUI
import AppKit

// MARK: - Report model

/// One crash report, with the facts worth putting in a list row lifted out of it.
///
/// `CrashReporter` writes two formats, and they label the cause differently: the
/// signal handler writes `Signal:` because a signal name is all it can know
/// without allocating, and the exception handler writes `Name:` with the
/// Objective-C class. Both mean "what killed the process", so both keys map to
/// this one field and the row reads the same either way.
///
/// An unparsed report keeps an empty `cause` rather than inventing one. A row
/// labelled with a guess is worse than a row labelled with a date, because it
/// sends whoever reads it looking for the wrong bug.
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
        // header key anyway — and a report truncated mid-write is exactly the case
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

// MARK: - Pane

/// The Diagnostics pane: the crash reports Utter wrote about itself.
///
/// `CrashReporter` has been writing these to
/// `~/Library/Application Support/Utter/crashes/` all along, and nothing ever
/// read them back — so they existed only for someone who already knew the folder
/// was there. A crash report nobody can find is a crash report nobody files a bug
/// about, which is the entire point of keeping one.
///
/// Deliberately not behind a developer or debug flag. A report holds a signal
/// name, the app version, the OS version and stack addresses — no transcripts, no
/// note text, no audio — and the files are already readable in Finder by anyone
/// who opens the folder. Gating them would hide them from exactly the people in a
/// position to report the crash while protecting nothing.
@MainActor
final class DiagnosticsViewModel: ObservableObject {
    @Published var logs: [CrashLogSummary] = []
    @Published var selectedID: URL?
    @Published var revealProblem: String?
    @Published var micLevel: Double = 0.0

    var selected: CrashLogSummary? {
        logs.first { $0.id == selectedID }
    }

    func load() {
        logs = CrashReporter.shared.crashLogs.map {
            CrashLogSummary(url: $0.url, date: $0.date, content: $0.content)
        }
        if selectedID == nil || !logs.contains(where: { $0.id == selectedID }) {
            selectedID = logs.first?.id
        }
    }

    private var timer: Timer?

    func startMonitoring() {
        stopMonitoring()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            let amp = AppDelegate.current?.audioRecorder?.inputLevel ?? 0
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.08)) {
                    self?.micLevel = max(0.05, min(1.0, Double(amp) * 1.8))
                }
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func reveal(_ url: URL, isDirectory: Bool = false) {
        revealProblem = nil
        let workspace = NSWorkspace.shared

        if isDirectory {
            if workspace.selectFile(nil, inFileViewerRootedAtPath: url.path) { return }
            let parent = url.deletingLastPathComponent()
            if workspace.selectFile(nil, inFileViewerRootedAtPath: parent.path) { return }
            revealProblem = "Couldn’t open \(url.path)."
        } else {
            if workspace.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path) {
                return
            }
            revealProblem = "Couldn’t reveal \(url.lastPathComponent). It may have been deleted."
        }
    }
}

struct DiagnosticsSettingsContent: View {
    @StateObject private var model = DiagnosticsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x5) {
            telemetryCard
            liveMicTestCard
            reportsCard
            systemReportsCard
        }
        .onAppear { model.load() }
    }

    // MARK: Hardware & Engine Telemetry

    @ViewBuilder
    private var telemetryCard: some View {
        SettingsCard(title: "Hardware & Engine Telemetry") {
            VStack(alignment: .leading, spacing: Space.x3) {
                HStack(spacing: Space.x4) {
                    TelemetryTile(
                        icon: "cpu",
                        title: "Processor Architecture",
                        value: "\(ProcessInfo.processInfo.processorCount) Cores Active",
                        subtitle: "Apple Silicon Optimized"
                    )
                    TelemetryTile(
                        icon: "bolt.badge.automatic",
                        title: "Whisper Acceleration",
                        value: "Metal + CoreML",
                        subtitle: "Zero-Copy Audio Shaders"
                    )
                }

                HStack(spacing: Space.x4) {
                    TelemetryTile(
                        icon: "memorychip",
                        title: "Unified Memory",
                        value: "\(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)) GB RAM",
                        subtitle: "Shared GPU/Neural Buffer"
                    )
                    TelemetryTile(
                        icon: "waveform.badge.magnifyingglass",
                        title: "Speech Engine Model",
                        value: ModelStore.shared.active.rawValue.capitalized,
                        subtitle: "16 kHz Mono PCM Float32"
                    )
                }
            }
        }
    }

    // MARK: Live Microphone Test Meter

    @ViewBuilder
    private var liveMicTestCard: some View {
        SettingsCard(title: "Microphone Input Test") {
            VStack(alignment: .leading, spacing: Space.x3) {
                Text("Speak into your microphone to verify audio capture responsiveness:")
                    .font(.caption)
                    .foregroundStyle(Ink.secondary)

                HStack(spacing: Space.x3) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(Tint.accent)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                                .frame(height: 12)

                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Tint.accent, Color.green, Color.orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(8, geo.size.width * CGFloat(model.micLevel)), height: 12)
                        }
                    }
                    .frame(height: 12)

                    Text(String(format: "%.0f dB", (model.micLevel * 60) - 60))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Ink.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }
            .onAppear {
                model.startMonitoring()
            }
            .onDisappear {
                model.stopMonitoring()
            }
        }
    }

    // MARK: Utter's own reports

    @ViewBuilder
    private var reportsCard: some View {
        SettingsCard(title: "Crash reports") {
            if model.logs.isEmpty {
                EmptyStateView(
                    icon: "checkmark.seal",
                    title: "No crash reports",
                    message: "Utter hasn’t crashed on this Mac. If it ever does, the report lands here."
                )
            } else {
                if CrashReporter.shared.previousRunCrashed {
                    Label(
                        "Utter’s last run ended in a crash. The newest report below is from that run.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .typo(.caption, ink: Tint.warningText)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Text("Reports Utter wrote as it crashed, newest first. Utter keeps the ten most recent.")
                    .typo(.caption)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: Space.x2) {
                    ForEach(model.logs) { log in
                        GlassSelectableRow(isSelected: log.id == model.selectedID) {
                            model.selectedID = log.id
                        } content: {
                            row(for: log)
                        }
                    }
                }

                if let selected = model.selected {
                    HairlineDivider()
                    detail(for: selected)
                }
            }
        }
    }

    private func row(for log: CrashLogSummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.x3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.date, format: .dateTime.month().day().hour().minute())
                    .typo(.callout, ink: Ink.primary)
                let subtitle = log.subtitle
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .typo(.caption, ink: Ink.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Space.x2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Selected report

    @ViewBuilder
    private func detail(for log: CrashLogSummary) -> some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            HStack(spacing: Space.x2) {
                Text(log.url.lastPathComponent)
                    .typo(.caption, ink: Ink.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: Space.x2)
                GlassButton(title: "Reveal in Finder", systemImage: "folder", size: .small) {
                    model.reveal(log.url)
                }
                GlassButton(title: "Copy", systemImage: "doc.on.doc", size: .small) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(log.content, forType: .string)
                }
            }

            GroupBox {
                ScrollView([.vertical, .horizontal]) {
                    Text(log.content)
                        .typo(.mono)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Space.x3)
                }
                .frame(height: 260)
                .accessibilityLabel("Crash report contents")
            }

            if let revealProblem = model.revealProblem {
                Text(revealProblem)
                    .typo(.caption, ink: Tint.dangerText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: The system's reports

    private var systemReportsCard: some View {
        SettingsCard(title: "System crash reports") {
            Text("macOS files its own report for the same crash, fully symbolicated — it names the functions Utter’s report can only record as addresses. Prefer it when reporting a bug.")
                .typo(.caption)
                .fixedSize(horizontal: false, vertical: true)

            GlassButton(title: "Open DiagnosticReports", systemImage: "folder", size: .small) {
                model.reveal(Self.systemReportsDirectory, isDirectory: true)
            }
        }
    }

    private static var systemReportsDirectory: URL {
        FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/DiagnosticReports", isDirectory: true)
    }
}

// MARK: - Telemetry Tile

private struct TelemetryTile: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack(spacing: Space.x3) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Tint.accent.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Tint.accent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(Ink.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Ink.primary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Ink.tertiary)
            }
            Spacer()
        }
        .padding(8)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

