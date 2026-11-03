import Foundation

/// The two editor-agnostic delivery strategies for source code.
/// Exact insertion sends one standard Paste command; simulated typing sends keys.
enum CodeInputStrategy: String, CaseIterable, Identifiable {
    case simulated
    case exactInsert

    var id: Self { self }
}

/// A single changed region aligned to complete lines. This avoids applying
/// prose sentence heuristics to braces, indentation and punctuation.
struct CodeLineReplacement: Equatable {
    let position: Int
    let removed: String
    let inserted: String
}

enum CodeInputCore {
    /// Keep the original newline characters, trailing newline, and empty lines.
    static func linesPreservingTerminators(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        let parts = text.components(separatedBy: "\n")
        return parts.enumerated().compactMap { index, part in
            if index < parts.count - 1 { return part + "\n" }
            return part.isEmpty ? nil : part
        }
    }

    /// Produce one safe, line-aligned replacement spanning the changed region.
    /// No tokenization or semantic understanding of the programming language.
    static func changedLineRegion(from oldText: String, to newText: String) -> CodeLineReplacement? {
        guard oldText != newText else { return nil }

        let oldLines = linesPreservingTerminators(oldText)
        let newLines = linesPreservingTerminators(newText)
        var sharedPrefix = 0
        while sharedPrefix < min(oldLines.count, newLines.count)
            && oldLines[sharedPrefix] == newLines[sharedPrefix] {
            sharedPrefix += 1
        }

        var sharedSuffix = 0
        while sharedSuffix < oldLines.count - sharedPrefix
            && sharedSuffix < newLines.count - sharedPrefix
            && oldLines[oldLines.count - 1 - sharedSuffix] == newLines[newLines.count - 1 - sharedSuffix] {
            sharedSuffix += 1
        }

        let position = oldLines.prefix(sharedPrefix).reduce(0) { $0 + $1.count }
        let oldEnd = oldLines.count - sharedSuffix
        let newEnd = newLines.count - sharedSuffix
        let removed = oldLines[sharedPrefix..<oldEnd].joined()
        let inserted = newLines[sharedPrefix..<newEnd].joined()

        return CodeLineReplacement(position: position, removed: removed, inserted: inserted)
    }

    /// Logical line count including a trailing empty line. Handles CR, LF,
    /// and CRLF as one line break without altering source bytes.
    static func lineCount(in source: String) -> Int {
        guard !source.isEmpty else { return 0 }
        var count = 1
        var previousWasCR = false
        for unit in source.utf16 {
            if unit == 13 {
                count += 1
            } else if unit == 10 && !previousWasCR {
                count += 1
            }
            previousWasCR = (unit == 13)
        }
        return count
    }

    /// Give editors time to process structural keys; WPM remains the base
    /// speed, but bursty punctuation/newlines are deliberately slower.
    static func minimumDelay(after character: Character) -> TimeInterval {
        if character == "\n" || character == "\r" || character == "\t" {
            return 0.12
        }
        if "()[]{}\"'".contains(character) { return 0.06 }
        return 0
    }
}
