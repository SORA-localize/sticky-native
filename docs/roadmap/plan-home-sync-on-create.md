# Home Sync on Memo Create Plan

作成: 2026-04-26  
ステータス: 計画中

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-26 | `plan-paste-sync-language.md` の A-202 を分離。根本原因（新規メモが SQLite に未存在）を特定し再計画 |

---

## SSOT参照宣言

本計画は以下を上位文書として扱う。

- `docs/roadmap/stickynative-ai-planning-guidelines.md`
- `docs/product/ux-principles.md`
- `docs/architecture/technical-decision.md`
- `docs/roadmap/phase-4-management-surface-plan.md`

`/Users/hori/Desktop/Sticky/migration/*` は作業環境に存在しない。本計画では repo 内 docs と現行実装を暫定 SSOT とする。これは整合「済み」ではなく「SSOT 未確認 / 保留」であり、migration 文書が復旧した場合は再照合が必要。

### SSOT整合メモ

- `ux-principles.md`: 「可逆: close しても失わない」「軽い: 整理や mode 切替を先に要求しない」。新規作成と同時に Home に表示されることは「軽い」に対応し、管理画面の遅延更新を排除する。
- `technical-decision.md`: SQLite が persistence の唯一の SSOT。メモの存在はこの文書に記録された時点から有効とする。

---

## 背景

### 根本原因の分析

`HomeViewModel.reload()` は `coordinator.fetchAllMemos()` → `SQLiteStore.fetchAll()` を呼び、SQLite の `memos` テーブルを読む。

`createNewMemoWindow()` は `MemoWindow` を `openControllers` に乗せてウィンドウを表示するが、**SQLite への書き込みを行わない**。新規メモの初回 persistence は以下のどちらかまで遅延する:

1. ユーザーが入力 → autosave 発火 → `AutosaveScheduler` → `persistContent` → `coordinator.saveMemoContent` → `store.upsertContent`
2. ウィンドウを閉じる → `handleWindowClose` → `coordinator.saveWindowState`（non-autoDelete 時のみ、かつ frame のみ更新）

したがって、`createNewMemoWindow()` に `onClosedStackChanged?()` を追加するだけでは Home は更新されない（`reload()` が呼ばれても SQLite に行がないため空振りする）。

### 新規メモの SSOT 定義

本計画では「メモは `createNewMemoWindow()` 呼び出し時点から SQLite に存在する」とする。これにより:

- Home が即時更新される
- autosave と close 時の `upsertContent` / `saveWindowState` は ON CONFLICT で既存行を更新する（新規行の二重作成にならない）
- ユーザーが入力なしで閉じた場合: 既存の `isAutoDelete` パス（`isDraftEmpty` → `permanentDelete`）がそのまま機能し、空行は削除される → `onClosedStackChanged?()` → Home からも消える

---

## 今回触る関連ファイル

| ファイル | 扱い |
|----------|------|
| `StickyNativeApp/WindowManager.swift` | `createNewMemoWindow()` に初回 persist と `onClosedStackChanged?()` を追加 |
| `StickyNativeApp/PersistenceCoordinator.swift` | 参照のみ（`saveMemoContent` を再利用） |
| `StickyNativeApp/SQLiteStore.swift` | 参照のみ（`upsertContent` の ON CONFLICT 動作を確認済み） |

---

## 問題一覧

| ID | 種別 | 問題 | 影響 | 対応 Phase |
|----|------|------|------|------------|
| A-202 | Architecture | 新規メモ作成時に管理画面が自動同期されない | 管理画面を開いたまま新規メモを作ると一覧が古いまま | Phase 1 |

---

## 修正フェーズ

### Phase 1: Persist on Create（A-202）

**目的:** 新規メモ作成時に SQLite 行を即時作成し、管理画面を自動更新する。

**対象ファイル:** `WindowManager.swift`

**実装方針:**

`createNewMemoWindow()` の末尾に以下を追加する:

```swift
coordinator.saveMemoContent(
  id: memo.id,
  content: EditorContent(plainText: ""),
  colorIndex: memo.colorTheme.colorIndex
)
onClosedStackChanged?()
```

`saveMemoContent` → `store.upsertContent` は以下の SQL を実行する:

```sql
INSERT INTO memos (id, draft, title, color_index, rich_text_data, is_pinned, is_open, is_trashed, created_at, updated_at, content_edited_at)
VALUES (?, '', '', <colorIndex>, NULL, 0, 1, 0, <now>, <now>, <now>)
ON CONFLICT(id) DO UPDATE SET ...
```

初回呼び出しでは行が存在しないため INSERT が走り、正しい `color_index` と `is_open = 1` で行が作られる。以後の autosave や close 時は ON CONFLICT UPDATE が走り、既存行を更新する。

**空メモのクリーンアップ:**

ユーザーが入力なしで閉じると、既存の `isAutoDelete` パスが動作する:

1. `MemoWindowController` が `isDraftEmpty(memo.draft)` を判定
2. `onClose(ClosedMemoRecord(memoID:, frame: nil, isAutoDelete: true))` を呼ぶ
3. `handleWindowClose` → `coordinator.permanentDelete(id:)` → 行削除
4. `onClosedStackChanged?()` → `HomeViewModel.reload()` → Home から消える

この経路は既存コードで完結しており、追加実装は不要。

**作業:**

1. `WindowManager.createNewMemoWindow()` の `controller.showAndFocusEditor()` と `lastCascadeOrigin` 更新の後に、上記 2 行を追加する

**Gate:**

- 管理画面を開いたまま Cmd+Option+Enter で新規メモを作成すると、管理画面の一覧に即時（空タイトルで）追加される
- 新規メモに入力して保存すると、管理画面のタイトルが更新される（autosave → reload の既存動作）
- 新規メモを入力なしで閉じると、管理画面から消える
- メモを閉じる / ゴミ箱 / reopen の既存同期動作が壊れない
- `openMemo` / `reopenLastClosedMemo` の `markOpen` 経路は変更しない
- build が通る

---

## Gate条件まとめ

- G-01: 新規メモ作成時に管理画面が即時更新される
- G-02: 空メモを閉じると管理画面から消える
- G-03: close / trash / reopen の既存同期動作が壊れない
- G-04: build が通る

---

## 回帰 / 副作用チェック

### Management Screen

- 新規メモ作成 → 管理画面に即時追加される
- 新規メモに入力後、autosave で管理画面タイトルが更新される（既存動作）
- 新規メモを入力なしで閉じると管理画面から消える
- メモを閉じる → 管理画面に反映（既存動作）
- ゴミ箱に入れる → 管理画面に反映（既存動作）
- reopen → 管理画面に反映（既存動作）
- 管理画面が閉じている状態での新規作成（`onClosedStackChanged` の `canReopen` 更新が正しく動く）

### Persistence

- autosave が発火したとき ON CONFLICT UPDATE で正しく上書きされる
- close 時の `saveWindowState` が ON CONFLICT UPDATE で frame を更新する（is_open = false）
- `permanentDelete` が正しく行を削除する（空メモクローズ時）

### Window Lifecycle

- 複数メモを連続作成して管理画面に全て表示されること
- 新規作成→即クローズ（空）→管理画面に残らないこと
- app relaunch 後に空で作成したメモが再表示されないこと（close 時に削除される）

---

## 実機確認項目

1. 管理画面を開いたまま Cmd+Option+Enter で新規メモを作成し、一覧に即時追加されることを確認する
2. 新規メモにテキストを入力し、管理画面のタイトルが更新されることを確認する（autosave 後）
3. 新規メモを入力なしで閉じ、管理画面から消えることを確認する
4. 既存のメモを閉じる / ゴミ箱 / reopen が正常に動作することを確認する
5. 複数メモを連続作成して全て管理画面に表示されることを確認する
6. app を再起動し、入力ありメモのみが復元されることを確認する

---

## 技術詳細確認

### 責務配置

`WindowManager.swift`:

- `createNewMemoWindow()` に `coordinator.saveMemoContent` と `onClosedStackChanged?()` を追加する
- それ以外の責務は変更しない

`PersistenceCoordinator.swift`:

- 変更なし。`saveMemoContent` を既存 API として呼び出す

### メモリで持つ情報

- 変更なし。`openControllers` に載せる既存の in-memory 管理はそのまま維持する
- SQLite が新たにメモの「存在の SSOT」になる（作成時点から）

### イベント経路

**新規作成 → Home 同期:**

1. ユーザーが Cmd+Option+Enter
2. `WindowManager.createNewMemoWindow()`
3. `MemoWindow` と `MemoWindowController` を作成
4. `openControllers[memo.id] = controller`
5. `controller.showAndFocusEditor()`
6. `coordinator.saveMemoContent(id: memo.id, content: EditorContent(plainText: ""), colorIndex: memo.colorTheme.colorIndex)` ← 追加
7. `onClosedStackChanged?()` ← 追加
8. `AppDelegate` closure → `homeWindowController.viewModel.reload()` → `fetchAllMemos()` → 新行が一覧に現れる

**空メモクローズ → Home から削除:**

1. ユーザーが Cmd+W（入力なし）
2. `MemoWindowController.isDraftEmpty` → `onClose(ClosedMemoRecord(isAutoDelete: true))`
3. `handleWindowClose` → `coordinator.permanentDelete(id:)` → SQLite から削除
4. `onClosedStackChanged?()` → `reload()` → 一覧から消える（既存動作）

### AppKit / SwiftUI 責務境界

- `saveMemoContent` と `onClosedStackChanged?()` の追加は AppKit 層（`WindowManager`）に閉じている
- SwiftUI の `HomeView` は既存の `@ObservedObject viewModel` で自動更新される。変更なし

### close / reopen / pin / drag の状態遷移

- close: 変更なし。`handleWindowClose` が `saveWindowState` (isOpen: false) + `onClosedStackChanged?()` を呼ぶ
- reopen: 変更なし。`openMemo` / `reopenLastClosedMemo` が `markOpen` を呼んで既存行を更新する
- pin / drag: 変更なし

### Persistence との衝突

- `upsertContent` は ON CONFLICT DO UPDATE のため、作成後の autosave や close 時の上書きと衝突しない
- `saveWindowState` は frame と is_open のみ更新し、draft / title / color_index は変更しない（既存動作）
- `markOpen` は `is_open = 1` に更新するだけなので、作成時の初期値と衝突しない

---

## MECE 検査

### Issue → Phase 対応

- A-202: Phase 1

### SSOT整合

- `ux-principles.md`: 「軽い」「可逆」→ 即時 Home 反映と空メモ自動削除が両立する設計になっている
- `technical-decision.md`: SQLite が唯一の persistence SSOT → 作成時点から行を持つことで一貫する

### DRY / KISS

- 新コールバックを追加しない。既存の `onClosedStackChanged` を再利用する
- 既存の `isAutoDelete` / `permanentDelete` パスを再利用し、空メモクリーンアップの新規実装をしない
- 変更は `createNewMemoWindow()` への 2 行追加のみ

---

## セルフチェック結果

### SSOT整合

[BLOCKER: missing] migration README — 復旧時に再照合が必要  
[BLOCKER: missing] 01_product_decision — 同上  
[BLOCKER: missing] 02_ux_principles — 同上  
[BLOCKER: missing] 06_roadmap — 同上  
[BLOCKER: missing] 07_project_bootstrap — 同上  
[BLOCKER: missing] 09_seamless_ux_spec — 同上  
[x] repo-local docs を確認した  
[x] SQLiteStore の upsertContent ON CONFLICT 動作を確認した  
[x] MemoWindowController の isAutoDelete パスを確認した  

### 変更範囲

[x] 主目的は1つ（新規作成時の Home 同期のみ）  
[n/a: 高リスク疎通確認テーマなし]  
[x] ついで作業を入れていない  

### 技術詳細

[x] 根本原因（SQLite に行が存在しない）が特定されている  
[x] 修正の実装が 2 行追加に特定されている  
[x] ON CONFLICT の動作を確認し、autosave / close との衝突がないことを確認した  
[x] 空メモクリーンアップは既存パスで動作することを確認した  
[x] イベント経路が明記されている  

### Window / Focus

[n/a: window / focus 責務を変更しない]  

### Persistence

[x] upsertContent は ON CONFLICT UPDATE で既存行を正しく更新する  
[x] saveWindowState と upsertContent は更新対象列が異なり衝突しない  
[x] permanentDelete は既存パスで動作する  
[x] スキーマ変更なし  

### 実機確認

[x] 実機確認項目が列挙されている  
[n/a: global shortcut の動作変更なし]  
[n/a: first mouse の動作変更なし]  
[n/a: ゼロクリック入力の動作変更なし]  
