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
    let firstLine = draft
      .components(separatedBy: "\n")
      .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
    let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "New Memo" : String(trimmed.prefix(30))
  }
}
