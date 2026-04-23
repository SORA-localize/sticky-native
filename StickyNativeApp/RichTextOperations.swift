import AppKit

enum RichTextFormattingAction {
  case bold
  case underline
  case strikethrough
  case highlight
}

enum RichTextOperations {
  static func apply(
    action: RichTextFormattingAction,
    to textView: NSTextView,
    range: NSRange,
    baseFont: NSFont
  ) {
    guard range.length > 0, let textStorage = textView.textStorage else { return }
    let targetRange = clampedRange(range, length: textStorage.length)
    guard targetRange.length > 0 else { return }

    textStorage.beginEditing()
    switch action {
    case .bold:
      toggleFontTrait(.boldFontMask, in: targetRange, textStorage: textStorage, baseFont: baseFont)
    case .underline:
      toggleAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, in: targetRange, textStorage: textStorage)
    case .strikethrough:
      toggleAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, in: targetRange, textStorage: textStorage)
    case .highlight:
      toggleAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.32), in: targetRange, textStorage: textStorage)
    }
    textStorage.endEditing()

    updateTypingAttributes(for: textView, range: targetRange, baseFont: baseFont)
  }

  static func isMultiRangeCharacterAttributeChange(_ textView: NSTextView) -> Bool {
    guard let ranges = textView.rangesForUserCharacterAttributeChange else { return false }
    return ranges.count > 1
  }

  static func targetRange(for textView: NSTextView) -> NSRange? {
    let range = textView.rangeForUserCharacterAttributeChange
    guard range.location != NSNotFound, range.length > 0 else { return nil }
    return range
  }

  static func activeActions(
    in range: NSRange,
    textStorage: NSTextStorage,
    baseFont: NSFont
  ) -> Set<RichTextFormattingAction> {
    guard range.length > 0, textStorage.length > 0 else { return [] }
    let targetRange = clampedRange(range, length: textStorage.length)
    guard targetRange.length > 0 else { return [] }

    var active: Set<RichTextFormattingAction> = []

    let boldRuns = attributeRuns(for: .font, in: targetRange, textStorage: textStorage)
    if boldRuns.allSatisfy({ ($0.value as? NSFont).map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } ?? false }) {
      active.insert(.bold)
    }

    if attributeRuns(for: .underlineStyle, in: targetRange, textStorage: textStorage).allSatisfy({ $0.value != nil }) {
      active.insert(.underline)
    }

    if attributeRuns(for: .strikethroughStyle, in: targetRange, textStorage: textStorage).allSatisfy({ $0.value != nil }) {
      active.insert(.strikethrough)
    }

    if attributeRuns(for: .backgroundColor, in: targetRange, textStorage: textStorage).allSatisfy({ $0.value != nil }) {
      active.insert(.highlight)
    }

    return active
  }
}

private extension RichTextOperations {
  struct AttributeRun {
    let range: NSRange
    let value: Any?
  }

  static func toggleFontTrait(
    _ trait: NSFontTraitMask,
    in range: NSRange,
    textStorage: NSTextStorage,
    baseFont: NSFont
  ) {
    let runs = attributeRuns(for: .font, in: range, textStorage: textStorage)
    let shouldApply = !runs.allSatisfy { run in
      let font = (run.value as? NSFont) ?? baseFont
      return NSFontManager.shared.traits(of: font).contains(trait)
    }

    for run in runs {
      let currentFont = (run.value as? NSFont) ?? baseFont
      let nextFont = shouldApply
        ? font(currentFont, adding: trait, baseFont: baseFont)
        : font(currentFont, removing: trait, baseFont: baseFont)
      textStorage.addAttribute(.font, value: nextFont, range: run.range)
    }
  }

  static func toggleAttribute(
    _ key: NSAttributedString.Key,
    value: Any,
    in range: NSRange,
    textStorage: NSTextStorage
  ) {
    let runs = attributeRuns(for: key, in: range, textStorage: textStorage)
    let shouldApply = !runs.allSatisfy { $0.value != nil }

    if shouldApply {
      textStorage.addAttribute(key, value: value, range: range)
    } else {
      textStorage.removeAttribute(key, range: range)
    }
  }

  static func attributeRuns(
    for key: NSAttributedString.Key,
    in range: NSRange,
    textStorage: NSTextStorage
  ) -> [AttributeRun] {
    var runs: [AttributeRun] = []
    textStorage.enumerateAttribute(key, in: range) { value, effectiveRange, _ in
      runs.append(AttributeRun(range: NSIntersectionRange(range, effectiveRange), value: value))
    }
    return runs.filter { $0.range.length > 0 }
  }

  static func updateTypingAttributes(
    for textView: NSTextView,
    range: NSRange,
    baseFont: NSFont
  ) {
    guard let textStorage = textView.textStorage else { return }
    let attributesLocation = min(range.location, max(0, textStorage.length - 1))
    let sourceAttributes = textStorage.length > 0
      ? textStorage.attributes(at: attributesLocation, effectiveRange: nil)
      : textView.typingAttributes

    var typingAttributes = textView.typingAttributes
    typingAttributes.removeValue(forKey: .strikethroughStyle)
    typingAttributes.removeValue(forKey: .backgroundColor)
    typingAttributes.removeValue(forKey: .foregroundColor)
    typingAttributes.removeValue(forKey: .underlineStyle)

    let sourceFont = (sourceAttributes[.font] as? NSFont) ?? baseFont
    var nextFont = baseFont
    if NSFontManager.shared.traits(of: sourceFont).contains(.boldFontMask) {
      nextFont = font(nextFont, adding: .boldFontMask, baseFont: baseFont)
    }

    typingAttributes[.font] = nextFont
    textView.typingAttributes = typingAttributes
  }

  static func font(_ font: NSFont, adding trait: NSFontTraitMask, baseFont: NSFont) -> NSFont {
    let converted = NSFontManager.shared.convert(font, toHaveTrait: trait)
    if NSFontManager.shared.traits(of: converted).contains(trait) {
      return converted
    }
    if trait == .boldFontMask {
      return NSFont.systemFont(ofSize: baseFont.pointSize, weight: .bold)
    }
    return converted
  }

  static func font(_ font: NSFont, removing trait: NSFontTraitMask, baseFont: NSFont) -> NSFont {
    let converted = NSFontManager.shared.convert(font, toNotHaveTrait: trait)
    if !NSFontManager.shared.traits(of: converted).contains(trait) {
      return converted
    }
    if trait == .boldFontMask {
      return NSFont.systemFont(ofSize: baseFont.pointSize)
    }
    return converted
  }

  static func clampedRange(_ range: NSRange, length: Int) -> NSRange {
    guard range.location != NSNotFound else { return NSRange(location: 0, length: 0) }
    let location = min(range.location, length)
    return NSRange(location: location, length: min(range.length, max(0, length - location)))
  }
}
