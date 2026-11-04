import Foundation

/// Deterministic, opt-in macOS UI-test state. Production launches never
/// consult fixture environment variables and retain the normal empty editor.
/// The only activation path is the explicit --wmt-ui-tests launch argument.
enum UIRegressionFixture {
    static let isRunning = ProcessInfo.processInfo.arguments.contains("--wmt-ui-tests")

    static var name: String {
        guard isRunning else { return "" }
        return ProcessInfo.processInfo.environment["WMT_UI_FIXTURE"] ?? "python"
    }

    static var codeMode: Bool {
        isRunning && name != "normal"
    }

    static var forceDarkAppearance: Bool {
        isRunning && ProcessInfo.processInfo.environment["WMT_UI_APPEARANCE"] == "dark"
    }

    static var showDraft2: Bool {
        isRunning && (name == "two-drafts" || name == "three-drafts")
    }

    static var showDraft3: Bool {
        isRunning && name == "three-drafts"
    }

    static let python = """
    def greet(name: str) -> str:
        # Keep indentation and punctuation intact
        if not name:
            return "Hello, world!"
        return f"Hello, {name}!"

    class Greeter:
        def __init__(self, prefix: str):
            self.prefix = prefix

        def say(self, name: str) -> str:
            return f"{self.prefix}, {name}!"

    print(greet("Ada"))
    """

    static var draft1: String {
        guard isRunning else { return "" }
        switch name {
        case "empty":
            return ""
        case "wrapped":
            return "message = " + String(repeating: "'this_is_a_long_unbroken_token_to_test_text_wrapping' + ", count: 8) + "'end'"
        case "scroll":
            return (1...160).map { "print(\"line \($0): scrolling and gutter alignment\")" }
                .joined(separator: "\n")
        case "normal":
            return "Normal mode should keep its existing editing behavior."
        default:
            return python
        }
    }

    static var draft2: String {
        showDraft2 ? python.replacingOccurrences(of: "Ada", with: "Grace") : ""
    }

    static var draft3: String {
        showDraft3 ? python.replacingOccurrences(of: "Ada", with: "Linus") : ""
    }
}
