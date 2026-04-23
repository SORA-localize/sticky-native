import AppKit

@MainActor
final class MemoWindow: ObservableObject, Identifiable {
  let id: UUID
  let createdAt: Date
  let colorTheme: MemoColorTheme
  @Published var draft: String
  @Published var attributedContent: NSAttributedString

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    draft: String = "",
    attributedContent: NSAttributedString? = nil,
    colorTheme: MemoColorTheme = .fallback
  ) {
    self.id = id
    self.createdAt = createdAt
    self.colorTheme = colorTheme
    self.draft = draft
    self.attributedContent = attributedContent ?? NSAttributedString(string: draft)
  }

  var title: String {
    MemoTitleFormatter.displayTitle(from: draft)
  }

  func updateAttributedContent(_ attributedContent: NSAttributedString) {
    self.attributedContent = attributedContent
    draft = attributedContent.string
  }
}
