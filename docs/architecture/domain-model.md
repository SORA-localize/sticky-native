# Domain Model

最終更新: 2026-04-11

## Phase 1 Core

- `Memo`
  - 本文、タイトル、window frame、pin 状態、open 状態を持つ
  - 表示と保存の中心

## Deferred

- `Session`
  - 概念は維持するが Phase 1 実装には入れない
- `Trash`
  - 概念は維持するが Phase 1 実装には入れない
- `Settings`
  - 将来の自動 close や shortcut 設定の受け皿

## SQLite Fields For Phase 1

- `id`
- `content`
- `title`
- `window_x`
- `window_y`
- `window_width`
- `window_height`
- `is_pinned`
- `is_open`
- `created_at`
- `updated_at`
- `last_opened_at`
