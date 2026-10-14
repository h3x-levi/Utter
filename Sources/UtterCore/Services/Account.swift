import AppKit
import Foundation

/// Who is using Utter, as the sign-in provider reported them.
package struct Account: Codable, Equatable, Sendable {
    package var name: String
    package var email: String
    package var photoURL: URL?

    package init(name: String, email: String, photoURL: URL? = nil) {
        self.name = name
        self.email = email
        self.photoURL = photoURL
    }
}

/// The part that talks to Google, plugged in later through `AccountSession.provider`.
///
/// Shaped after GoogleSignIn on macOS: `restorePreviousSignIn`, `signIn(withPresenting:)` and
/// `signOut()`, with the account read from `user.profile`. Throw `CancellationError` when the
/// user closes the browser without signing in, so no error is shown for it.
@MainActor
package protocol SignInProvider: AnyObject {
    /// A fresher copy of the stored account, or nil when there is none or the provider can't tell
    /// (GoogleSignIn's restore needs the network). Nil keeps the stored account signed in.
    func restore() async -> Account?
    func signIn(presenting window: NSWindow?) async throws -> Account
    func signOut()
}

/// The signed-in state the app reads. Sign-in is required only once a provider is set;
/// without one Utter runs as it always has, because nobody could get past the screen.
@MainActor
package final class AccountSession: ObservableObject {
    package static let shared = AccountSession()

    package init(provider: SignInProvider? = nil, defaults: UserDefaults = .standard) {
        self.provider = provider
        self.defaults = defaults
        account = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(Account.self, from: $0) }
    }

    private static let key = "signedInAccount"
    private let defaults: UserDefaults

    /// Kept on this Mac so an offline launch still counts as signed in; only `signOut` clears it.
    @Published package private(set) var account: Account? {
        didSet { defaults.set(account.flatMap { try? JSONEncoder().encode($0) }, forKey: Self.key) }
    }
    @Published package private(set) var isSigningIn = false
    /// Why the last sign-in failed, in a sentence for the screen.
    @Published package private(set) var problem: String?

    /// Set at launch, before `restore`, by whatever connects Google.
    package var provider: SignInProvider?

    package var isRequired: Bool { provider != nil }
    package var needsSignIn: Bool { isRequired && account == nil }

    package func restore() async {
        guard let provider, let fresh = await provider.restore() else { return }
        account = fresh
    }

    @discardableResult
    package func signIn(presenting window: NSWindow?) async -> Bool {
        guard let provider else {
            problem = "Google sign-in isn\u{2019}t connected yet."
            return false
        }
        guard !isSigningIn else { return false }
        isSigningIn = true
        problem = nil
        defer { isSigningIn = false }
        do {
            account = try await provider.signIn(presenting: window)
            return true
        } catch is CancellationError {
            return false
        } catch {
            problem = "Couldn\u{2019}t sign in: \(error.localizedDescription)"
            return false
        }
    }

    package func signOut() {
        provider?.signOut()
        account = nil
        problem = nil
    }
}
