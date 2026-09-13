import AppKit

@MainActor
struct PasteboardSnapshot {
    private struct Representation {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }

    private let items: [[Representation]]

    init(_ pasteboard: NSPasteboard) {
        self.items = (pasteboard.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in
                item.data(forType: type).map { Representation(type: type, data: $0) }
            }
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        let restoredItems = self.items.map { representations in
            let item = NSPasteboardItem()
            for representation in representations {
                item.setData(representation.data, forType: representation.type)
            }
            return item
        }
        pasteboard.clearContents()
        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }
}
