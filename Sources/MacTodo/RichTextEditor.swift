import AppKit
import SwiftUI

/// Görev açıklaması için biçimlendirilebilir metin düzenleyici. İçerik RTF olarak saklanır.
struct RichTextEditor: NSViewRepresentable {
    let rtf: Data?
    let fallbackText: String
    let controller: RichTextController
    let onChange: (_ rtf: Data?, _ plainText: String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        // TextKit 1: listelerde Enter ile otomatik madde ekleme burada sorunsuz çalışıyor.
        let textView = NSTextView(usingTextLayoutManager: false)
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFontPanel = true
        textView.isAutomaticLinkDetectionEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 10, height: 12)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        textView.textStorage?.setAttributedString(RichText.decode(rtf, fallback: fallbackText))
        textView.typingAttributes = RichText.defaultAttributes
        textView.delegate = context.coordinator

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        controller.textView = textView
        controller.refresh()
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor

        init(_ parent: RichTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, let storage = textView.textStorage else { return }
            let plain = storage.string.trimmingCharacters(in: .whitespacesAndNewlines)
            parent.onChange(plain.isEmpty ? nil : RichText.encode(storage), plain)
            parent.controller.refresh()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            parent.controller.refresh()
        }
    }
}

enum RichText {
    static let bodyFont = NSFont.systemFont(ofSize: 14)

    static var defaultAttributes: [NSAttributedString.Key: Any] {
        [.font: bodyFont, .foregroundColor: NSColor.textColor]
    }

    static func decode(_ rtf: Data?, fallback: String) -> NSAttributedString {
        let text: NSMutableAttributedString
        if let rtf, let decoded = try? NSMutableAttributedString(
            data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil
        ) {
            text = decoded
        } else {
            text = NSMutableAttributedString(string: fallback, attributes: defaultAttributes)
        }
        // Rengi belirtilmemiş metin açık/koyu moda uysun.
        let full = NSRange(location: 0, length: text.length)
        text.enumerateAttribute(.foregroundColor, in: full) { value, range, _ in
            if value == nil { text.addAttribute(.foregroundColor, value: NSColor.textColor, range: range) }
        }
        return text
    }

    static func encode(_ text: NSAttributedString) -> Data? {
        // Dinamik metin rengi RTF'e sabit siyah olarak yazılmasın.
        let copy = NSMutableAttributedString(attributedString: text)
        let full = NSRange(location: 0, length: copy.length)
        copy.enumerateAttribute(.foregroundColor, in: full) { value, range, _ in
            if (value as? NSColor) == NSColor.textColor { copy.removeAttribute(.foregroundColor, range: range) }
        }
        return try? copy.data(from: full, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }
}

enum TextStyle: CaseIterable, Identifiable {
    case title, heading, body

    var id: Self { self }

    var name: String {
        switch self {
        case .title: "Başlık"
        case .heading: "Alt başlık"
        case .body: "Metin"
        }
    }

    var font: NSFont {
        switch self {
        case .title: .systemFont(ofSize: 22, weight: .bold)
        case .heading: .systemFont(ofSize: 17, weight: .semibold)
        case .body: RichText.bodyFont
        }
    }

    init(font: NSFont) {
        self = font.pointSize >= 22 ? .title : font.pointSize >= 17 ? .heading : .body
    }
}

/// Biçim çubuğunun düzenleyiciye komut göndermesini ve imleçteki biçimi göstermesini sağlar.
@MainActor
@Observable
final class RichTextController {
    @ObservationIgnored weak var textView: NSTextView?

    private(set) var isBold = false
    private(set) var isItalic = false
    private(set) var isUnderlined = false
    private(set) var isStruckThrough = false
    private(set) var style = TextStyle.body
    private(set) var listFormat: NSTextList.MarkerFormat?
    private(set) var isEmpty = true

    func refresh() {
        guard let textView, let storage = textView.textStorage else { return }
        let range = textView.selectedRange()
        let attributes = range.length == 0 || storage.length == 0
            ? textView.typingAttributes
            : storage.attributes(at: min(range.location, storage.length - 1), effectiveRange: nil)

        let font = attributes[.font] as? NSFont ?? RichText.bodyFont
        let traits = NSFontManager.shared.traits(of: font)
        isBold = traits.contains(.boldFontMask)
        isItalic = traits.contains(.italicFontMask)
        isUnderlined = (attributes[.underlineStyle] as? Int ?? 0) != 0
        isStruckThrough = (attributes[.strikethroughStyle] as? Int ?? 0) != 0
        style = TextStyle(font: font)
        listFormat = (attributes[.paragraphStyle] as? NSParagraphStyle)?.textLists.last?.markerFormat
        isEmpty = storage.length == 0
    }

    // MARK: - Karakter biçimi

    func toggleBold() { toggleTrait(.boldFontMask, isOn: isBold) }
    func toggleItalic() { toggleTrait(.italicFontMask, isOn: isItalic) }
    func toggleUnderline() { toggleLine(.underlineStyle, isOn: isUnderlined) }
    func toggleStrikethrough() { toggleLine(.strikethroughStyle, isOn: isStruckThrough) }

    private func toggleTrait(_ trait: NSFontTraitMask, isOn: Bool) {
        let manager = NSFontManager.shared
        edit { textView, storage, range in
            let convert = { (font: NSFont) in
                isOn ? manager.convert(font, toNotHaveTrait: trait) : manager.convert(font, toHaveTrait: trait)
            }
            if range.length == 0 {
                textView.typingAttributes[.font] = convert(textView.typingAttributes[.font] as? NSFont ?? RichText.bodyFont)
                return
            }
            change(textView, storage, range) {
                storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
                    storage.addAttribute(.font, value: convert(value as? NSFont ?? RichText.bodyFont), range: subrange)
                }
            }
        }
    }

    private func toggleLine(_ key: NSAttributedString.Key, isOn: Bool) {
        let value = NSUnderlineStyle.single.rawValue
        edit { textView, storage, range in
            if range.length == 0 {
                textView.typingAttributes[key] = isOn ? nil : value
                return
            }
            change(textView, storage, range) {
                if isOn { storage.removeAttribute(key, range: range) } else { storage.addAttribute(key, value: value, range: range) }
            }
        }
    }

    // MARK: - Paragraf biçimi

    func setStyle(_ style: TextStyle) {
        edit { textView, storage, range in
            let paragraph = (storage.string as NSString).paragraphRange(for: range)
            if paragraph.length > 0 {
                change(textView, storage, paragraph) {
                    storage.addAttribute(.font, value: style.font, range: paragraph)
                }
            }
            textView.typingAttributes[.font] = style.font
        }
    }

    func toggleList(_ format: NSTextList.MarkerFormat) {
        let removing = listFormat == format
        edit { textView, storage, range in
            let string = storage.string as NSString
            let paragraphs = string.paragraphRange(for: range)
            let list = NSTextList(markerFormat: format, options: 0)
            let result = NSMutableAttributedString()
            var number = 1

            func listStyle(from base: NSParagraphStyle?) -> NSParagraphStyle {
                let style = (base ?? .default).mutableCopy() as! NSMutableParagraphStyle
                if removing {
                    style.textLists = []
                    style.tabStops = NSParagraphStyle.default.tabStops
                    style.headIndent = 0
                } else {
                    style.textLists = [list]
                    style.tabStops = [NSTextTab(textAlignment: .left, location: 8), NSTextTab(textAlignment: .left, location: 28)]
                    style.headIndent = 28
                }
                return style
            }

            func marker(_ attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
                defer { number += 1 }
                return NSAttributedString(string: "\t\(list.marker(forItemNumber: number))\t", attributes: attributes)
            }

            string.enumerateSubstrings(in: paragraphs, options: [.byParagraphs, .substringNotRequired]) { _, _, enclosing, _ in
                let paragraph = NSMutableAttributedString(attributedString: storage.attributedSubstring(from: enclosing))
                let current = paragraph.length > 0 ? paragraph.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle : nil

                // Varsa eski madde işaretini kaldır.
                if current?.textLists.isEmpty == false,
                   let match = Self.markerPattern.firstMatch(in: paragraph.string, range: NSRange(location: 0, length: paragraph.length)) {
                    paragraph.deleteCharacters(in: match.range)
                }
                if !removing {
                    let attributes = paragraph.length > 0 ? paragraph.attributes(at: 0, effectiveRange: nil) : textView.typingAttributes
                    paragraph.insert(marker(attributes), at: 0)
                }
                paragraph.addAttribute(.paragraphStyle, value: listStyle(from: current), range: NSRange(location: 0, length: paragraph.length))
                result.append(paragraph)
            }

            let typingStyle = listStyle(from: textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle)
            // İmleç boş son satırdaysa yalnızca işareti ekle.
            if result.length == 0 && !removing {
                var attributes = textView.typingAttributes
                attributes[.paragraphStyle] = typingStyle
                result.append(marker(attributes))
            }

            if textView.shouldChangeText(in: paragraphs, replacementString: result.string) {
                storage.replaceCharacters(in: paragraphs, with: result)
                textView.didChangeText()
                textView.setSelectedRange(NSRange(location: paragraphs.location + result.length - (result.string.hasSuffix("\n") ? 1 : 0), length: 0))
            }
            textView.typingAttributes[.paragraphStyle] = typingStyle
        }
    }

    private static let markerPattern = try! NSRegularExpression(pattern: "^\t[^\t\n]*\t")

    // MARK: - Yardımcılar

    private func edit(_ body: (NSTextView, NSTextStorage, NSRange) -> Void) {
        guard let textView, let storage = textView.textStorage else { return }
        body(textView, storage, textView.selectedRange())
        textView.window?.makeFirstResponder(textView)
        refresh()
    }

    /// Öznitelik değişikliklerini geri alınabilir yapar ve kaydı tetikler.
    private func change(_ textView: NSTextView, _ storage: NSTextStorage, _ range: NSRange, _ body: () -> Void) {
        guard textView.shouldChangeText(in: range, replacementString: nil) else { return }
        storage.beginEditing()
        body()
        storage.endEditing()
        textView.didChangeText()
    }
}

/// Düzenleyicinin üstündeki biçim çubuğu.
struct FormatBar: View {
    let controller: RichTextController

    var body: some View {
        HStack(spacing: 2) {
            Menu {
                ForEach(TextStyle.allCases) { style in
                    Button(style.name) { controller.setStyle(style) }
                }
            } label: {
                Text(controller.style.name)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.trailing, 4)
            .help("Paragraf stili")

            Divider().frame(height: 16)

            button("bold", "Kalın (⌘B)", controller.isBold, controller.toggleBold)
            button("italic", "İtalik (⌘I)", controller.isItalic, controller.toggleItalic)
            button("underline", "Altı çizili (⌘U)", controller.isUnderlined, controller.toggleUnderline)
            button("strikethrough", "Üstü çizili", controller.isStruckThrough, controller.toggleStrikethrough)

            Divider().frame(height: 16)

            button("list.bullet", "Madde işaretli liste", controller.listFormat == .disc) { controller.toggleList(.disc) }
            button("list.number", "Numaralı liste", controller.listFormat == .decimal) { controller.toggleList(.decimal) }

            Spacer(minLength: 0)
        }
    }

    private func button(_ icon: String, _ help: String, _ isOn: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 26, height: 22)
                .foregroundStyle(isOn ? Color.accentColor : Color.primary)
                .background(isOn ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
