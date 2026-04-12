import Foundation
import SQLite3

final class SQLiteStore {
  private var db: OpaquePointer?

  // SELECT で使う標準列順
  // 0:id 1:draft 2:title 3:origin_x 4:origin_y 5:width 6:height
  // 7:is_pinned 8:is_open 9:is_trashed 10:created_at 11:updated_at
  private static let selectColumns = """
    id, draft, title, origin_x, origin_y, width, height,
    is_pinned, is_open, is_trashed, created_at, updated_at
    """

  init() throws {
    let url = try Self.storeURL()
    let path = url.path
    guard sqlite3_open(path, &db) == SQLITE_OK else {
      let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
      throw StoreError.openFailed(msg)
    }
    try createSchema()
    try migrate()
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
        title      TEXT NOT NULL DEFAULT '',
        origin_x   REAL,
        origin_y   REAL,
        width      REAL,
        height     REAL,
        is_pinned  INTEGER NOT NULL DEFAULT 0,
        is_open    INTEGER NOT NULL DEFAULT 1,
        is_trashed INTEGER NOT NULL DEFAULT 0,
        created_at REAL,
        updated_at REAL NOT NULL
      );
      """
    try exec(sql)
  }

  private func migrate() throws {
    let existing = try fetchColumnNames()
    if !existing.contains("title") {
      try exec("ALTER TABLE memos ADD COLUMN title TEXT NOT NULL DEFAULT '';")
    }
    if !existing.contains("is_trashed") {
      try exec("ALTER TABLE memos ADD COLUMN is_trashed INTEGER NOT NULL DEFAULT 0;")
    }
    if !existing.contains("created_at") {
      try exec("ALTER TABLE memos ADD COLUMN created_at REAL;")
    }
  }

  private func fetchColumnNames() throws -> Set<String> {
    let sql = "PRAGMA table_info(memos);"
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }
    try prepare(sql, &stmt)
    var names = Set<String>()
    while sqlite3_step(stmt) == SQLITE_ROW {
      if let name = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }) {
        names.insert(name)
      }
    }
    return names
  }

  // MARK: - CRUD

  func upsertDraft(id: UUID, draft: String, title: String) throws {
    let now = Date.now.timeIntervalSince1970
    let sql = """
      INSERT INTO memos (id, draft, title, is_pinned, is_open, is_trashed, created_at, updated_at)
      VALUES (?, ?, ?, 0, 1, 0, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        draft      = excluded.draft,
        title      = excluded.title,
        updated_at = excluded.updated_at;
      """
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }

    try prepare(sql, &stmt)
    sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(stmt, 2, draft, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(stmt, 3, title, -1, SQLITE_TRANSIENT)
    sqlite3_bind_double(stmt, 4, now)
    sqlite3_bind_double(stmt, 5, now)
    try step(stmt)
  }

  // frame と isOpen のみ更新。is_pinned / title / is_trashed は既存の値を保持する。
  func updateWindowState(
    id: UUID,
    originX: Double?,
    originY: Double?,
    width: Double?,
    height: Double?,
    isOpen: Bool
  ) throws {
    let now = Date.now.timeIntervalSince1970
    let sql = """
      INSERT INTO memos (id, draft, title, origin_x, origin_y, width, height, is_pinned, is_open, is_trashed, created_at, updated_at)
      VALUES (?, '', '', ?, ?, ?, ?, 0, ?, 0, ?, ?)
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
    sqlite3_bind_double(stmt, 7, now)
    sqlite3_bind_double(stmt, 8, now)
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

  func trash(id: UUID) throws {
    let sql = "UPDATE memos SET is_trashed = 1, is_open = 0, updated_at = ? WHERE id = ?;"
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }
    try prepare(sql, &stmt)
    sqlite3_bind_double(stmt, 1, Date.now.timeIntervalSince1970)
    sqlite3_bind_text(stmt, 2, id.uuidString, -1, SQLITE_TRANSIENT)
    try step(stmt)
  }

  func restore(id: UUID) throws {
    let sql = "UPDATE memos SET is_trashed = 0, updated_at = ? WHERE id = ?;"
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }
    try prepare(sql, &stmt)
    sqlite3_bind_double(stmt, 1, Date.now.timeIntervalSince1970)
    sqlite3_bind_text(stmt, 2, id.uuidString, -1, SQLITE_TRANSIENT)
    try step(stmt)
  }

  func permanentDelete(id: UUID) throws {
    let sql = "DELETE FROM memos WHERE id = ?;"
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }
    try prepare(sql, &stmt)
    sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
    try step(stmt)
  }

  func emptyTrash() throws {
    try exec("DELETE FROM memos WHERE is_trashed = 1;")
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

  func fetch(id: UUID) throws -> PersistedMemo? {
    let sql = "SELECT \(Self.selectColumns) FROM memos WHERE id = ?;"
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }

    try prepare(sql, &stmt)
    sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
    guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
    return row(from: stmt)
  }

  func fetchOpen() throws -> [PersistedMemo] {
    let sql = "SELECT \(Self.selectColumns) FROM memos WHERE is_open = 1 AND is_trashed = 0 ORDER BY updated_at ASC;"
    return try fetchList(sql: sql)
  }

  func fetchAll() throws -> [PersistedMemo] {
    let sql = "SELECT \(Self.selectColumns) FROM memos WHERE is_trashed = 0 ORDER BY updated_at DESC;"
    return try fetchList(sql: sql)
  }

  func fetchTrashed() throws -> [PersistedMemo] {
    let sql = "SELECT \(Self.selectColumns) FROM memos WHERE is_trashed = 1 ORDER BY updated_at DESC;"
    return try fetchList(sql: sql)
  }

  // MARK: - Helpers

  private func fetchList(sql: String) throws -> [PersistedMemo] {
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

    let title    = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
    let originX  = sqlite3_column_type(stmt, 3) != SQLITE_NULL ? sqlite3_column_double(stmt, 3) : nil as Double?
    let originY  = sqlite3_column_type(stmt, 4) != SQLITE_NULL ? sqlite3_column_double(stmt, 4) : nil as Double?
    let width    = sqlite3_column_type(stmt, 5) != SQLITE_NULL ? sqlite3_column_double(stmt, 5) : nil as Double?
    let height   = sqlite3_column_type(stmt, 6) != SQLITE_NULL ? sqlite3_column_double(stmt, 6) : nil as Double?
    let createdAt = sqlite3_column_type(stmt, 10) != SQLITE_NULL
      ? Date(timeIntervalSince1970: sqlite3_column_double(stmt, 10))
      : nil as Date?

    return PersistedMemo(
      id: id,
      draft: rawDraft,
      title: title,
      originX: originX,
      originY: originY,
      width: width,
      height: height,
      isPinned: sqlite3_column_int(stmt, 7) != 0,
      isOpen: sqlite3_column_int(stmt, 8) != 0,
      isTrash: sqlite3_column_int(stmt, 9) != 0,
      createdAt: createdAt,
      updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 11))
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
