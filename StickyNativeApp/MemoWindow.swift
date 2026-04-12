import Foundation

@MainActor
final class MemoWindow: ObservableObject, Identifiable {
  let id: UUID
  let createdAt: Date
  @Published var draft: String

  init(id: UUID = UUID(), createdAt: Date = .now, draft: String = "") {
    self.id = id
    self.createdAt = createdAt
    self.draft = draft
  }

  var title: String {
    "Quick Memo"
  }
}
