import UtterKit

// The executable, and deliberately nothing more.
//
// Every line of Utter lives in the `UtterKit` library; this target exists only to
// launch it. The reason is testability: SwiftPM cannot attach a test target to an
// executable target, so while the app *was* the executable there was no way to write
// a unit test against any of it — `import XCTest` in a test alongside an executable
// target fails to resolve, and `@testable import` has no module to reach into.
//
// Keeping the shim this thin means the untested surface of the app is exactly one
// statement long.
UtterApp.main()
