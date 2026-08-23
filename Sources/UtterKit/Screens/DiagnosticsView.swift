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
struct DiagnosticsSettingsContent: View {
    /// Loaded on appear rather than read from `body`.
    ///
    /// `CrashReporter.crashLogs` enumerates a directory and reads every file in
    /// it. `body` runs on every layout pass, so binding the view straight to that
    /// property would put synchronous disk I/O on the render path.
    ///
    /// Loading once is also sufficient, not just cheaper: a report for *this*
    /// process is written as the process dies, so no new report can appear while
    /// this pane is on screen. There is nothing for a Refresh button to find.
    @State private var logs: [CrashLogSummary] = []
    @State private var selectedID: URL?
    /// Why a Finder reveal didn't happen, when it doesn't.
    ///
    /// `selectFile` returns `false` for a folder macOS hasn't created yet, and a
    /// button that silently does nothing reads as a broken app.
    @State private var revealProblem: String?

    private var selected: CrashLogSummary? {
        logs.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x5) {
            reportsCard
            systemReportsCard
        }
        .onAppear(perform: load)
    }

    // MARK: Utter's own reports

    @ViewBuilder
    private var reportsCard: some View {
        SettingsCard(title: "Crash reports") {
            if logs.isEmpty {
                // Worded as the healthy outcome, because it is the common one.
                // "No data" phrasing here would read as a failure to collect
                // something rather than as nothing having gone wrong.
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

                // **Not a `List(selection:)`, and this is the one place in this pane
                // where that is a close call.** A single-selection list of reports
                // with a detail view under it is what `List` is for, and it would
                // bring row hover, keyboard arrow navigation and the system's
                // selection highlight for free — all three of which
                // `GlassSelectableRow` is hand-rolling. Three things stop it:
                //
                //   * `List` has no intrinsic content height on macOS. This pane is a
                //     child of `SettingsWindowView`'s `ScrollView`, so a `List` here
                //     is a scroll container inside a scroll container and would need a
                //     hand-picked fixed height — a number that cannot be chosen
                //     without the app on screen, and `.scrollDisabled(true)` does not
                //     give a `List` an intrinsic height either.
                //   * That outer `ScrollView` is being rewritten concurrently. Nesting
                //     a `List` inside whatever replaces it is not a decision to take
                //     from this file.
                //   * `GlassSelectableRow` has a second call site, so converting this
                //     one does not retire the type — it leaves the app with two
                //     selection idioms instead of one.
                //
                // Routed rather than guessed. The rows keep their current behaviour
                // exactly, which for a read-only crash-report pane is the safe half of
                // the trade.
                VStack(spacing: Space.x2) {
                    ForEach(logs) { log in
                        GlassSelectableRow(isSelected: log.id == selectedID) {
                            selectedID = log.id
                        } content: {
                            row(for: log)
                        }
                    }
                }

                if let selected {
                    HairlineDivider()
                    detail(for: selected)
                }
            }
        }
    }

    private func row(for log: CrashLogSummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.x3) {
            VStack(alignment: .leading, spacing: 2) {
                // Locale-aware rather than a hand-built format string: this is a
                // timestamp the user may have to quote in a bug report.
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
                    reveal(log.url)
                }
                GlassButton(title: "Copy", systemImage: "doc.on.doc", size: .small) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(log.content, forType: .string)
                }
            }

            // A well, not glass: this is a wall of 13pt monospaced text, and text
            // composited onto Liquid Glass loses subpixel antialiasing. Thin mono
            // stems are where that reads most plainly as blur. That reasoning
            // survives `GroupBox` unchanged, because `GroupBox` is not glass — it is
            // the system's own grouped container, which is what a well is.
            //
            // The hand-drawn version was `Surface.sunken` behind a
            // `Line.hairline` stroke, and the hairline is the measured defect: it
            // computes to **1.015:1** on Paper and **1.022:1** on Linen in light mode
            // against ~1.55:1 in dark, so the well's edge was there in dark themes and
            // simply absent in light ones. `DefaultGroupBoxStyle` draws the system's
            // grouped background and border, which are appearance-aware by
            // construction — the light-mode contrast stops being a number this file
            // has to hit by hand.
            //
            // `.frame(height: 260)` stays and stays *inside* the group, so the well is
            // still pinned and there is no intrinsic-height question to answer. The
            // inner `Space.x3` also stays: it scrolls with the text, whereas
            // `GroupBox`'s inset does not, and without it the first line of a trace
            // would sit flush against the scroll edge.
            GroupBox {
                ScrollView([.vertical, .horizontal]) {
                    Text(log.content)
                        .typo(.mono)
                        // Selectable so a stack frame can be pulled straight into a
                        // bug report, and unwrapped so the trace keeps its columns.
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Space.x3)
                }
                .frame(height: 260)
                .accessibilityLabel("Crash report contents")
            }

            if let revealProblem {
                Text(revealProblem)
                    .typo(.caption, ink: Tint.dangerText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: The system's reports

    private var systemReportsCard: some View {
        SettingsCard(title: "System crash reports") {
            // Said plainly because it changes what someone attaches to a bug.
            // Utter's own report carries raw addresses; the system's names the
            // functions, which is the difference between a usable post-mortem and
            // a list of numbers.
            Text("macOS files its own report for the same crash, fully symbolicated — it names the functions Utter’s report can only record as addresses. Prefer it when reporting a bug.")
                .typo(.caption)
                .fixedSize(horizontal: false, vertical: true)

            GlassButton(title: "Open DiagnosticReports", systemImage: "folder", size: .small) {
                reveal(Self.systemReportsDirectory, isDirectory: true)
            }
        }
    }

    /// `~/Library/Logs/DiagnosticReports/`, built from the search path rather
    /// than a literal so it stays correct for the current user.
    private static var systemReportsDirectory: URL {
        FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/DiagnosticReports", isDirectory: true)
    }

    // MARK: Actions

    private func load() {
        logs = CrashReporter.shared.crashLogs.map {
            CrashLogSummary(url: $0.url, date: $0.date, content: $0.content)
        }
        // Open on the newest report: it is the one that just happened, and a pane
        // that shows a list but no contents looks like it failed to load.
        if selectedID == nil || !logs.contains(where: { $0.id == selectedID }) {
            selectedID = logs.first?.id
        }
    }

    /// Show a file selected in Finder, or a folder's contents.
    ///
    /// Falls back to the enclosing folder when the target isn't there — macOS
    /// creates `DiagnosticReports` lazily, so on a Mac that has never crashed the
    /// obvious call just fails.
    private func reveal(_ url: URL, isDirectory: Bool = false) {
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
