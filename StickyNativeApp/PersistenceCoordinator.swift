import Foundation

@MainActor
final class PersistenceCoordinator {
  private let store: SQLiteStore

  init(store: SQLiteStore) {
    self.store = store
  }

  func saveDraft(id: UUID, draft: String) {
    try? store.upsertDraft(id: id, draft: draft)
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
