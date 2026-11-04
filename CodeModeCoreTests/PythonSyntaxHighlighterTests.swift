import Foundation
import XCTest
@testable import CodeModeCore

final class PythonSyntaxHighlighterTests: XCTestCase {
    private func entries(in source: String) -> [(String, PythonHighlightKind)] {
        let nsSource = source as NSString
        return PythonSyntaxHighlighter.tokenize(source).map {
            (nsSource.substring(with: $0.range), $0.kind)
        }
    }

    func testPythonDefinitionsKeywordsAndBuiltins() {
        let source = "async def greet(name):\n    if name:\n        print(name)\n    return None\n"
        let tokens = entries(in: source)
        XCTAssertTrue(tokens.contains { $0.0 == "async" && $0.1 == .keyword })
        XCTAssertTrue(tokens.contains { $0.0 == "def" && $0.1 == .keyword })
        XCTAssertTrue(tokens.contains { $0.0 == "greet" && $0.1 == .definition })
        XCTAssertTrue(tokens.contains { $0.0 == "print" && $0.1 == .builtin })
        XCTAssertTrue(tokens.contains { $0.0 == "None" && $0.1 == .constant })
        XCTAssertTrue(tokens.contains { $0.0 == "return" && $0.1 == .keyword })
    }

    func testPythonCommentsAndQuotedHashes() {
        let source = "text = '# not a comment'  # actual comment\n"
        let tokens = entries(in: source)
        XCTAssertTrue(tokens.contains { $0.0 == "'# not a comment'" && $0.1 == .string })
        XCTAssertTrue(tokens.contains { $0.0 == "# actual comment" && $0.1 == .comment })
        XCTAssertEqual(tokens.filter { $0.1 == .comment }.count, 1)
    }

    func testTripleQuotedDocstringsIncludingNewlinesAndHashes() {
        let docstring = "\"\"\"hello\n# inside string\nworld\"\"\""
        let source = "def f():\n    " + docstring + "\n    return 1\n"
        let tokens = entries(in: source)
        XCTAssertTrue(tokens.contains { $0.0 == docstring && $0.1 == .string })
        XCTAssertEqual(tokens.filter { $0.1 == .comment }.count, 0)
        XCTAssertTrue(tokens.contains { $0.0 == "1" && $0.1 == .number })
    }

    func testFStringsRawPrefixesAndEscapes() {
        let source = "a = f\"Hi {name}!\"\nb = r'# raw'\nc = 'it\\'s fine'\n"
        let tokens = entries(in: source)
        XCTAssertTrue(tokens.contains { $0.0 == "f\"Hi {name}!\"" && $0.1 == .string })
        XCTAssertTrue(tokens.contains { $0.0 == "r'# raw'" && $0.1 == .string })
        XCTAssertTrue(tokens.contains { $0.0 == "'it\\'s fine'" && $0.1 == .string })
        XCTAssertFalse(tokens.contains { $0.1 == .comment })
    }

    func testRawStringsDoNotEscapeClosingQuote() {
        // In a raw string a backslash does not escape the next character.
        // The old lexer skipped the closing quote and merged the next token
        // into the same string highlight.
        let source = "a = r\"x\\\" + \"y\"\n"
        let tokens = entries(in: source)
        XCTAssertTrue(tokens.contains { $0.0 == "r\"x\\\"" && $0.1 == .string })
        XCTAssertTrue(tokens.contains { $0.0 == "\"y\"" && $0.1 == .string })
        XCTAssertEqual(tokens.filter { $0.1 == .string }.count, 2)

        let path = "p = r\"C:\\new\\file\"\n"
        let pathTokens = entries(in: path)
        XCTAssertTrue(pathTokens.contains { $0.0 == "r\"C:\\new\\file\"" && $0.1 == .string })
        XCTAssertEqual(pathTokens.filter { $0.1 == .string }.count, 1)
    }

    func testDecoratorsClassesAndNumbers() {
        let source = "@dataclass\nclass Point:\n    x = 3.14\n    y = 1e-3\n"
        let tokens = entries(in: source)
        XCTAssertTrue(tokens.contains { $0.0 == "@dataclass" && $0.1 == .decorator })
        XCTAssertTrue(tokens.contains { $0.0 == "Point" && $0.1 == .definition })
        XCTAssertTrue(tokens.contains { $0.0 == "3.14" && $0.1 == .number })
        XCTAssertTrue(tokens.contains { $0.0 == "1e-3" && $0.1 == .number })
    }

    func testUTF16RangesFollowingEmoji() {
        let source = "# 😀\ndef f():\n    return True\n"
        let tokens = PythonSyntaxHighlighter.tokenize(source)
        let nsSource = source as NSString
        for token in tokens {
            XCTAssertGreaterThanOrEqual(token.range.location, 0)
            XCTAssertLessThanOrEqual(NSMaxRange(token.range), nsSource.length)
        }
        XCTAssertTrue(tokens.contains {
            nsSource.substring(with: $0.range) == "def" && $0.kind == .keyword
        })
        XCTAssertTrue(tokens.contains {
            nsSource.substring(with: $0.range) == "True" && $0.kind == .constant
        })
    }

    func testHighlightingNeverChangesSourceAndUsesNonOverlappingRanges() {
        let samples = [
            "def f(x):\n\treturn f\"val {x}\"\n",
            "print(\"\\\"#not a comment\\\"\") # trailing\n",
            "class 名称:\n    pass\n",
            "",
            "x = \"\"\"multi\nline\"\"\"\n"
        ]
        for original in samples {
            let tokens = PythonSyntaxHighlighter.tokenize(original)
            let utf16Count = (original as NSString).length
            var previousEnd = 0
            for token in tokens {
                XCTAssertGreaterThan(token.range.length, 0)
                XCTAssertGreaterThanOrEqual(token.range.location, previousEnd)
                XCTAssertLessThanOrEqual(NSMaxRange(token.range), utf16Count)
                previousEnd = NSMaxRange(token.range)
            }
            XCTAssertEqual((original as NSString).length, utf16Count)
        }
    }

    func testEmptyAndUnterminatedPythonText() {
        XCTAssertTrue(PythonSyntaxHighlighter.tokenize("").isEmpty)
        XCTAssertTrue(entries(in: "\"unterminated").contains { $0.0 == "\"unterminated" && $0.1 == .string })
        XCTAssertTrue(entries(in: "'''no end").contains { $0.0 == "'''no end" && $0.1 == .string })
    }
}
