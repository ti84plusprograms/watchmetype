import AppKit

/// Adds syntax colors only as temporary layout attributes. The NSTextView's
/// actual string, copy/paste content, selection, and undo history stay plain.
enum CodeEditorAppearance {
    static func highlight(_ textView: NSTextView, enabled: Bool) {
        guard let layout = textView.layoutManager else { return }
        let source = textView.string
        let fullRange = NSRange(location: 0, length: (source as NSString).length)
        if fullRange.length > 0 {
            layout.removeTemporaryAttribute(.foregroundColor, forCharacterRange: fullRange)
        }
        guard enabled else { return }

        for token in PythonSyntaxHighlighter.tokenize(source) {
            layout.addTemporaryAttribute(
                .foregroundColor,
                value: color(for: token.kind),
                forCharacterRange: token.range
            )
        }
    }

    private static func color(for kind: PythonHighlightKind) -> NSColor {
        switch kind {
        case .keyword: return .systemPurple
        case .string: return .systemGreen
        case .comment: return .secondaryLabelColor
        case .number, .constant: return .systemOrange
        case .definition: return .systemBlue
        case .decorator: return .systemTeal
        case .builtin: return .systemBlue
        }
    }
}

/// NSTextView-hosted gutter for Code Mode.
///
/// A separate NSRulerView can make SwiftUI's zero-width layout passes leave the
/// document view displaced, with line numbers visible but code and caret blank.
/// Reserve space inside NSTextView instead, so glyphs, insertion point, and
/// line numbers share the same coordinate system and scroll together.
final class CodeDraftTextView: NSTextView {
    static let codeGutterWidth: CGFloat = 42
    static let standardLinePadding: CGFloat = 5

    var onFocusChange: ((Bool) -> Void)?
    var showsCodeLineNumbers: Bool = false {
        didSet {
            if oldValue != showsCodeLineNumbers { needsDisplay = true }
        }
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result { onFocusChange?(true) }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result { onFocusChange?(false) }
        return result
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if showsCodeLineNumbers {
            drawLineNumbers(in: dirtyRect)
        }
    }

    private func drawLineNumbers(in dirtyRect: NSRect) {
        guard let manager = layoutManager, let container = textContainer else { return }
        manager.ensureLayout(for: container)

        let source = string as NSString
        let length = source.length
        let origin = textContainerOrigin
        let visible = visibleRect
        let glyphRect = NSRect(
            x: visible.minX - origin.x,
            y: visible.minY - origin.y,
            width: visible.width,
            height: visible.height
        )
        let glyphRange = manager.glyphRange(forBoundingRect: glyphRect, in: container)
        let characters = manager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let first = min(characters.location, length)
        var index = source.lineRange(for: NSRange(location: first, length: 0)).location
        var number = max(1, CodeInputCore.lineCount(in: source.substring(to: index)))

        let style: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let end = min(length, NSMaxRange(characters) + 1)
        let lastUnit = length > 0 ? source.character(at: length - 1) : 0
        let hasTrailingLine = lastUnit == 10 || lastUnit == 13

        while index <= end {
            // The EOF caret belongs to the last nonempty line unless a newline
            // created an actual trailing empty line.
            if index == length && length > 0 && !hasTrailingLine { break }

            let y: CGFloat
            if length == 0 || index == length {
                let extra = manager.extraLineFragmentRect
                y = (extra.height > 0 ? extra.minY : 0) + origin.y
            } else {
                let glyphIndex = manager.glyphIndexForCharacter(at: index)
                let fragment = manager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
                y = fragment.minY + origin.y
            }

            let label = NSString(string: String(number))
            let size = label.size(withAttributes: style)
            if y + size.height >= visible.minY && y <= visible.maxY
                && y + size.height >= dirtyRect.minY && y <= dirtyRect.maxY {
                label.draw(
                    at: NSPoint(
                        x: max(2, origin.x + container.lineFragmentPadding - size.width - 8),
                        y: y
                    ),
                    withAttributes: style
                )
            }

            if index >= length { break }
            let next = NSMaxRange(source.lineRange(for: NSRange(location: index, length: 0)))
            guard next > index else { break }
            index = next
            number += 1
        }
    }
}
