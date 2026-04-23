import AppKit

enum RichTextContentCodec {
  static func encode(_ attributedString: NSAttributedString) -> Data? {
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
