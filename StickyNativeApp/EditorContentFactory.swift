import AppKit

struct EditorDisplayContent {
  let attributedString: NSAttributedString
  let didFallbackFromRichTextData: Bool
}

enum EditorContentFactory {
  static func makeDisplayContent(draft: String, richTextData: Data?) -> EditorDisplayContent {
    if let richTextData,
       let attributedString = RichTextContentCodec.decode(richTextData) {
      return EditorDisplayContent(
        attributedString: attributedString,
        didFallbackFromRichTextData: false
      )
    }

    return EditorDisplayContent(
      attributedString: NSAttributedString(string: draft),
      didFallbackFromRichTextData: richTextData != nil
    )
  }
}
