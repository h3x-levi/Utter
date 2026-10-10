import Foundation

/// Records uncaught exceptions and fatal signals to
/// `~/Library/Application Support/Utter/crashes/`.
///
/// The signal path is deliberately austere. A signal handler may only call
/// async-signal-safe functions - essentially `write(2)`, `_exit(2)`, and
/// `signal(2)`. `DateFormatter`, string interpolation, `Thread.callStackSymbols`
/// and `String.write(to:)` all allocate or take locks, so calling them from a
/// handler risks deadlocking against the very heap that just crashed, or
/// re-crashing inside the reporter. Either way no report is written - precisely
/// when one is most wanted.
///
/// So the two paths differ on purpose:
///
///   * **Uncaught Objective-C exceptions** are delivered on a normal thread with a
///     working runtime, so the rich Foundation report is safe there.
///   * **Signals** get a fixed-size, pre-rendered, `write(2)`-only note. It carries
///     the signal name and the app version and nothing that needs to allocate.
///
/// The handler also re-raises rather than calling `exit()`. `exit()` runs atexit
/// handlers and C++ static destructors - which is how a clean quit was previously
/// turned into a SIGABRT inside ggml's Metal teardown - and it sets an exit code
/// instead of dying from the signal, so the OS never files its own `.ips` report.
/// Re-raising with the default disposition preserves the real crash for the system
/// crash reporter, which has symbolication this never will.
final class CrashReporter {

    private static let live = CrashReporter()
    nonisolated(unsafe) static var preview: CrashReporter?
    static var shared: CrashReporter { preview ?? live }

    /// Guards against re-entering the handler if the reporter itself faults.
    /// `sig_atomic_t` because it is touched from a signal handler.
    private static var handling: sig_atomic_t = 0

    /// Pre-opened, pre-rendered state for the signal path.
    ///
    /// Everything a handler needs must exist *before* the crash: a C string path,
    /// and the version bytes. Building either at signal time would allocate.
    /// Candidate paths for signal reports, pre-rendered at install time.
    ///
    /// The handler cannot build a filename: formatting a timestamp allocates. The
    /// original design wrote one fixed name with `O_TRUNC`, which meant every
    /// signal crash overwrote the previous one - so `pruneOldLogs`, which keeps ten
    /// logs, only ever had one signal log to keep, and a second crash erased the
    /// evidence of the first.
    ///
    /// Instead: render a small pool of numbered paths up front and let the handler
    /// pick the first that does not exist yet, using `access(2)` (async-signal-safe).
    /// A full pool falls back to slot 0, so the newest crash is always recorded.
    private static var signalLogSlots: [[CChar]] = []
    private static var versionBytes: [UInt8] = []

    private let crashDir: URL?

    init(crashDir: URL? = AppDirectory.subdirectory("crashes")) {
        self.crashDir = crashDir
    }

    /// Crash logs from previous runs, newest first. Read by the UI.
    ///
    /// The `url` is part of the result because the Diagnostics pane reveals the
    /// file in Finder, and rebuilding the path at the call site would duplicate
    /// `crashDir` - the one place that knows where these live.
    ///
    /// Dated by *modification* time, not creation time. The signal handler cannot
    /// format a timestamp into a filename without allocating, so it reuses one of
    /// the pre-rendered `crash-signal-NN.log` slots with `O_TRUNC` - and once the
    /// pool is full it truncates slot 0 again. A reused slot keeps the creation date
    /// of the crash that first claimed it while its contents are from the most
    /// recent one, so creation date would put a months-old date on a crash that
    /// happened minutes ago. This also matches `detectPreviousCrash` and
    /// `pruneOldLogs`, which already use mtime.
    var crashLogs: [(url: URL, date: Date, content: String)] {
        let fm = FileManager.default
        guard let crashDir, let files = try? fm.contentsOfDirectory(
            at: crashDir, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "log" }
            .compactMap { url -> (URL, Date, String)? in
                guard let content = try? String(contentsOf: url, encoding: .utf8),
                      let date = try? url.resourceValues(
                          forKeys: [.contentModificationDateKey]
                      ).contentModificationDate
                else { return nil }
                return (url, date, content)
            }
            .sorted { $0.1 > $1.1 }
    }

    /// True when the previous run ended in a crash within the last 24 hours.
    ///
    /// Exposed rather than merely printed: `print` goes to stdout, which nobody
    /// sees in a packaged app, so the old detection was dead code.
    private(set) var previousRunCrashed = false

    func install() {
        guard let crashDir else { return }
        prepareSignalState(in: crashDir)

        NSSetUncaughtExceptionHandler { exception in
            // Safe to allocate here: this is an ordinary thread, not a signal
            // context. Grab the symbols while the frames are still meaningful.
            CrashReporter.shared.writeReport(
                type: "UncaughtException",
                name: exception.name.rawValue,
                reason: exception.reason ?? "unknown",
                stack: exception.callStackSymbols.joined(separator: "\n")
            )
        }

        for sig in [SIGABRT, SIGSEGV, SIGBUS, SIGFPE, SIGILL, SIGTRAP] {
            signal(sig) { received in
                // Re-entrancy: if writing the note faults, don't loop forever.
                if CrashReporter.handling != 0 {
                    signal(received, SIG_DFL)
                    raise(received)
                    return
                }
                CrashReporter.handling = 1

                CrashReporter.writeSignalNote(received)

                // Restore the default disposition and re-raise, so the process dies
                // of the actual signal. This is what lets macOS write its own
                // symbolicated report; `exit(sig)` suppressed it entirely.
                signal(received, SIG_DFL)
                raise(received)
            }
        }

        detectPreviousCrash(in: crashDir)
        pruneOldLogs(in: crashDir)
    }

    // MARK: - Signal path (async-signal-safe only)

    /// Build everything the signal handler will need, ahead of time.
    private func prepareSignalState(in crashDir: URL) {
        // Ten slots to match `pruneOldLogs`'s retention. `%02d` keeps them sorting
        // lexically, which is how the pruner and the UI both order files.
        Self.signalLogSlots = (0..<10).map { index in
            crashDir
                .appendingPathComponent(String(format: "crash-signal-%02d.log", index))
                .path
                .utf8CString
                .map { $0 }
        }
        Self.versionBytes = Array(ConfigManager.shared.appVersion.utf8)

        // Force the re-entrancy flag's lazy initialisation to happen *here*.
        //
        // Swift initialises static storage on first access, through `swift_once`.
        // Nothing else touches `handling`, so the very first access would otherwise
        // be the signal handler's own `if CrashReporter.handling != 0` - running
        // `swift_once` (a `dispatch_once` underneath) inside a signal context, which
        // is not on the async-signal-safe list. Writing it once from ordinary code
        // completes the token, after which every handler access is a plain load.
        // Costs one store at launch and removes the question entirely.
        Self.handling = 0
    }

    /// First unused slot, or slot 0 when every slot is taken.
    ///
    /// `access` is on the POSIX async-signal-safe list, and the slot array was
    /// built before the crash, so this allocates nothing.
    private static func nextFreeSlot() -> [CChar] {
        for slot in signalLogSlots where access(slot, F_OK) != 0 {
            return slot
        }
        return signalLogSlots.first ?? []
    }

    /// Write a minimal crash note using only `open`/`write`/`close`.
    ///
    /// Fixed strings and pre-rendered bytes only - no allocation, no formatting,
    /// no Foundation. Timestamping is left to the file's mtime, which the OS
    /// records for free.
    private static func writeSignalNote(_ sig: Int32) {
        let fd = open(nextFreeSlot(), O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        guard fd >= 0 else { return }

        func put(_ bytes: [UInt8]) {
            var offset = 0
            while offset < bytes.count {
                let written = bytes.withUnsafeBufferPointer { buffer in
                    write(fd, buffer.baseAddress! + offset, bytes.count - offset)
                }
                if written <= 0 { return }
                offset += written
            }
        }
        func put(_ text: StaticString) {
            var offset = 0
            let count = text.utf8CodeUnitCount
            while offset < count {
                let written = write(fd, text.utf8Start + offset, count - offset)
                if written <= 0 { return }
                offset += written
            }
        }

        put("Utter crash (signal)\n")
        put("Signal: ")
        put(name(for: sig))
        put("\nVersion: ")
        put(versionBytes)
        put("\n\nStack (innermost first):\n")

        // `backtrace` walks the stack into a caller-supplied buffer and
        // `backtrace_symbols_fd` writes straight to the descriptor - neither
        // allocates, so both are safe here. (`backtrace_symbols`, the more obvious
        // choice, mallocs an array of strings and must not be used in a handler.)
        //
        // The buffer is a fixed-size local: 64 frames is deep enough to reach main
        // through a SwiftUI/AppKit stack, and stack space is all we can rely on.
        var frames = [UnsafeMutableRawPointer?](repeating: nil, count: 64)
        let depth = frames.withUnsafeMutableBufferPointer { buffer in
            backtrace(buffer.baseAddress, Int32(buffer.count))
        }
        if depth > 0 {
            frames.withUnsafeMutableBufferPointer { buffer in
                backtrace_symbols_fd(buffer.baseAddress, depth, fd)
            }
        }

        put("\nAddresses are unsymbolicated for inlined Swift frames; the system\n")
        put("report in ~/Library/Logs/DiagnosticReports/ has full symbolication.\n")
        close(fd)
    }

    /// Signal number → its name.
    ///
    /// `StaticString`, not `String`: the literals live in the binary and `put`
    /// writes their bytes directly. Returning a `String` and taking `Array(_.utf8)`
    /// would allocate - the exact thing a signal handler must not do.
    ///
    /// The previous version interpolated the *number* into `"SIG\(n)"`, so a
    /// SIGABRT was recorded as "SIG6", which is not a signal name at all.
    private static func name(for sig: Int32) -> StaticString {
        switch sig {
        case SIGABRT: return "SIGABRT"
        case SIGSEGV: return "SIGSEGV"
        case SIGBUS: return "SIGBUS"
        case SIGFPE: return "SIGFPE"
        case SIGILL: return "SIGILL"
        case SIGTRAP: return "SIGTRAP"
        default: return "UNKNOWN"
        }
    }

    // MARK: - Exception path (allocation is fine here)

    private func writeReport(type: String, name: String, reason: String, stack: String) {
        guard let crashDir else { return }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let url = crashDir.appendingPathComponent("crash_\(fmt.string(from: Date())).log")

        let report = """
        Utter Crash Report
        ==================
        Date: \(Date())
        Type: \(type)
        Name: \(name)
        Reason: \(reason)
        Version: \(ConfigManager.shared.appVersion)
        OS: \(ProcessInfo.processInfo.operatingSystemVersionString)

        Stack Trace:
        \(stack)
        """
        try? report.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Housekeeping

    private func detectPreviousCrash(in crashDir: URL) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: crashDir, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        let newest = files
            .filter { $0.pathExtension == "log" }
            .compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
            .max()

        guard let newest else { return }
        previousRunCrashed = Date().timeIntervalSince(newest) < 86_400
        if previousRunCrashed {
            print("⚠️ Previous run left a crash log (\(newest))")
        }
    }

    /// Keep the ten most recent logs.
    private func pruneOldLogs(in crashDir: URL) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: crashDir, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        let logs = files.filter { $0.pathExtension == "log" }
        guard logs.count > 10 else { return }

        let oldestFirst = logs.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a < b
        }
        for file in oldestFirst.prefix(logs.count - 10) {
            try? fm.removeItem(at: file)
        }
    }
}
