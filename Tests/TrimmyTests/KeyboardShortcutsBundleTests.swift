import Foundation
import KeyboardShortcuts
import Testing

@MainActor
struct KeyboardShortcutsBundleTests {
    @Test func `recorder initializes without crashing`() {
        // Regression for missing KeyboardShortcuts resource bundle: constructing the recorder used to trap
        // when Bundle.module could not be resolved in packaged builds.
        _ = KeyboardShortcuts.RecorderCocoa(for: .init("test.keyboardshortcuts.bundle"))
    }
}
