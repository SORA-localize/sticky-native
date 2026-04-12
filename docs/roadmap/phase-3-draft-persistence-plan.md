# Phase 3 Draft Persistence Plan

最終更新: 2026-04-12

## SSOT 参照宣言

- `/Users/hori/Desktop/Sticky/migration/01_product_decision.md`
- `/Users/hori/Desktop/Sticky/migration/02_ux_principles.md`
- `/Users/hori/Desktop/Sticky/migration/04_technical_decision.md`
- `/Users/hori/Desktop/Sticky/migration/06_roadmap.md`
- `/Users/hori/Desktop/Sticky/migration/09_seamless_ux_spec.md`
- `docs/product/mvp-scope.md`
- `docs/architecture/persistence-boundary.md`
- `docs/architecture/technical-decision.md`
- `docs/roadmap/development-roadmap-revalidated.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`

## 今回触る関連ファイル

- `StickyNative.xcodeproj`
- `StickyNativeApp/MemoWindow.swift`
- `StickyNativeApp/MemoWindowController.swift`
- `StickyNativeApp/WindowManager.swift`
- `StickyNativeApp/AppDelegate.swift`
- `StickyNativeApp/MenuBarController.swift`
- `StickyNativeApp/SQLiteStore.swift`
- `StickyNativeApp/PersistenceModels.swift`
- `StickyNativeApp/PersistenceCoordinator.swift`
- `StickyNativeApp/AutosaveScheduler.swift`

補足:
- `SQLiteStore.swift`, `PersistenceModels.swift`, `PersistenceCoordinator.swift`, `AutosaveScheduler.swift` は新規作成候補
- `WindowManager.swift` は persistence に依存しすぎないよう、読み書きの窓口だけを持つ
- これ以上ファイルが増える場合は、実装前に本計画を更新する

## 問題一覧

- `P-01`: in-memory reopen のみで、app 再起動後に draft を失う
- `P-02`: window frame / pin / open state の永続境界が未定義
- `P-03`: autosave の契機が未定義で、入力と保存が分離していない
- `P-04`: relaunch 時にどの memo を reopen するかの復元ルールが未定義
- `A-01`: persistence を window lifecycle へ直接混ぜると責務が崩れる
- `K-01`: 旧 `Phase 1 SQLite` 前提の文書が残ると判断を誤る

## 目的

- close / relaunch をまたいでも、memo の draft と reopen 状態を失わない最小 persistence を成立させる

## スコープ In

- SQLite 導入
- memo draft 保存
- frame 保存
- pin 状態保存
- open / close 状態保存
- app 再起動後の reopen
- 最小 autosave

## スコープ Out

- Trash
- Session
- 検索 index
- title 自動生成
- 高度な差分保存
- クラウド同期

## 技術詳細確認

### ファイル責務

- `SQLiteStore.swift`
  - SQLite 接続、schema 作成、CRUD の最下層
  - SQL を直接持つ唯一の層
- `PersistenceModels.swift`
  - DB row と app model の橋渡しに使う最小 struct
- `PersistenceCoordinator.swift`
  - `WindowManager` から見た保存 / 読み出し窓口
  - app launch 時の初期ロードと relaunch reopen 判定
- `AutosaveScheduler.swift`
  - 入力頻度に対する保存の間引き
  - `TextEditor` の onChange と DB 書き込みを直結させない
- `WindowManager.swift`
  - open 中 window の管理を維持
  - persistence への保存要求だけを出す
- `MemoWindowController.swift`
  - close / frame / pin 状態の変化を `WindowManager` へ通知する
- `MemoWindow.swift`
  - draft と persistence 用識別子を持つ最小モデル

### データ境界

- Phase 3 で SQLite に保存するもの
  - `memo id`
  - `draft`
  - `window origin x/y`
  - `window size width/height`
  - `isPinned`
  - `isOpen`
  - `updatedAt`
- Phase 3 でまだ保存しないもの
  - Trash 状態
  - Session ID
  - title
  - 検索用トークン

### schema の最小案

- table: `memos`
  - `id TEXT PRIMARY KEY`
  - `draft TEXT NOT NULL`
  - `origin_x REAL`
  - `origin_y REAL`
  - `width REAL`
  - `height REAL`
  - `is_pinned INTEGER NOT NULL`
  - `is_open INTEGER NOT NULL`
  - `updated_at REAL NOT NULL`

### イベント経路

- app launch
  - `AppDelegate`
  - `PersistenceCoordinator.loadLaunchState()`
  - `WindowManager.restorePersistedOpenMemos()`
- draft change
  - `MemoEditorView`
  - `AutosaveScheduler`
  - `PersistenceCoordinator.saveDraft`
- pin change
  - `MemoWindowController.pinWindow(_:)`
  - `WindowManager`
  - `PersistenceCoordinator.saveWindowState`
- close
  - `MemoWindowController.windowWillClose`
  - `WindowManager`
  - `PersistenceCoordinator.markClosed`
- reopen after relaunch
  - `PersistenceCoordinator.fetchOpenMemos()`
  - `WindowManager`
  - `MemoWindowController`

### autosave ルール

- draft 保存は即時同期書き込みにしない
- 最小 debounce を入れる
- close 時は pending save を flush する
- app terminate 時も flush を試みる

### reopen ルール

- close 後 reopen
  - DB 保存済み state を基準に reopen する
- relaunch 後 reopen
  - `is_open = true` の memo を復元対象にする
- close した memo は `is_open = false` とする
- reopen 時は直前の frame と pin 状態を優先して復元する

## 修正フェーズ

### Phase 3-1: SQLite Bootstrap

目的:
- SQLite の最小接続と schema 作成を成立させる

Gate:
- app 起動時に DB 初期化が成功する
- memo table が自動作成される

### Phase 3-2: Draft Save Path

目的:
- draft を SQLite へ保存する経路を作る

Gate:
- draft 入力後に close / reopen しても内容が残る
- 保存経路が `AutosaveScheduler -> PersistenceCoordinator -> SQLiteStore` に一本化される

### Phase 3-3: Window State Persistence

目的:
- frame / pin / open state を保存する

Gate:
- close / reopen 後に frame と pin 状態が復元される

### Phase 3-4: Relaunch Restore

目的:
- app 再起動後に open memo を復元する

Gate:
- app 再起動後も open state に応じて memo が復元される

## Gate 条件

- draft が close / reopen をまたいで失われない
- app 再起動後も reopen が成立する
- frame / pin / open state が二重管理されない
- autosave が UI 操作感を壊さない
- SQLite 導入で seamless UX の操作感を壊していない

## 回帰 / 副作用チェック

- persistence ロジックを `View` に直接書かない
- SQL を `WindowManager` や `MemoWindowController` に漏らさない
- close 時保存と autosave の二重書き込み競合を避ける
- in-memory reopen と DB reopen の責務を混同しない
- 旧 `sticky.db` を読みにいかない

## 実機確認項目

1. memo に文字を入れて close し、menu bar から reopen したときに内容が残るか
2. memo を pin して位置とサイズを変え、close / reopen で状態が戻るか
3. app を終了して再起動したとき、open 状態だった memo が復元されるか
4. app を終了する直前に入力した文字が失われないか
5. autosave 導入後も pin / close / drag の操作感が重くなっていないか

## 変更履歴

- 2026-04-12: 初版作成
