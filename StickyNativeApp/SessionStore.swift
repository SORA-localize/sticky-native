import Foundation

/// SQLiteStore の session CRUD メソッドへの委譲ラッパー。
/// PersistenceCoordinator が保持し、session 操作はここを経由する。
@MainActor
final class SessionStore {
  private let store: SQLiteStore

  init(store: SQLiteStore) {
    self.store = store
  }

  @discardableResult
  func create(name: String) -> Session? {
    let session = Session(id: UUID(), name: name, createdAt: Date(), updatedAt: Date())
    try? store.insertSession(id: session.id, name: session.name)
    return session
  }

  func rename(id: UUID, name: String) {
    try? store.updateSession(id: id, name: name)
  }

  func delete(id: UUID) {
    try? store.deleteSession(id: id)
  }

  func fetchAll() -> [Session] {
    (try? store.fetchAllSessions()) ?? []
  }

  func assignToMemo(memoID: UUID, sessionID: UUID?) {
    try? store.updateMemoSession(id: memoID, sessionID: sessionID)
  }
}
