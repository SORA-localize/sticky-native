import AppKit

enum RichTextContentCodec {
  static func hasPersistableAttributes(_ attributedString: NSAttributedString) -> Bool {
    var hasAttributes = false
    let fullRange = NSRange(location: 0, length: attributedString.length)
    attributedString.enumerateAttributes(in: fullRange) { attributes, _, stop in
      if attributes[.strikethroughStyle] != nil || attributes[.backgroundColor] != nil {
        hasAttributes = true
        stop.pointee = true
        return
      }

      if let font = attributes[.font] as? NSFont {
        let traits = NSFontManager.shared.traits(of: font)
        if traits.contains(.boldFontMask) || traits.contains(.italicFontMask) {
          hasAttributes = true
          stop.pointee = true
        }
      }
    }
    return hasAttributes
  }

  static func encode(_ attributedString: NSAttributedString) -> Data? {
    guard hasPersistableAttributes(attributedString) else { return nil }
    let range = NSRange(location: 0, length: attributedString.length)
    return try? attributedString.data(
      from: range,
      documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
    )
  }

  static func decode(_ data: Data) -> NSAttributedString? {
    try? NSAttributedString(
      data: data,
      options: [.documentType: NSAttributedString.DocumentType.rtf],
      documentAttributes: nil
    )
  }
}
