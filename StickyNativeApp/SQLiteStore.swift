import Foundation
import SQLite3

final class SQLiteStore {
  private var db: OpaquePointer?

  init() throws {
    let url = try Self.storeURL()
    let path = url.path
    guard sqlite3_open(path, &db) == SQLITE_OK else {
      let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
      throw StoreError.openFailed(msg)
    }
    try createSchema()
  }

  deinit {
    sqlite3_close(db)
  }

  // MARK: - Schema

  private func createSchema() throws {
    let sql = """
      CREATE TABLE IF NOT EXISTS memos (
        id         TEXT PRIMARY KEY,
        draft      TEXT NOT NULL,
        origin_x   REAL,
        origin_y   REAL,
        width      REAL,
        height     REAL,
        is_pinned  INTEGER NOT NULL,
        is_open    INTEGER NOT NULL,
        updated_at REAL NOT NULL
      );
      """
    try exec(sql)
  }

  // MARK: - CRUD

  func upsert(_ memo: PersistedMemo) throws {
    let sql = """
      INSERT INTO memos (id, draft, origin_x, origin_y, width, height, is_pinned, is_open, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        draft      = excluded.draft,
        origin_x   = excluded.origin_x,
        origin_y   = excluded.origin_y,
        width      = excluded.width,
        height     = excluded.height,
        is_pinned  = excluded.is_pinned,
        is_open    = excluded.is_open,
        updated_at = excluded.updated_at;
      """
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }

    try prepare(sql, &stmt)
    sqlite3_bind_text(stmt, 1, memo.id.uuidString, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(stmt, 2, memo.draft, -1, SQLITE_TRANSIENT)
    bindOptionalReal(stmt, 3, memo.originX)
    bindOptionalReal(stmt, 4, memo.originY)
    bindOptionalReal(stmt, 5, memo.width)
    bindOptionalReal(stmt, 6, memo.height)
    sqlite3_bind_int(stmt, 7, memo.isPinned ? 1 : 0)
    sqlite3_bind_int(stmt, 8, memo.isOpen ? 1 : 0)
    sqlite3_bind_double(stmt, 9, memo.updatedAt.timeIntervalSince1970)
    try step(stmt)
  }

  // frame と isOpen のみ更新。is_pinned は既存の値を保持する。
  func updateWindowState(
    id: UUID,
    originX: Double?,
    originY: Double?,
    width: Double?,
    height: Double?,
    isOpen: Bool
  ) throws {
    let sql = """
      INSERT INTO memos (id, draft, origin_x, origin_y, width, height, is_pinned, is_open, updated_at)
      VALUES (?, '', ?, ?, ?, ?, 0, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        origin_x   = excluded.origin_x,
        origin_y   = excluded.origin_y,
        width      = excluded.width,
        height     = excluded.height,
        is_open    = excluded.is_open,
        updated_at = excluded.updated_at;
      """
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }

    try prepare(sql, &stmt)
    sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
    bindOptionalReal(stmt, 2, originX)
    bindOptionalReal(stmt, 3, originY)
    bindOptionalReal(stmt, 4, width)
    bindOptionalReal(stmt, 5, height)
    sqlite3_bind_int(stmt, 6, isOpen ? 1 : 0)
    sqlite3_bind_double(stmt, 7, Date.now.timeIntervalSince1970)
    try step(stmt)
  }

  func updatePinned(id: UUID, isPinned: Bool) throws {
    let sql = "UPDATE memos SET is_pinned = ?, updated_at = ? WHERE id = ?;"
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }

    try prepare(sql, &stmt)
    sqlite3_bind_int(stmt, 1, isPinned ? 1 : 0)
    sqlite3_bind_double(stmt, 2, Date.now.timeIntervalSince1970)
    sqlite3_bind_text(stmt, 3, id.uuidString, -1, SQLITE_TRANSIENT)
    try step(stmt)
  }

  func markOpen(id: UUID) throws {
    let sql = "UPDATE memos SET is_open = 1, updated_at = ? WHERE id = ?;"
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }

    try prepare(sql, &stmt)
    sqlite3_bind_double(stmt, 1, Date.now.timeIntervalSince1970)
    sqlite3_bind_text(stmt, 2, id.uuidString, -1, SQLITE_TRANSIENT)
    try step(stmt)
  }

  func upsertDraft(id: UUID, draft: String) throws {
    let sql = """
      INSERT INTO memos (id, draft, is_pinned, is_open, updated_at)
      VALUES (?, ?, 0, 1, ?)
      ON CONFLICT(id) DO UPDATE SET
        draft      = excluded.draft,
        updated_at = excluded.updated_at;
      """
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }

    try prepare(sql, &stmt)
    sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(stmt, 2, draft, -1, SQLITE_TRANSIENT)
    sqlite3_bind_double(stmt, 3, Date.now.timeIntervalSince1970)
    try step(stmt)
  }

  func fetch(id: UUID) throws -> PersistedMemo? {
    let sql = "SELECT id, draft, origin_x, origin_y, width, height, is_pinned, is_open, updated_at FROM memos WHERE id = ?;"
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }

    try prepare(sql, &stmt)
    sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
    guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
    return row(from: stmt)
  }

  func fetchOpen() throws -> [PersistedMemo] {
    let sql = """
      SELECT id, draft, origin_x, origin_y, width, height, is_pinned, is_open, updated_at
      FROM memos WHERE is_open = 1 ORDER BY updated_at ASC;
      """
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }

    try prepare(sql, &stmt)
    var results: [PersistedMemo] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
      if let memo = row(from: stmt) {
        results.append(memo)
      }
    }
    return results
  }

  func fetchAll() throws -> [PersistedMemo] {
    let sql = "SELECT id, draft, origin_x, origin_y, width, height, is_pinned, is_open, updated_at FROM memos;"
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }

    try prepare(sql, &stmt)
    var results: [PersistedMemo] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
      if let memo = row(from: stmt) {
        results.append(memo)
      }
    }
    return results
  }

  // MARK: - Helpers

  private func exec(_ sql: String) throws {
    var errMsg: UnsafeMutablePointer<CChar>?
    guard sqlite3_exec(db, sql, nil, nil, &errMsg) == SQLITE_OK else {
      let msg = errMsg.map { String(cString: $0) } ?? "exec failed"
      sqlite3_free(errMsg)
      throw StoreError.execFailed(msg)
    }
  }

  private func prepare(_ sql: String, _ stmt: inout OpaquePointer?) throws {
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
      let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "prepare failed"
      throw StoreError.execFailed(msg)
    }
  }

  private func step(_ stmt: OpaquePointer?) throws {
    let result = sqlite3_step(stmt)
    guard result == SQLITE_DONE || result == SQLITE_ROW else {
      let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "step failed"
      throw StoreError.execFailed(msg)
    }
  }

  private func bindOptionalReal(_ stmt: OpaquePointer?, _ index: Int32, _ value: Double?) {
    if let value {
      sqlite3_bind_double(stmt, index, value)
    } else {
      sqlite3_bind_null(stmt, index)
    }
  }

  private func row(from stmt: OpaquePointer?) -> PersistedMemo? {
    guard
      let rawID = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
      let id = UUID(uuidString: rawID),
      let rawDraft = sqlite3_column_text(stmt, 1).map({ String(cString: $0) })
    else { return nil }

    let originX = sqlite3_column_type(stmt, 2) != SQLITE_NULL ? sqlite3_column_double(stmt, 2) : nil as Double?
    let originY = sqlite3_column_type(stmt, 3) != SQLITE_NULL ? sqlite3_column_double(stmt, 3) : nil as Double?
    let width   = sqlite3_column_type(stmt, 4) != SQLITE_NULL ? sqlite3_column_double(stmt, 4) : nil as Double?
    let height  = sqlite3_column_type(stmt, 5) != SQLITE_NULL ? sqlite3_column_double(stmt, 5) : nil as Double?

    return PersistedMemo(
      id: id,
      draft: rawDraft,
      originX: originX,
      originY: originY,
      width: width,
      height: height,
      isPinned: sqlite3_column_int(stmt, 6) != 0,
      isOpen: sqlite3_column_int(stmt, 7) != 0,
      updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 8))
    )
  }

  private static func storeURL() throws -> URL {
    guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      throw StoreError.noAppSupportDirectory
    }
    let dir = appSupport.appendingPathComponent("StickyNative", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("memos.db")
  }

  enum StoreError: Error {
    case openFailed(String)
    case execFailed(String)
    case noAppSupportDirectory
  }
}

// Stable pointer for SQLite text binding
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
