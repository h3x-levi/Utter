import Testing
import Foundation
@testable import UtterKit

/// Header parsing for the Diagnostics list rows.
///
/// Worth pinning because `CrashReporter` writes two different formats from two
/// different code paths - the async-signal-safe handler and the exception handler
/// - and the subtitle has to read correctly for both. The signal path in
/// particular is a fixed byte sequence assembled by `write(2)` calls that no test
/// can exercise directly, so these fixtures mirror it exactly as
/// `writeSignalNote` emits it.
@Suite("Crash log summary parsing")
struct CrashLogSummaryTests {

    private func summary(_ content: String) -> CrashLogSummary {
        CrashLogSummary(
            url: URL(fileURLWithPath: "/tmp/crash-signal.log"),
            date: Date(timeIntervalSince1970: 0),
            content: content
        )
    }

    /// Byte-for-byte what `CrashReporter.writeSignalNote` puts at the head of the
    /// file, including the blank line before the stack.
    private let signalReport = """
    Utter crash (signal)
    Signal: SIGABRT
    Version: 1.4.2

    Stack (innermost first):
    0   Utter  0x0000000102a4c1f8 0x102a44000 + 33272
    1   libsystem_platform.dylib 0x000000018d2a4184 _sigtramp + 56
    """

    /// The exception path's format, from `writeReport`.
    private let exceptionReport = """
    Utter Crash Report
    ==================
    Date: 2026-08-10 18:22:41 +0000
    Type: UncaughtException
    Name: NSInvalidArgumentException
    Reason: unrecognized selector sent to instance
    Version: 1.4.2
    OS: Version 15.3 (Build 24D60)

    Stack Trace:
    0   CoreFoundation  0x000000018d5b1f2c __exceptionPreprocess + 176
    """

    @Test("A signal report reads its signal name and version")
    func signalHeaders() {
        let parsed = summary(signalReport)
        #expect(parsed.cause == "SIGABRT")
        #expect(parsed.version == "1.4.2")
        #expect(parsed.subtitle == "SIGABRT · version 1.4.2")
    }

    @Test("An exception report reads its class name and version")
    func exceptionHeaders() {
        let parsed = summary(exceptionReport)
        // `Name:`, not `Signal:` - the two formats label the cause differently and
        // both have to land in the same field.
        #expect(parsed.cause == "NSInvalidArgumentException")
        #expect(parsed.version == "1.4.2")
    }

    /// The header scan stops before the stack trace, so a symbol line that happens
    /// to contain a colon cannot be mistaken for a header.
    @Test("Stack frames don't supply header values")
    func stackIsNotScanned() {
        let parsed = summary("""
        Utter crash (signal)
        Signal: SIGSEGV

        Stack (innermost first):
        0   Utter  Version: not-a-real-version
        """)
        #expect(parsed.cause == "SIGSEGV")
        #expect(parsed.version == nil)
    }

    /// A report truncated mid-write is the normal failure mode here: the process
    /// was dying while the file was being written. It must still produce a row.
    @Test("A truncated report degrades to a dateless-but-valid row")
    func truncated() {
        let parsed = summary("Utter crash (signal)\nSignal: ")
        // `Signal:` with nothing after it is not a cause. Empty, not " ".
        #expect(parsed.cause == "")
        #expect(parsed.version == nil)
        #expect(parsed.subtitle == "")
    }

    @Test("An empty file yields an empty subtitle rather than crashing")
    func empty() {
        let parsed = summary("")
        #expect(parsed.cause == "")
        #expect(parsed.subtitle == "")
    }

    /// With no version the subtitle is just the cause - no dangling separator.
    @Test("A missing version leaves no orphaned separator")
    func causeOnly() {
        let parsed = summary("Utter crash (signal)\nSignal: SIGTRAP\n")
        #expect(parsed.subtitle == "SIGTRAP")
    }

    @Test("A version with no cause still labels the row")
    func versionOnly() {
        let parsed = summary("Utter Crash Report\nVersion: 2.0.0\n")
        #expect(parsed.subtitle == "version 2.0.0")
    }
}
