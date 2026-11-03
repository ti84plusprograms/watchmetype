import Foundation

/// Pure lexer output. Ranges are UTF-16 offsets so NSTextView can apply
/// temporary display attributes without changing the source or undo history.
enum PythonHighlightKind: Equatable {
    case keyword
    case string
    case comment
    case number
    case definition
    case decorator
    case constant
    case builtin
}

struct PythonHighlight: Equatable {
    let kind: PythonHighlightKind
    let range: NSRange
}

/// A lightweight Python-first lexer for source presentation, not compilation.
/// Recognizes strings (including triple quotes), comments, identifiers,
/// decorators, common constants, and numbers. F-string interpolation is
/// colored as part of the string; nested expressions are not parsed.
enum PythonSyntaxHighlighter {
    private static let keywords: Set<String> = [
        "and", "as", "assert", "async", "await", "break", "case", "class",
        "continue", "def", "del", "elif", "else", "except", "finally",
        "for", "from", "global", "if", "import", "in", "is", "lambda",
        "match", "nonlocal", "not", "or", "pass", "raise", "return",
        "try", "while", "with", "yield"
    ]
    private static let constants: Set<String> = ["True", "False", "None", "Ellipsis", "NotImplemented"]
    private static let builtins: Set<String> = [
        "abs", "all", "any", "bool", "bytes", "dict", "enumerate",
        "filter", "float", "int", "isinstance", "len", "list", "map",
        "max", "min", "object", "open", "print", "range", "reversed",
        "round", "set", "sorted", "str", "sum", "super", "tuple", "type", "zip"
    ]

    static func tokenize(_ source: String) -> [PythonHighlight] {
        let units = Array(source.utf16)
        let count = units.count
        var highlights: [PythonHighlight] = []
        var position = 0
        var expectsDefinition = false
        var atLineStart = true

        func isAsciiLetter(_ value: UInt16) -> Bool {
            (65...90).contains(value) || (97...122).contains(value)
        }
        func isDigit(_ value: UInt16) -> Bool {
            (48...57).contains(value)
        }
        func isIdentifierStart(_ value: UInt16) -> Bool {
            value == 95 || isAsciiLetter(value)
        }
        func isIdentifierPart(_ value: UInt16) -> Bool {
            isIdentifierStart(value) || isDigit(value)
        }
        func isQuote(_ value: UInt16) -> Bool {
            value == 34 || value == 39
        }
        func isStringPrefix(_ value: UInt16) -> Bool {
            // b, f, r, and u, in either case
            [UInt16(66), 70, 82, 85, 98, 102, 114, 117].contains(value)
        }
        func append(_ kind: PythonHighlightKind, _ start: Int, _ end: Int) {
            guard end > start else { return }
            highlights.append(PythonHighlight(kind: kind, range: NSRange(location: start, length: end - start)))
        }

        while position < count {
            let c = units[position]
            if c == 10 || c == 13 {
                position += 1
                atLineStart = true
                expectsDefinition = false
                continue
            }
            if c == 9 || c == 32 {
                position += 1
                continue
            }

            let isFirstOnLine = atLineStart
            atLineStart = false

            // Comment markers inside strings are handled later by the string scanner.
            if c == 35 {
                let start = position
                while position < count && units[position] != 10 && units[position] != 13 {
                    position += 1
                }
                append(.comment, start, position)
                continue
            }

            if c == 64 && isFirstOnLine && position + 1 < count && isIdentifierStart(units[position + 1]) {
                let start = position
                position += 1
                while position < count &&
                    (isIdentifierPart(units[position]) || units[position] == 46) {
                    position += 1
                }
                append(.decorator, start, position)
                continue
            }

            // A Python string may have an r, f, b or u prefix (or a pair).
            // Scan it before identifiers so e.g. f"# not a comment" stays one string.
            var quotePosition = position
            if !isQuote(c) && isStringPrefix(c) {
                var candidate = position
                while candidate < count && candidate - position < 2 && isStringPrefix(units[candidate]) {
                    candidate += 1
                }
                if candidate < count && isQuote(units[candidate]) {
                    quotePosition = candidate
                }
            }
            if quotePosition < count && isQuote(units[quotePosition]) {
                let start = position
                let quote = units[quotePosition]
                let triple = quotePosition + 2 < count
                    && units[quotePosition + 1] == quote
                    && units[quotePosition + 2] == quote
                position = quotePosition + (triple ? 3 : 1)

                while position < count {
                    if units[position] == 92 { // Backslash escapes the next unit.
                        position = min(position + 2, count)
                        continue
                    }
                    if units[position] == quote {
                        if !triple {
                            position += 1
                            break
                        }
                        if position + 2 < count && units[position + 1] == quote && units[position + 2] == quote {
                            position += 3
                            break
                        }
                    }
                    if !triple && (units[position] == 10 || units[position] == 13) {
                        break
                    }
                    position += 1
                }
                append(.string, start, position)
                continue
            }

            if isIdentifierStart(c) {
                let start = position
                position += 1
                while position < count && isIdentifierPart(units[position]) {
                    position += 1
                }
                let word = String(decoding: units[start..<position], as: UTF16.self)
                let kind: PythonHighlightKind?
                if expectsDefinition {
                    kind = .definition
                    expectsDefinition = false
                } else if keywords.contains(word) {
                    kind = .keyword
                    if word == "def" || word == "class" { expectsDefinition = true }
                } else if constants.contains(word) {
                    kind = .constant
                } else if builtins.contains(word) {
                    kind = .builtin
                } else {
                    kind = nil
                }
                if let kind { append(kind, start, position) }
                continue
            }

            if isDigit(c) {
                let start = position
                position += 1
                while position < count {
                    let next = units[position]
                    if isIdentifierPart(next) || next == 46 {
                        position += 1
                    } else if (next == 43 || next == 45) && position > start
                                && (units[position - 1] == 101 || units[position - 1] == 69) {
                        position += 1
                    } else {
                        break
                    }
                }
                append(.number, start, position)
                continue
            }

            // A definition name must follow def/class, not arbitrary punctuation.
            if expectsDefinition { expectsDefinition = false }
            position += 1
        }
        return highlights
    }
}
