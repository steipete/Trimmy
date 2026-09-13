import AppKit

extension ClipboardMonitor {
    static func struck(original: String, trimmed: String) -> AttributedString {
        let characters = Array(original)
        var removed = Array(repeating: false, count: characters.count)
        for change in Array(trimmed).difference(from: characters) {
            if case let .remove(offset, _, _) = change {
                removed[offset] = true
            }
        }
        let (visible, flags) = PreviewMetrics.mapToVisibleWhitespace(original, removed: removed)
        let preview = NSMutableAttributedString(string: visible)
        var utf16Offset = 0
        for (character, isRemoved) in zip(visible, flags) {
            let length = String(character).utf16.count
            if isRemoved {
                preview.addAttribute(
                    .strikethroughStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    range: NSRange(location: utf16Offset, length: length))
            }
            utf16Offset += length
        }
        return AttributedString(preview)
    }
}
