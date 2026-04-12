import Foundation

@MainActor
final class PersistenceCoordinator {
  private let store: SQLiteStore

  init(store: SQLiteStore) {
    self.store = store
  }

  func saveDraft(id: UUID, draft: String) {
    let title = Self.generateTitle(from: draft)
    try? store.upsertDraft(id: id, draft: draft, title: title)
  }

  static func generateTitle(from draft: String) -> String {
    let firstLine = draft
      .components(separatedBy: "\n")
      .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
    return String(firstLine.trimmingCharacters(in: .whitespaces).prefix(50))
  }

  func saveWindowState(id: UUID, frame: NSRect?, isOpen: Bool) {
    try? store.updateWindowState(
      id: id,
      originX: frame.map { Double($0.origin.x) },
      originY: frame.map { Double($0.origin.y) },
      width: frame.map { Double($0.size.width) },
      height: frame.map { Double($0.size.height) },
      isOpen: isOpen
    )
  }

  func savePinned(id: UUID, isPinned: Bool) {
    try? store.updatePinned(id: id, isPinned: isPinned)
  }

  func markOpen(id: UUID) {
    try? store.markOpen(id: id)
  }

  func trashMemo(id: UUID) {
    try? store.trash(id: id)
  }

  func restoreMemo(id: UUID) {
    try? store.restore(id: id)
  }

  func emptyTrash() {
    try? store.emptyTrash()
  }

  func fetchAllMemos() -> [PersistedMemo] {
    (try? store.fetchAll()) ?? []
  }

  func fetchTrashedMemos() -> [PersistedMemo] {
    (try? store.fetchTrashed()) ?? []
  }

  func fetchDraft(id: UUID) -> String? {
    try? store.fetch(id: id)?.draft
  }

  func fetchMemo(id: UUID) -> PersistedMemo? {
    try? store.fetch(id: id)
  }

  func fetchOpenMemos() -> [PersistedMemo] {
    (try? store.fetchOpen()) ?? []
  }
}
