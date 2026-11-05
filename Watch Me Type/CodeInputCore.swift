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
    /// Splits on LF, CRLF, and CR-only terminators. The previous implementation
    /// split only on "\n", so a CR-only file was treated as a single line and
    /// any change produced one whole-file replacement instead of a line change.
    /// Splitting on UTF-16 units is safe here: CR (13) and LF (10) never occur
    /// inside a surrogate pair, so no multi-unit character is split.
    static func linesPreservingTerminators(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        let units = Array(text.utf16)
        var lines: [String] = []
        var start = 0
        var index = 0
        while index < units.count {
            if units[index] == 13 {
                // CR, or CRLF as a single terminator.
                var end = index + 1
                if end < units.count && units[end] == 10 { end += 1 }
                lines.append(String(decoding: units[start..<end], as: UTF16.self))
                index = end
                start = end
            } else if units[index] == 10 {
                lines.append(String(decoding: units[start..<(index + 1)], as: UTF16.self))
                index += 1
                start = index
            } else {
                index += 1
            }
        }
        if start < units.count {
            lines.append(String(decoding: units[start..<units.count], as: UTF16.self))
        }
        return lines
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

    /// How a simulated newline is delivered to the target editor.
    /// This decision is pure and SwiftPM-testable; the CGEvent posting
    /// itself lives in TypingManager and cannot be unit-tested here.
    enum NewlineDelivery: Equatable {
        /// Plain Return, as before. Used for prose and as the safe fallback.
        case plainReturn
        /// Initial simulated Code Mode pass: tagged Escape to dismiss
        /// completion, deferred Return, then Cmd+Left to line start.
        case dismissCompletionThenReturnThenReset
        /// Code Mode revision (editing) pass: synchronous Return, then
        /// Cmd+Left to line start. No Escape dismissal, because the
        /// deferred Return and pause-retry machinery are tied to the
        /// typing-phase scheduler, not the editing scheduler.
        case returnThenReset
    }

    /// Decide newline delivery from the caller's phase, without AppKit.
    /// `initialSimulated` means Code Mode, typing state, simulated
    /// strategy (not Exact Insert). `editing` means Code Mode revision
    /// state. Anything else — including prose, and Code Mode with
    /// Exact Insert on the initial pass — falls back to plain Return.
    static func newlineDelivery(
        codeMode: Bool,
        initialSimulated: Bool,
        editing: Bool
    ) -> NewlineDelivery {
        guard codeMode else { return .plainReturn }
        if initialSimulated { return .dismissCompletionThenReturnThenReset }
        if editing { return .returnThenReset }
        return .plainReturn
    }

    /// Give editors time to process structural keys; WPM remains the base
    /// speed, but bursty punctuation/newlines are deliberately slower.
    static let suggestionDismissalDelay: TimeInterval = 0.05

    static func minimumDelay(after character: Character) -> TimeInterval {
        if character == "\n" || character == "\r" {
            // Leave time for Escape -> Return and the editor's input queue.
            return 0.25
        }
        if character == "\t" {
            return 0.12
        }
        if "()[]{}\"'".contains(character) { return 0.06 }
        return 0
    }
}
