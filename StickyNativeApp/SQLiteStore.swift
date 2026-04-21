import Foundation
import SQLite3

final class SQLiteStore {
  private var db: OpaquePointer?

  // SELECT で使う標準列順（isSessionReady == true 時は末尾に 15:session_id が追加される）
  // 0:id 1:draft 2:title 3:origin_x 4:origin_y 5:width 6:height 7:color_index
  // 8:is_pinned 9:is_list_pinned 10:is_open 11:is_trashed 12:created_at 13:updated_at
  // 14:content_edited_at [15:session_id]
  private var selectColumns: String {
    let base = """
      id, draft, title, origin_x, origin_y, width, height, color_index,
      is_pinned, is_list_pinned, is_open, is_trashed, created_at, updated_at,
      content_edited_at
      """
    return isSessionReady ? base + ", session_id" : base
  }

  /// session_id 列の migration が成功した場合のみ true。
  /// false のままでも起動は継続する（degraded 起動）。
  private(set) var isSessionReady: Bool = false

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
    let memoSQL = """
      CREATE TABLE IF NOT EXISTS memos (
        id         TEXT PRIMARY KEY,
        draft      TEXT NOT NULL,
        title      TEXT NOT NULL DEFAULT '',
        origin_x   REAL,
        origin_y   REAL,
        width      REAL,
        height     REAL,
        color_index INTEGER NOT NULL DEFAULT 0,
        is_pinned  INTEGER NOT NULL DEFAULT 0,
        is_list_pinned INTEGER NOT NULL DEFAULT 0,
        is_open    INTEGER NOT NULL DEFAULT 1,
        is_trashed INTEGER NOT NULL DEFAULT 0,
        created_at REAL,
        updated_at REAL NOT NULL,
        content_edited_at REAL NOT NULL DEFAULT 0
      );
      """
    let sessionSQL = """
      CREATE TABLE IF NOT EXISTS sessions (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL DEFAULT '',
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL
      );
      """
    try exec(memoSQL)
    try exec(sessionSQL)
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
    if !existing.contains("color_index") {
      try exec("ALTER TABLE memos ADD COLUMN color_index INTEGER NOT NULL DEFAULT 0;")
    }
    if !existing.contains("is_list_pinned") {
      try exec("ALTER TABLE memos ADD COLUMN is_list_pinned INTEGER NOT NULL DEFAULT 0;")
    }

    if !existing.contains("content_edited_at") {
      try exec("ALTER TABLE memos ADD COLUMN content_edited_at REAL NOT NULL DEFAULT 0;")
      try exec("UPDATE memos SET content_edited_at = updated_at WHERE content_edited_at = 0;")
    }

    // session_id migration: 失敗しても起動継続（degraded 起動）
    do {
      if !existing.contains("session_id") {
        try exec("ALTER TABLE memos ADD COLUMN session_id TEXT REFERENCES sessions(id);")
      }
      isSessionReady = true
    } catch {
      // isSessionReady は false のまま。UI 側は disabled で表示する。
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

  // MARK: - Memo CRUD

  func upsertDraft(id: UUID, draft: String, title: String, colorIndex: Int) throws {
    let now = Date.now.timeIntervalSince1970
    let sql = """
      INSERT INTO memos (id, draft, title, color_index, is_pinned, is_open, is_trashed, created_at, updated_at, content_edited_at)
      VALUES (?, ?, ?, ?, 0, 1, 0, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        draft             = excluded.draft,
        title             = excluded.title,
        color_index       = excluded.color_index,
        updated_at        = excluded.updated_at,
        content_edited_at = excluded.content_edited_at;
      """
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }

    try prepare(sql, &stmt)
    sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(stmt, 2, draft, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(stmt, 3, title, -1, SQLITE_TRANSIENT)
    sqlite3_bind_int(stmt, 4, Int32(colorIndex))
    sqlite3_bind_double(stmt, 5, now)
    sqlite3_bind_double(stmt, 6, now)
    sqlite3_bind_double(stmt, 7, now)
    try step(stmt)
  }

  // frame と isOpen のみ更新。is_pinned / title / is_trashed / session_id は既存の値を保持する。
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
      INSERT INTO memos (id, draft, title, origin_x, origin_y, width, height, color_index, is_pinned, is_open, is_trashed, created_at, updated_at)
      VALUES (?, '', '', ?, ?, ?, ?, 0, 0, ?, 0, ?, ?)
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

  func updateListPinned(id: UUID, isPinned: Bool) throws {
    let sql = "UPDATE memos SET is_list_pinned = ? WHERE id = ?;"
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }

    try prepare(sql, &stmt)
    sqlite3_bind_int(stmt, 1, isPinned ? 1 : 0)
    sqlite3_bind_text(stmt, 2, id.uuidString, -1, SQLITE_TRANSIENT)
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

  func updateMemoSession(id: UUID, sessionID: UUID?) throws {
    let sql = "UPDATE memos SET session_id = ?, updated_at = ? WHERE id = ?;"
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }
    try prepare(sql, &stmt)
    if let sessionID {
      sqlite3_bind_text(stmt, 1, sessionID.uuidString, -1, SQLITE_TRANSIENT)
    } else {
      sqlite3_bind_null(stmt, 1)
    }
    sqlite3_bind_double(stmt, 2, Date.now.timeIntervalSince1970)
    sqlite3_bind_text(stmt, 3, id.uuidString, -1, SQLITE_TRANSIENT)
    try step(stmt)
  }

  func fetch(id: UUID) throws -> PersistedMemo? {
    let sql = "SELECT \(selectColumns) FROM memos WHERE id = ?;"
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }

    try prepare(sql, &stmt)
    sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
    guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
    return memoRow(from: stmt)
  }

  func fetchOpen() throws -> [PersistedMemo] {
    let sql = "SELECT \(selectColumns) FROM memos WHERE is_open = 1 AND is_trashed = 0 ORDER BY updated_at ASC;"
    return try fetchMemoList(sql: sql)
  }

  func fetchAll() throws -> [PersistedMemo] {
    let sql = "SELECT \(selectColumns) FROM memos WHERE is_trashed = 0 ORDER BY updated_at DESC;"
    return try fetchMemoList(sql: sql)
  }

  func fetchTrashed() throws -> [PersistedMemo] {
    let sql = "SELECT \(selectColumns) FROM memos WHERE is_trashed = 1 ORDER BY updated_at DESC;"
    return try fetchMemoList(sql: sql)
  }

  // MARK: - Session CRUD

  func insertSession(id: UUID, name: String) throws {
    let now = Date.now.timeIntervalSince1970
    let sql = """
      INSERT INTO sessions (id, name, created_at, updated_at)
      VALUES (?, ?, ?, ?);
      """
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }
    try prepare(sql, &stmt)
    sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(stmt, 2, name, -1, SQLITE_TRANSIENT)
    sqlite3_bind_double(stmt, 3, now)
    sqlite3_bind_double(stmt, 4, now)
    try step(stmt)
  }

  func updateSession(id: UUID, name: String) throws {
    let sql = "UPDATE sessions SET name = ?, updated_at = ? WHERE id = ?;"
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }
    try prepare(sql, &stmt)
    sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
    sqlite3_bind_double(stmt, 2, Date.now.timeIntervalSince1970)
    sqlite3_bind_text(stmt, 3, id.uuidString, -1, SQLITE_TRANSIENT)
    try step(stmt)
  }

  func deleteSession(id: UUID) throws {
    // 2 ステップをトランザクションで実行: memo を Unsorted に戻す → session 行削除
    try exec("BEGIN;")
    do {
      try clearSessionFromMemos(sessionID: id)
      try deleteSessionRow(id: id)
      try exec("COMMIT;")
    } catch {
      try? exec("ROLLBACK;")
      throw error
    }
  }

  func fetchAllSessions() throws -> [Session] {
    let sql = "SELECT id, name, created_at, updated_at FROM sessions ORDER BY created_at ASC;"
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }
    try prepare(sql, &stmt)
    var results: [Session] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
      if let session = sessionRow(from: stmt) {
        results.append(session)
      }
    }
    return results
  }

  private func clearSessionFromMemos(sessionID: UUID) throws {
    let sql = "UPDATE memos SET session_id = NULL WHERE session_id = ?;"
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }
    try prepare(sql, &stmt)
    sqlite3_bind_text(stmt, 1, sessionID.uuidString, -1, SQLITE_TRANSIENT)
    try step(stmt)
  }

  private func deleteSessionRow(id: UUID) throws {
    let sql = "DELETE FROM sessions WHERE id = ?;"
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }
    try prepare(sql, &stmt)
    sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
    try step(stmt)
  }

  // MARK: - Helpers

  private func fetchMemoList(sql: String) throws -> [PersistedMemo] {
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }

    try prepare(sql, &stmt)
    var results: [PersistedMemo] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
      if let memo = memoRow(from: stmt) {
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

  private func memoRow(from stmt: OpaquePointer?) -> PersistedMemo? {
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
    let colorIndex = Int(sqlite3_column_int(stmt, 7))
    let createdAt = sqlite3_column_type(stmt, 12) != SQLITE_NULL
      ? Date(timeIntervalSince1970: sqlite3_column_double(stmt, 12))
      : nil as Date?
    let contentEditedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 14))
    let sessionID: UUID? = isSessionReady
      ? sqlite3_column_text(stmt, 15).flatMap { UUID(uuidString: String(cString: $0)) }
      : nil

    return PersistedMemo(
      id: id,
      draft: rawDraft,
      title: title,
      originX: originX,
      originY: originY,
      width: width,
      height: height,
      colorIndex: MemoColorTheme.from(index: colorIndex).colorIndex,
      isPinned: sqlite3_column_int(stmt, 8) != 0,
      isListPinned: sqlite3_column_int(stmt, 9) != 0,
      isOpen: sqlite3_column_int(stmt, 10) != 0,
      isTrash: sqlite3_column_int(stmt, 11) != 0,
      createdAt: createdAt,
      updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 13)),
      contentEditedAt: contentEditedAt,
      sessionID: sessionID
    )
  }

  private func sessionRow(from stmt: OpaquePointer?) -> Session? {
    guard
      let rawID = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
      let id = UUID(uuidString: rawID),
      let name = sqlite3_column_text(stmt, 1).map({ String(cString: $0) })
    else { return nil }
    let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
    let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
    return Session(id: id, name: name, createdAt: createdAt, updatedAt: updatedAt)
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
