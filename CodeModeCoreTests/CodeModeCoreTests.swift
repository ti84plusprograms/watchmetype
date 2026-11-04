import XCTest
@testable import CodeModeCore

final class CodeModeCoreTests: XCTestCase {
    private func apply(_ replacement: CodeLineReplacement?, to original: String) -> String {
        guard let replacement else { return original }
        var characters = Array(original)
        let end = replacement.position + replacement.removed.count
        XCTAssertLessThanOrEqual(end, characters.count)
        XCTAssertEqual(String(characters[replacement.position..<end]), replacement.removed)
        characters.replaceSubrange(replacement.position..<end, with: Array(replacement.inserted))
        return String(characters)
    }

    func testExactWhitespaceRoundTrip() {
        let snippets = [
            "def f():\n    if x:\n        print('hi')\n\n",
            "func run() {\n\tprint(1)\n}\n",
            "const a = { x: [1, 2] };\n",
            "x\r\ny\r\n\r\nz",
            "  leading\n  trailing  ",
            ""
        ]
        for snippet in snippets {
            XCTAssertEqual(CodeInputCore.linesPreservingTerminators(snippet).joined(), snippet)
            XCTAssertNil(CodeInputCore.changedLineRegion(from: snippet, to: snippet))
        }
    }

    func testChangePreservesUnchangedIndentation() {
        let old = "def f():\n    x = 1\n\n    return x\n"
        let new = "def f():\n    x = 2\n\n    return x\n"
        let change = CodeInputCore.changedLineRegion(from: old, to: new)
        XCTAssertEqual(change?.position, "def f():\n".count)
        XCTAssertEqual(change?.removed, "    x = 1\n")
        XCTAssertEqual(change?.inserted, "    x = 2\n")
        XCTAssertEqual(apply(change, to: old), new)
    }

    func testInsertDeleteBlankLinesAndTabs() {
        let pairs = [
            ("a\nb\n", "a\n\nb\n"),
            ("a\n\nb\n", "a\nb\n"),
            ("x\n", "x\n\tindent\n"),
            ("x\n\tindent\n", "x\n"),
            ("", "hello\n"),
            ("hello\n", "")
        ]
        for (old, new) in pairs {
            XCTAssertEqual(apply(CodeInputCore.changedLineRegion(from: old, to: new), to: old), new)
        }
    }

    func testEditsWithPunctuationAndMultipleChangedLines() {
        let old = "function f() {\n  return [1];\n}\n"
        let new = "function f() {\n  const x = [1, 2];\n  return x;\n}\n"
        XCTAssertEqual(apply(CodeInputCore.changedLineRegion(from: old, to: new), to: old), new)
    }

    func testUnicodeAndWindowsLineEndings() {
        let old = "let π = 3.14\r\n\tprint(π)\r\n"
        let new = "let π = 3.14159\r\n\tprint(π)\r\n"
        XCTAssertEqual(apply(CodeInputCore.changedLineRegion(from: old, to: new), to: old), new)
    }

    func testClassicMacAndMixedLineEndings() {
        // CR-only text previously collapsed to a single line, so any change
        // became a whole-file replacement.
        let oldCR = "a\rb\rc\r"
        let newCR = "a\rb\rd\r"
        XCTAssertEqual(CodeInputCore.linesPreservingTerminators(oldCR), ["a\r", "b\r", "c\r"])
        XCTAssertEqual(CodeInputCore.linesPreservingTerminators(oldCR).joined(), oldCR)
        XCTAssertEqual(apply(CodeInputCore.changedLineRegion(from: oldCR, to: newCR), to: oldCR), newCR)

        let mixed = "a\r\nb\rc\n"
        XCTAssertEqual(CodeInputCore.linesPreservingTerminators(mixed), ["a\r\n", "b\r", "c\n"])
        XCTAssertEqual(CodeInputCore.linesPreservingTerminators(mixed).joined(), mixed)
        XCTAssertEqual(CodeInputCore.linesPreservingTerminators("a\n\n"), ["a\n", "\n"])
    }

    func testLineCountWithUnixWindowsAndClassicMacLineEndings() {
        XCTAssertEqual(CodeInputCore.lineCount(in: ""), 0)
        XCTAssertEqual(CodeInputCore.lineCount(in: "def f():\n    pass\n"), 3)
        XCTAssertEqual(CodeInputCore.lineCount(in: "a\r\nb\r\n"), 3)
        XCTAssertEqual(CodeInputCore.lineCount(in: "a\rb\r"), 3)
        XCTAssertEqual(CodeInputCore.lineCount(in: "  only spaces  "), 1)
    }

    func testStructuralPacing() {
        XCTAssertGreaterThanOrEqual(CodeInputCore.minimumDelay(after: "\n"), 0.1)
        XCTAssertGreaterThanOrEqual(CodeInputCore.minimumDelay(after: "\t"), 0.1)
        XCTAssertGreaterThan(CodeInputCore.minimumDelay(after: "{"), 0)
        XCTAssertEqual(CodeInputCore.minimumDelay(after: "a"), 0)
    }

    func testInputStrategiesRemainDistinct() {
        XCTAssertEqual(CodeInputStrategy.allCases, [.simulated, .exactInsert])
        XCTAssertNotEqual(CodeInputStrategy.simulated, .exactInsert)
    }
}
