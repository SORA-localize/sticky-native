# MVP Scope

最終更新: 2026-04-12

## Phase 1 In

- `SeamlessWindow`
- `SeamlessHostingView`
- `acceptsFirstMouse`
- `canBecomeKey` / `canBecomeMain`
- `@FocusState`
- 1 click 操作の疎通確認
- ゼロクリック入力の疎通確認
- material / vibrancy の疎通確認

## Phase 1 Out

- menu bar app の土台
- global shortcut
- 新規 memo window
- 入力 UI
- drag
- resize
- pin / unpin
- close
- close 後の local reopen
- app 再起動をまたぐ local draft 保持
- Home / Trash / Settings
- session 管理 UI
- 旧 `sticky.db` / Trash の自動移行
- クラウド同期
- 複数 memo の一括操作

## Phase 2 In

- menu bar app の土台
- global shortcut
- 新規 memo window
- 入力 UI
- drag
- resize
- pin / unpin
- close
- menu bar からの reopen

## Phase 3 In

- SQLite
- close 後の local reopen
- app 再起動後の local reopen
- app 再起動をまたぐ local draft 保持
- frame / open state 保存
