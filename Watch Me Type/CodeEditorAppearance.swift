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
    static let gutterWidth: CGFloat = 42
    weak var editor: NSTextView?

    init(scrollView: NSScrollView, editor: NSTextView) {
        self.editor = editor
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = editor
        ruleThickness = Self.gutterWidth
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

        // The extra line fragment is used for an empty buffer or a trailing
        // line break; layout must exist before requesting its geometry.
        manager.ensureLayout(for: container)

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
        // Use the shared line-ending policy so CRLF counts as one line.
        let prefix = source.substring(to: index)
        var lineNumber = max(1, CodeInputCore.lineCount(in: prefix))

        let style: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let end = min(size, NSMaxRange(visibleCharacters) + 1)
        let lastUnit = size > 0 ? source.character(at: size - 1) : 0
        let endsWithLineBreak = lastUnit == 10 || lastUnit == 13

        while index <= end {
            // A caret at end-of-file is not another logical line unless the
            // source ends with a line break. An empty document still has line 1.
            if index == size && size > 0 && !endsWithLineBreak { break }

            let y: CGFloat
            if size == 0 || index == size {
                let extra = manager.extraLineFragmentRect
                let origin = NSPoint(
                    x: 0,
                    y: extra.minY + editor.textContainerOrigin.y
                )
                y = editor.convert(origin, to: self).y
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
