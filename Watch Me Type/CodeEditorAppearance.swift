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

/// A native gutter aligned with the editor's scroll position and text layout.
/// Shows logical (not wrapped-visual) line numbers.
final class PythonLineNumberRulerView: NSRulerView {
    weak var editor: NSTextView?

    init(scrollView: NSScrollView, editor: NSTextView) {
        self.editor = editor
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = editor
        ruleThickness = 42
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let editor,
              let manager = editor.layoutManager,
              let container = editor.textContainer else { return }

        NSColor.controlBackgroundColor.setFill()
        NSBezierPath(rect: rect).fill()

        let source = editor.string as NSString
        let size = source.length
        let textRect = editor.visibleRect
        let glyphRect = NSRect(
            x: textRect.minX - editor.textContainerOrigin.x,
            y: textRect.minY - editor.textContainerOrigin.y,
            width: textRect.width,
            height: textRect.height
        )
        let visibleGlyphs = manager.glyphRange(forBoundingRect: glyphRect, in: container)
        let visibleCharacters = manager.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)

        let initial = min(visibleCharacters.location, size)
        var index = source.lineRange(for: NSRange(location: initial, length: 0)).location
        let prefix = source.substring(to: index)
        var lineNumber = prefix.reduce(into: 1) { result, c in
            if c == "\n" { result += 1 }
        }

        let style: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let end = min(size, NSMaxRange(visibleCharacters) + 1)
        while index <= end {
            let y: CGFloat
            if size == 0 || index == size {
                // Empty buffer or trailing newline: use an estimated caret line.
                let caret = editor.firstRect(forCharacterRange: NSRange(location: index, length: 0), actualRange: nil)
                y = convert(editor.window?.convertFromScreen(caret).origin ?? .zero, from: nil).y
            } else {
                let glyph = manager.glyphIndexForCharacter(at: index)
                let fragment = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                let origin = NSPoint(x: 0, y: fragment.minY + editor.textContainerOrigin.y)
                y = editor.convert(origin, to: self).y
            }
            let label = NSString(string: String(lineNumber))
            let width = label.size(withAttributes: style).width
            label.draw(at: NSPoint(x: max(3, ruleThickness - width - 9), y: y), withAttributes: style)

            if index >= size { break }
            let next = NSMaxRange(source.lineRange(for: NSRange(location: index, length: 0)))
            guard next > index else { break }
            index = next
            lineNumber += 1
        }
    }
}
