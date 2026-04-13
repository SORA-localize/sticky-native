# Domain Model

最終更新: 2026-04-12（Phase 5-1 で現状に同期）

## Core

- `Memo`
  - 本文、タイトル、window frame、pin 状態、open 状態、session 所属を持つ
  - 表示と保存の中心

- `Session`
  - 論理グループ（データ単位、表示単位ではない）
  - memo を任意のコンテキストでまとめる手段
  - Phase 5 で実装

## Deferred

- `Settings`
  - 将来の自動 close や shortcut 設定の受け皿（Phase 6 以降）

## SQLite スキーマ（Phase 5-1 時点）

### memos テーブル

- `id` TEXT PRIMARY KEY
- `draft` TEXT NOT NULL
- `title` TEXT NOT NULL DEFAULT ''
- `origin_x` REAL
- `origin_y` REAL
- `width` REAL
- `height` REAL
- `is_pinned` INTEGER NOT NULL DEFAULT 0
- `is_open` INTEGER NOT NULL DEFAULT 1
- `is_trashed` INTEGER NOT NULL DEFAULT 0
- `created_at` REAL
- `updated_at` REAL NOT NULL
- `session_id` TEXT REFERENCES sessions(id)（nullable、Phase 5-1 で追加）

### sessions テーブル（Phase 5-1 で追加）

- `id` TEXT PRIMARY KEY
- `name` TEXT NOT NULL DEFAULT ''
- `created_at` REAL NOT NULL
- `updated_at` REAL NOT NULL

## レイヤ責務

- App layer: app lifecycle、menu bar、global shortcut
- Window layer: memo window の生成・focus・pin・close
- Persistence layer: SQLite、autosave、cleanup
- Management layer: Home / Trash / Session 管理 UI
