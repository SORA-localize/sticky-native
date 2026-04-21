import Foundation

@MainActor
final class PersistenceCoordinator {
  private let store: SQLiteStore
  private let folderStore: FolderStore

  init(store: SQLiteStore) {
    self.store = store
    self.folderStore = FolderStore(store: store)
  }

  func saveDraft(id: UUID, draft: String, colorIndex: Int) {
    let title = Self.generateTitle(from: draft)
    try? store.upsertDraft(id: id, draft: draft, title: title, colorIndex: colorIndex)
  }

  static func generateTitle(from draft: String) -> String {
    MemoTitleFormatter.generatedTitle(from: draft)
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

  func saveListPinned(id: UUID, isPinned: Bool) {
    try? store.updateListPinned(id: id, isPinned: isPinned)
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

  func permanentDelete(id: UUID) {
    try? store.permanentDelete(id: id)
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

  // MARK: - Folder

  var isFolderReady: Bool { store.isSessionReady }

  @discardableResult
  func createFolder(name: String) -> Folder? {
    folderStore.create(name: name)
  }

  func renameFolder(id: UUID, name: String) {
    folderStore.rename(id: id, name: name)
  }

  func deleteFolder(id: UUID) {
    folderStore.delete(id: id)
  }

  func fetchAllFolders() -> [Folder] {
    folderStore.fetchAll()
  }

  func assignFolder(memoID: UUID, folderID: UUID?) {
    folderStore.assignToMemo(memoID: memoID, folderID: folderID)
  }
}
