import Foundation

@MainActor
final class MemoWindow: ObservableObject, Identifiable {
  let id: UUID
  let createdAt: Date
  let colorTheme: MemoColorTheme
  @Published var draft: String

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    draft: String = "",
    colorTheme: MemoColorTheme = .fallback
  ) {
    self.id = id
    self.createdAt = createdAt
    self.colorTheme = colorTheme
    self.draft = draft
  }

  var title: String {
    MemoTitleFormatter.displayTitle(from: draft)
  }
}
