import AppKit

enum RichTextContentCodec {
  private static let defaultBaseFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)

  static func hasPersistableAttributes(
    _ attributedString: NSAttributedString,
    baseFont: NSFont = defaultBaseFont
  ) -> Bool {
    sanitizedAttributedString(from: attributedString, baseFont: baseFont).hasPersistableAttributes
  }

  static func encode(
    _ attributedString: NSAttributedString,
    baseFont: NSFont = defaultBaseFont
  ) -> Data? {
    let sanitized = sanitizedAttributedString(from: attributedString, baseFont: baseFont)
    guard sanitized.hasPersistableAttributes else { return nil }
    let range = NSRange(location: 0, length: sanitized.attributedString.length)
    return try? sanitized.attributedString.data(
      from: range,
      documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
    )
  }

  static func decode(_ data: Data, baseFont: NSFont = defaultBaseFont) -> NSAttributedString? {
    guard let decoded = try? NSAttributedString(
      data: data,
      options: [.documentType: NSAttributedString.DocumentType.rtf],
      documentAttributes: nil
    ) else {
      return nil
    }
    return sanitizedAttributedString(from: decoded, baseFont: baseFont).attributedString
  }
}

private extension RichTextContentCodec {
  struct SanitizedAttributedString {
    let attributedString: NSAttributedString
    let hasPersistableAttributes: Bool
  }

  static func sanitizedAttributedString(
    from attributedString: NSAttributedString,
    baseFont: NSFont
  ) -> SanitizedAttributedString {
    let sanitized = NSMutableAttributedString(
      string: attributedString.string,
      attributes: [.font: baseFont]
    )

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

    attributedString.enumerateAttributes(in: fullRange) { attributes, range, _ in
      if let font = attributes[.font] as? NSFont {
        let traits = NSFontManager.shared.traits(of: font)
        let normalizedFont = fontWithPersistedTraits(from: traits, baseFont: baseFont)
        sanitized.addAttribute(.font, value: normalizedFont, range: range)
      }

      if let strikethroughStyle = attributes[.strikethroughStyle] {
        sanitized.addAttribute(.strikethroughStyle, value: strikethroughStyle, range: range)
      }

      if let backgroundColor = attributes[.backgroundColor] {
        sanitized.addAttribute(.backgroundColor, value: backgroundColor, range: range)
      }
    }

    return SanitizedAttributedString(
      attributedString: sanitized,
      hasPersistableAttributes: hasAttributes
    )
  }

  static func fontWithPersistedTraits(from traits: NSFontTraitMask, baseFont: NSFont) -> NSFont {
    let manager = NSFontManager.shared
    var font = baseFont
    if traits.contains(.boldFontMask) {
      font = manager.convert(font, toHaveTrait: .boldFontMask)
    }
    if traits.contains(.italicFontMask) {
      font = manager.convert(font, toHaveTrait: .italicFontMask)
    }
    return font
  }
}
