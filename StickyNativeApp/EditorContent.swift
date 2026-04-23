import AppKit

struct EditorContent {
  let plainText: String
  let richTextData: Data?

  init(plainText: String, richTextData: Data? = nil) {
    self.plainText = plainText
    self.richTextData = richTextData
  }

  init(attributedString: NSAttributedString) {
    self.plainText = attributedString.string
    self.richTextData = RichTextContentCodec.encode(attributedString)
  }
}
