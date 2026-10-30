import Foundation

/// Checks whether a copied editor snapshot can safely serve as the source for
/// a character-position-based edit. This deliberately does NOT trim leading or
/// trailing whitespace, remove blank lines, or collapse repeated spaces.
enum DocumentSnapshotCheck: Equatable {
    case exact
    case normalized
    case mismatch(String)
}

enum DocumentSnapshotVerifier {
    static func check(expected: String, copied: String) -> DocumentSnapshotCheck {
        if expected == copied { return .exact }

        let expectedCharacters = Array(expected)
        let copiedCharacters = Array(copied)

        // Even a visually identical string can have shifted offsets. Require
        // the same number of grapheme clusters and identical line-break positions.
        let sameCharacterCount = expectedCharacters.count == copiedCharacters.count
        let sameLineBreakPositions = sameCharacterCount &&
            zip(expectedCharacters, copiedCharacters).allSatisfy {
                isLineBreak($0.0) == isLineBreak($0.1)
            }

        if sameCharacterCount && sameLineBreakPositions &&
            canonicalComparisonText(expected) == canonicalComparisonText(copied) {
            return .normalized
        }

        let firstDifference = zip(expectedCharacters, copiedCharacters)
            .firstIndex(where: { $0.0 != $0.1 }) ??
            min(expectedCharacters.count, copiedCharacters.count)

        let prefix = expectedCharacters.prefix(firstDifference)
        let line = prefix.filter { isLineBreak($0) }.count + 1
        let column = prefix.reversed().prefix { !isLineBreak($0) }.count + 1
        let expectedCharacter = firstDifference < expectedCharacters.count
            ? expectedCharacters[firstDifference] : nil
        let copiedCharacter = firstDifference < copiedCharacters.count
            ? copiedCharacters[firstDifference] : nil

        return .mismatch(
            "Document text mismatch at character \(firstDifference + 1) " +
            "(line \(line), column \(column)). " +
            "Expected \(describe(expectedCharacter)); " +
            "copied \(describe(copiedCharacter)). " +
            "Current Document: \(expectedCharacters.count) characters; " +
            "copied document: \(copiedCharacters.count) characters. " +
            "Blank lines, leading spaces, and trailing whitespace are preserved for safety. " +
            "No edits were made."
        )
    }

    private static func canonicalComparisonText(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .precomposedStringWithCanonicalMapping
    }

    private static func isLineBreak(_ character: Character) -> Bool {
        character == "\n" || character == "\r" ||
            character == "\r\n" || character == "\u{2028}" ||
            character == "\u{2029}"
    }

    private static func describe(_ character: Character?) -> String {
        guard let character else { return "end of document" }
        let name: String
        switch character {
        case " ": name = "SPACE"
        case "\t": name = "TAB"
        case "\n": name = "LINE FEED"
        case "\r": name = "CARRIAGE RETURN"
        case "\r\n": name = "CRLF"
        case "\u{00A0}": name = "NONBREAKING SPACE"
        case "\u{202F}": name = "NARROW NONBREAKING SPACE"
        case "\u{2028}": name = "LINE SEPARATOR"
        case "\u{2029}": name = "PARAGRAPH SEPARATOR"
        default: name = "character"
        }
        let scalars = character.unicodeScalars.map { String(format: "U+%04X", $0.value) }
            .joined(separator: " ")
        return "\(name) (\(scalars))"
    }
}
