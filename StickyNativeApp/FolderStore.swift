import Foundation

/// SQLiteStore の folder CRUD メソッドへの委譲ラッパー。
/// PersistenceCoordinator が保持し、folder 操作はここを経由する。
@MainActor
final class FolderStore {
  private let store: SQLiteStore

  init(store: SQLiteStore) {
    self.store = store
  }

  @discardableResult
  func create(name: String) -> Folder? {
    let folder = Folder(id: UUID(), name: name, createdAt: Date(), updatedAt: Date())
    try? store.insertFolder(id: folder.id, name: folder.name)
    return folder
  }

  func rename(id: UUID, name: String) {
    try? store.updateFolder(id: id, name: name)
  }

  func delete(id: UUID) {
    try? store.deleteFolder(id: id)
  }

  func fetchAll() -> [Folder] {
    (try? store.fetchAllFolders()) ?? []
  }

  func assignToMemo(memoID: UUID, folderID: UUID?) {
    try? store.updateMemoFolder(id: memoID, folderID: folderID)
  }
}
