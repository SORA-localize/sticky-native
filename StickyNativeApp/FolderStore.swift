import Foundation
import OSLog

/// SQLiteStore の folder CRUD メソッドへの委譲ラッパー。
/// PersistenceCoordinator が保持し、folder 操作はここを経由する。
@MainActor
final class FolderStore {
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.hori.StickyNative",
    category: "FolderStore"
  )
  private let store: SQLiteStore

  init(store: SQLiteStore) {
    self.store = store
  }

  @discardableResult
  func create(name: String) -> Folder? {
    let folder = Folder(id: UUID(), name: name, createdAt: Date(), updatedAt: Date())
    do {
      try store.insertFolder(id: folder.id, name: folder.name)
      return folder
    } catch {
      logFailure("create folder \(folder.id.uuidString)", error)
      return nil
    }
  }

  func rename(id: UUID, name: String) {
    do {
      try store.updateFolder(id: id, name: name)
    } catch {
      logFailure("rename folder \(id.uuidString)", error)
    }
  }

  func delete(id: UUID) {
    do {
      try store.deleteFolder(id: id)
    } catch {
      logFailure("delete folder \(id.uuidString)", error)
    }
  }

  func fetchAll() -> [Folder] {
    do {
      return try store.fetchAllFolders()
    } catch {
      logFailure("fetch all folders", error)
      return []
    }
  }

  func assignToMemo(memoID: UUID, folderID: UUID?) {
    do {
      try store.updateMemoFolder(id: memoID, folderID: folderID)
    } catch {
      logFailure("assign folder for memo \(memoID.uuidString)", error)
    }
  }

  private func logFailure(_ operation: String, _ error: Error) {
    logger.error("Folder operation failed: \(operation, privacy: .public): \(error.localizedDescription, privacy: .public)")
  }
}
