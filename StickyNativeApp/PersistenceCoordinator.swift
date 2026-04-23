import Foundation
import OSLog

@MainActor
final class PersistenceCoordinator {
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.hori.StickyNative",
    category: "Persistence"
  )
  private let store: SQLiteStore
  private let folderStore: FolderStore

  init(store: SQLiteStore) {
    self.store = store
    self.folderStore = FolderStore(store: store)
  }

  func saveDraft(id: UUID, draft: String, colorIndex: Int) {
    saveMemoContent(id: id, draft: draft, richTextData: nil, colorIndex: colorIndex)
  }

  func saveMemoContent(id: UUID, draft: String, richTextData: Data?, colorIndex: Int) {
    let title = Self.generateTitle(from: draft)
    do {
      try store.upsertContent(
        id: id,
        draft: draft,
        title: title,
        colorIndex: colorIndex,
        richTextData: richTextData
      )
    } catch {
      logFailure("save memo content \(id.uuidString)", error)
    }
  }

  static func generateTitle(from draft: String) -> String {
    MemoTitleFormatter.generatedTitle(from: draft)
  }

  func saveWindowState(id: UUID, frame: NSRect?, isOpen: Bool) {
    do {
      try store.updateWindowState(
        id: id,
        originX: frame.map { Double($0.origin.x) },
        originY: frame.map { Double($0.origin.y) },
        width: frame.map { Double($0.size.width) },
        height: frame.map { Double($0.size.height) },
        isOpen: isOpen
      )
    } catch {
      logFailure("save window state \(id.uuidString)", error)
    }
  }

  func savePinned(id: UUID, isPinned: Bool) {
    do {
      try store.updatePinned(id: id, isPinned: isPinned)
    } catch {
      logFailure("save pinned \(id.uuidString)", error)
    }
  }

  func saveListPinned(id: UUID, isPinned: Bool) {
    do {
      try store.updateListPinned(id: id, isPinned: isPinned)
    } catch {
      logFailure("save list pinned \(id.uuidString)", error)
    }
  }

  func markOpen(id: UUID) {
    do {
      try store.markOpen(id: id)
    } catch {
      logFailure("mark open \(id.uuidString)", error)
    }
  }

  func trashMemo(id: UUID) {
    do {
      try store.trash(id: id)
    } catch {
      logFailure("trash memo \(id.uuidString)", error)
    }
  }

  func restoreMemo(id: UUID) {
    do {
      try store.restore(id: id)
    } catch {
      logFailure("restore memo \(id.uuidString)", error)
    }
  }

  func permanentDelete(id: UUID) {
    do {
      try store.permanentDelete(id: id)
    } catch {
      logFailure("permanent delete memo \(id.uuidString)", error)
    }
  }

  func emptyTrash() {
    do {
      try store.emptyTrash()
    } catch {
      logFailure("empty trash", error)
    }
  }

  func fetchAllMemos() -> [PersistedMemo] {
    do {
      return try store.fetchAll()
    } catch {
      logFailure("fetch all memos", error)
      return []
    }
  }

  func fetchTrashedMemos() -> [PersistedMemo] {
    do {
      return try store.fetchTrashed()
    } catch {
      logFailure("fetch trashed memos", error)
      return []
    }
  }

  func fetchDraft(id: UUID) -> String? {
    do {
      return try store.fetch(id: id)?.draft
    } catch {
      logFailure("fetch draft \(id.uuidString)", error)
      return nil
    }
  }

  func fetchMemo(id: UUID) -> PersistedMemo? {
    do {
      return try store.fetch(id: id)
    } catch {
      logFailure("fetch memo \(id.uuidString)", error)
      return nil
    }
  }

  func fetchOpenMemos() -> [PersistedMemo] {
    do {
      return try store.fetchOpen()
    } catch {
      logFailure("fetch open memos", error)
      return []
    }
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

  private func logFailure(_ operation: String, _ error: Error) {
    logger.error("Persistence operation failed: \(operation, privacy: .public): \(error.localizedDescription, privacy: .public)")
  }
}
