import Foundation

/// The one directory Utter keeps its data in, and the only place its name is written down.
///
/// Six stores used to derive this path independently - `UserData`, `NoteStore`,
/// `TranscriptionHistory`, `CrashReporter`, `SpritePackStore` and `PrivacyView` each spelled out
/// their own copy of the folder name, and they did not all agree. So the app was writing to two
/// different folders depending on which store you asked, and renaming the folder meant finding
/// seven literals and getting all seven right. One owner instead: change `name` here and
/// everything follows.
///
/// It also does the three things a data directory should do and none of those seven did:
///
///   * **migrates** the old folder rather than orphaning it. A rename on the same volume is what
///     `FileManager.moveItem` performs, so the move is atomic - there is no window where half the
///     notes are in one folder and half in the other.
///   * **creates it owner-only** (0o700). The old call sites let it default to the process umask,
///     which is 0o755 - world-readable. `Application Support` is itself 0o700 so nothing could
///     traverse in, but a directory holding dictation transcripts should not be relying on its
///     parent for that.
///   * **cannot trap.** Every old call site did
///     `urls(for:in:).first!`, a force unwrap on a lookup that is allowed to return an empty
///     array. It never has in practice, which is exactly why it would be an unexplained launch
///     crash if it ever did.
package enum AppDirectory {

    /// The folder name.
    static let name = "Utter"

    /// The names to migrate away from, **newest first**.
    ///
    /// **These literals are deliberate historical data and must survive any future de-brand.**
    /// The app has been renamed twice - `AWSFlow` was the original working title, `Lumen` came
    /// next, and `Utter` is current. Neither old name is branding any more: each is the on-disk
    /// name of a real folder on the Mac of anyone who ran a build from that era, and they are the
    /// only things that find their notes, dictation history and crash logs. A future sweep for an
    /// old name will find these and want to "finish the job"; removing them orphans that user's
    /// data silently, with no error and nothing to recover from.
    ///
    /// Order is load-bearing. `resolve()` takes the **first** name that exists on disk, so the
    /// newest wins: someone who ran an `AWSFlow` build and then a `Lumen` build has both folders,
    /// and `Lumen` is the one holding the notes they can actually remember writing. Appending a
    /// future name to the end of this array would migrate the *oldest* data and abandon the rest  - 
    /// new names go at the **front**.
    ///
    /// Their twin is the same list in the permission-reset step of `scripts/build-app.sh`. Both
    /// stay until it is worth assuming nobody is upgrading from that era any more.
    static let legacyNames = ["Lumen", "AWSFlow"]

    /// `~/Library/Application Support/Utter`, migrated, created, and owner-only.
    ///
    /// Resolved once per launch: the migration must not race two stores initialising at the same
    /// time, and `static let` gives the one-time, thread-safe initialisation that guarantees it.
    package static let support: URL = resolve()

    /// A file directly inside the support directory.
    static func file(_ name: String) -> URL {
        support.appendingPathComponent(name)
    }

    /// A subdirectory, created if it does not exist yet.
    static func subdirectory(_ name: String) -> URL {
        let url = support.appendingPathComponent(name, isDirectory: true)
        create(url)
        return url
    }

    /// Every folder an earlier name of this app may have left behind.
    ///
    /// **Plural, and that is the point.** Its one caller is "Reset Utter", which promises to
    /// delete everything; with two old names a single URL would delete one folder and silently
    /// leave the other sitting there full of transcripts. A privacy control that keeps data it
    /// says it destroyed is worse than no control, so this returns all of them and the caller
    /// removes each.
    ///
    /// Not filtered by existence - `removeItem` on a missing path is already a no-op, and a
    /// `fileExists` check here would be a race with nothing to gain.
    package static var legacySupportDirectories: [URL] {
        guard let base = base() else { return [] }
        return legacyNames.map { base.appendingPathComponent($0, isDirectory: true) }
    }

    // MARK: -

    private static func base() -> URL? {
        let fm = FileManager.default
        if let url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return url
        }
        // The documented location, if the lookup ever comes back empty. Better than trapping,
        // and better than silently writing somewhere unexpected.
        return fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
    }

    private static func resolve() -> URL {
        let fm = FileManager.default
        // A throwaway folder for development and screenshots, so a dev build never touches real notes.
        if let custom = ProcessInfo.processInfo.environment["UTTER_DATA_DIR"], !custom.isEmpty {
            let url = URL(fileURLWithPath: custom, isDirectory: true)
            create(url)
            return url
        }
        guard let base = base() else {
            // Nothing sensible is left; the temporary directory at least keeps the app running,
            // and every store already handles a load that finds nothing.
            return fm.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        }
        let url = base.appendingPathComponent(name, isDirectory: true)

        if !fm.fileExists(atPath: url.path) {
            // The newest surviving old folder wins - see the note on `legacyNames`.
            let found = legacyNames
                .map { (name: $0, url: base.appendingPathComponent($0, isDirectory: true)) }
                .filter { fm.fileExists(atPath: $0.url.path) }

            if let migrate = found.first {
                do {
                    try fm.moveItem(at: migrate.url, to: url)
                    print("📁 Moved app data from \(migrate.name) to \(name)")
                    if found.count > 1 {
                        // Deliberately not merged: two files of the same name would mean choosing
                        // which notes to overwrite, and there is no basis for that choice. The
                        // older folders are left untouched rather than deleted, so the data is
                        // still there for anyone who goes looking.
                        let rest = found.dropFirst().map(\.name).joined(separator: ", ")
                        print("ℹ️ Older folders left in place, not merged: \(rest)")
                    }
                } catch {
                    // Keep using the old folder rather than starting empty beside it. Losing sight
                    // of existing notes is far worse than keeping the old name for another launch.
                    print("⚠️ Could not rename data folder: \(error.localizedDescription) - "
                          + "using \(migrate.name)")
                    create(migrate.url)
                    return migrate.url
                }
            }
        } else {
            // The current folder already exists, so nothing is migrated. An old one alongside it
            // means an older build ran after a newer one; say so and leave it alone.
            let stale = legacyNames.filter {
                fm.fileExists(atPath: base.appendingPathComponent($0, isDirectory: true).path)
            }
            if !stale.isEmpty {
                print("ℹ️ Old folder(s) still present alongside \(name): "
                      + stale.joined(separator: ", ") + "; not merged")
            }
        }

        create(url)
        return url
    }

    /// Create `url` if needed, and make sure it is owner-only either way.
    ///
    /// `createDirectory` applies `attributes` only when it actually creates the directory, so an
    /// existing folder - every install that predates this - needs the explicit `setAttributes`.
    private static func create(_ url: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: url,
                                withIntermediateDirectories: true,
                                attributes: [.posixPermissions: 0o700])
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }
}
