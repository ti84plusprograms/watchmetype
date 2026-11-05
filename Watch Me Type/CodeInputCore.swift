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
        /// Simulated Code Mode newline, initial pass and revision pass
        /// alike: tagged Escape to dismiss completion, deferred Return,
        /// then Cmd+Left to line start. TypingManager executes the two
        /// passes with separate deferred work items (typing-phase vs
        /// editing-phase schedulers), but the decision is the same.
        case dismissCompletionThenReturnThenReset
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
        if initialSimulated || editing { return .dismissCompletionThenReturnThenReset }
        return .plainReturn
    }

    /// Give editors time to process structural keys; WPM remains the base
    /// speed, but bursty punctuation/newlines are deliberately slower.
    /// The dismissal delay is deliberately well under the 0.25s newline
    /// pause, so the deferred Return always fires before the next
    /// character is scheduled, with margin for a loaded IDE to close
    /// its completion popup. Raising it further would eat into that
    /// margin without adding a delivery check, so it is not a fix for
    /// a Return the IDE drops outright — see README.
    static let suggestionDismissalDelay: TimeInterval = 0.10

    /// Delay between Return and the (single) Cmd+Left line-start
    /// reset. VS Code applies auto-indent asynchronously after Return,
    /// so a Cmd+Left posted immediately after Return can run before
    /// auto-indent lands and do nothing. Delaying the one reset by
    /// 0.05s lets auto-indent land first, while still firing before
    /// the next character (0.25s newline pause).
    ///
    /// Do NOT post a second Cmd+Left as a safety net: VS Code's Home
    /// (Cmd+Left) toggles between the first non-whitespace character
    /// and column 0. On a blank auto-indented line the first
    /// non-whitespace position is the end of the indent, so a second
    /// press after a successful first press moves the cursor back to
    /// the end of the indent and undoes the reset — the app then types
    /// its own spaces on top and the staircase gets worse, which is
    /// exactly what the second-reset attempt (8464a2c) did in testing.
    ///
    /// Option B uses these timings for its indent poll instead of a
    /// Cmd+Left reset: TypingManager reads the cursor column via
    /// Accessibility after Return, waits for it to stabilise, then
    /// adjusts it to the source indent. Polls are spaced by
    /// `lineStartResetPollInterval` and capped at
    /// `lineStartResetMaxAttempts`, so the whole loop still finishes
    /// before the next character (0.25s newline pause). Option A's
    /// closed-loop Cmd+Left reset used the same timings and showed
    /// no change in testing, so it was replaced by B.
    static let lineStartResetDelay: TimeInterval = 0.05
    static let lineStartResetPollInterval: TimeInterval = 0.02
    static let lineStartResetMaxAttempts: Int = 3

    /// Option B (IDE-aware stream): leading indent in spaces, counting
    /// a tab as 4. Used both for the target indent of the next line
    /// and for predicting the IDE's auto-indent.
    static func leadingIndentSpaces(_ line: String) -> Int {
        var count = 0
        for ch in line {
            if ch == " " { count += 1 }
            else if ch == "\t" { count += 4 }
            else { break }
        }
        return count
    }

    /// Target indent of the line starting at `index` in `text`
    /// (the character after a newline), in spaces.
    static func targetIndentAfterNewline(in text: [Character], at index: Int) -> Int {
        var count = 0
        var i = index
        while i < text.count {
            if text[i] == " " { count += 1 }
            else if text[i] == "\t" { count += 4 }
            else { break }
            i += 1
        }
        return count
    }

    /// What VS Code's Python auto-indent usually puts on a new line
    /// after `previousLine`: same indent, plus 4 after a line ending
    /// in `:`, 0 after a blank line. This is a prediction, not a
    /// measurement — TypingManager prefers the AX cursor column when
    /// it can read it, and uses this only when AX gives no column.
    /// It does not model bracket-continuation indent, so it can be
    /// off by 4 on continuation lines; that is a documented limit.
    static func predictedAutoIndent(after previousLine: String) -> Int {
        if previousLine.trimmingCharacters(in: .whitespaces).isEmpty { return 0 }
        let base = leadingIndentSpaces(previousLine)
        if previousLine.trimmingCharacters(in: .whitespaces).hasSuffix(":") { return base + 4 }
        return base
    }

    /// Real-keycode mapping for closing brackets/quotes in Code Mode
    /// simulated typing, on a US ANSI layout. Returns the virtual key
    /// code and whether Shift is held, or nil for any other character.
    ///
    /// Why keycodes, not unicode: VS Code auto-inserts a closer when
    /// the app types an opener (unicode openers do trigger auto-close),
    /// but a closer sent as a unicode string is inserted as text and
    /// does NOT trigger VS Code's overtype of that auto-closer. The
    /// auto-closers are then pushed to the end of the line as a
    /// trailing garbage sequence (e.g. `]))))"` after a correct line).
    /// A closer sent as a real key press is what a human types, so
    /// VS Code overtypes an auto-closer immediately before the cursor,
    /// and simply inserts when there is no auto-closer to overtype
    /// (e.g. inside a string, where VS Code did not auto-close).
    /// Openers are intentionally left as unicode: they already trigger
    /// auto-close correctly, and changing them is not needed.
    static func closingKeyCode(for character: Character) -> (keyCode: UInt16, needsShift: Bool)? {
        switch character {
        case ")": return (0x1D, true)   // Shift + 0
        case "]": return (0x1E, false)  // ]
        case "}": return (0x1E, true)   // Shift + ] — NOT 0x21: Shift + [ is {
        case "\"": return (0x27, true) // Shift + '
        case "'": return (0x27, false) // '
        default: return nil
        }
    }

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
