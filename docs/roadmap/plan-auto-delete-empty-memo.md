# 空メモ自動削除 実装計画

作成: 2026-04-15

---

## SSOT 参照宣言

本計画は以下を上位文書として参照する。

### 移行元 SSOT（最優先）

- `/Users/hori/Desktop/Sticky/migration/README.md`
- `/Users/hori/Desktop/Sticky/migration/01_product_decision.md`
- `/Users/hori/Desktop/Sticky/migration/02_ux_principles.md`
- `/Users/hori/Desktop/Sticky/migration/04_technical_decision.md`
- `/Users/hori/Desktop/Sticky/migration/06_roadmap.md`
- `/Users/hori/Desktop/Sticky/migration/07_project_bootstrap.md`
- `/Users/hori/Desktop/Sticky/migration/08_human_checklist.md`
- `/Users/hori/Desktop/Sticky/migration/09_seamless_ux_spec.md`

### ローカル SSOT 補助

- `docs/product/ux-principles.md`
- `docs/product/mvp-scope.md`
- `docs/architecture/technical-decision.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`

設計判断の根拠: Apple Notes 準拠 UX として「空メモを開いたまま閉じたら自動削除」が自然。  
本計画はゴミ箱フロー（`is_trashed`）を経由せず永続削除（`DELETE FROM memos`）とする。

---

## 今回触る関連ファイル

| ファイル | 役割 |
|---|---|
| `SQLiteStore.swift:197` | `permanentDelete(id:)` が既存。追加不要 |
| `PersistenceCoordinator.swift` | `permanentDelete(id:)` の公開ラッパーを追加 |
| `WindowManager.swift:79,99,174` | 起動時復元・終了時フラッシュ・close ハンドラを修正 |
| `MemoWindowController.swift:108,142` | `windowWillClose` と `onSaveAndClose` 経路に空判定を追加 |

---

## 問題一覧

| ID | 分類 | 概要 |
|---|---|---|
| P-01 | Persistence | 空メモが DB に残り、Home 一覧・再起動復元の両方に混入する |
| P-02 | Persistence | `permanentDelete` が `SQLiteStore` に存在するが `PersistenceCoordinator` に未公開 |
| W-01 | Window | close 経路が X/Cmd+W/Cmd+Enter の 3 本あり、空判定を漏れなく通す必要がある |
| A-01 | Architecture | 空判定ロジックが分散すると将来の閾値変更時に取りこぼしが生じる |

---

## Open Questions → 仕様決定

### Q1: 対象は「新規メモのみ」か「既存メモを全消しした場合」も含むか

**決定**: 両方対象。本文が空なら削除。新規/既存を区別しない。

### Q2: Cmd+Enter（save-and-close）経路は一時 flush を許容するか

**決定**: 空なら flush しない。`onSaveAndClose` 内で空チェックを先行させ、空ならそのまま close のみ実行。

### Q3: session 付きメモが空になった場合

**決定**: `DELETE FROM memos WHERE id = ?` で行ごと削除。sessions テーブルは無変更。session 側に孤立行は生じない。

---

## 技術詳細確認

### 空判定の定義と置き場（DRY 方針）

判定式の定義元を **`MemoWindowController` の static メソッド 1 箇所** に固定する。

```swift
// MemoWindowController.swift
static func isDraftEmpty(_ draft: String) -> Bool {
    draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}
```

各経路はこのメソッドを呼ぶだけにする。

| 経路 | 呼び出し |
|---|---|
| `windowWillClose` | `Self.isDraftEmpty(memo.draft)` |
| `onSaveAndClose` クロージャ | `MemoWindowController.isDraftEmpty(memo.draft)` |
| `restorePersistedOpenMemos` | `MemoWindowController.isDraftEmpty(persisted.draft)` |
| `prepareForTermination` | `MemoWindowController.isDraftEmpty(controller.memo.draft)` |

これにより A-01 の「分散による取りこぼし」を防ぐ。判定閾値を変更する場合は 1 箇所だけ直せばよい。

### イベント経路と空メモの扱い

| ユーザー操作 | 経路 | 空判定場所 | 空の場合の挙動 |
|---|---|---|---|
| X ボタン | `onClose` → `window?.close()` → `windowWillClose` | `MemoWindowController.windowWillClose` | flush なし・`isAutoDelete=true` で close |
| Cmd+W | 同上 | 同上 | 同上 |
| Cmd+Enter | `onSaveAndClose` → flush → `window?.close()` → `windowWillClose` | `onSaveAndClose` クロージャ内で先行チェック | 空なら flush スキップ・close のみ |
| アプリ起動 | `restorePersistedOpenMemos` | `WindowManager` でループ内チェック | 復元せず `permanentDelete` |
| アプリ終了 | `prepareForTermination` | `WindowManager` でループ内チェック | flush せず `permanentDelete` |

### ClosedMemoRecord への追加

`isAutoDelete: Bool = false` フラグを追加する。  
`handleWindowClose` はこのフラグで分岐し、`isAutoDelete == true` の場合は `permanentDelete` を呼びつつ `closedMemoRecords` に積まない（Reopen 対象外）。

### 既存 `permanentDelete` の再利用

`SQLiteStore.permanentDelete(id:)` は `SQLiteStore.swift:197` に実装済み。  
`PersistenceCoordinator` に以下を追加するだけで既存コードを再利用できる。

```swift
func permanentDelete(id: UUID) {
    try? store.permanentDelete(id: id)
}
```

### 責務境界

| 責務 | 担当 |
|---|---|
| 空判定 | `MemoWindowController`（close 時） / `WindowManager`（起動・終了時） |
| 永続削除 | `PersistenceCoordinator.permanentDelete` |
| Reopen スタック管理 | `WindowManager.handleWindowClose`（`isAutoDelete` で除外） |
| Home 一覧への反映 | close 経路では `handleWindowClose` → `onClosedStackChanged?()` → `homeWindowController.viewModel.reload()` が即時に走る（`AppDelegate.swift:50`）。起動時クリーンは Home ウィンドウ表示前のため reload 不要。終了時はアプリ終了中のため UI 更新不要。 |

---

## 修正フェーズ

### Phase 1: PersistenceCoordinator に `permanentDelete` を公開

- `PersistenceCoordinator.swift` に 1 メソッド追加
- 変更ファイル: 1

### Phase 2: close 時の空メモ自動削除

- `ClosedMemoRecord` に `isAutoDelete` フラグを追加
- `MemoWindowController.windowWillClose` に空判定を追加
- `MemoWindowController.onSaveAndClose` クロージャに空判定を追加
- `WindowManager.handleWindowClose` に `isAutoDelete` 分岐を追加
- 変更ファイル: 2（MemoWindowController / WindowManager）

### Phase 3: 起動・終了時クリーン

- `WindowManager.restorePersistedOpenMemos` でループ前に空メモを削除
- `WindowManager.prepareForTermination` で空メモを flush せず削除
- 変更ファイル: 1（WindowManager）

---

## Gate 条件

- [ ] Phase 1 完了後: ビルド通過
- [ ] Phase 2 完了後: close 系レビューゲートをすべて通過
- [ ] Phase 3 完了後: 起動・終了系レビューゲートをすべて通過

---

## 実機確認項目

### close 系

- [ ] 空メモを新規作成して X で閉じる → ウィンドウが消え、Reopen に出ない
- [ ] 空メモを新規作成して Cmd+W → 同上
- [ ] 空メモを新規作成して Cmd+Enter → 同上
- [ ] 文字を全部消してから X で閉じる（既存メモを空に） → 同上
- [ ] 文字を入力して X で閉じる（通常クローズ） → Reopen に積まれる

### 起動・終了系

- [ ] 空メモが開いている状態でアプリを Force Quit → 再起動後に空メモが出ない
- [ ] 空メモが開いている状態でアプリを Quit → 再起動後に空メモが出ない

### Home・一覧

- [ ] 空メモ削除後に Home を開く → 一覧に空メモが表示されない
- [ ] session 付きメモを空にして閉じる → session 一覧から消える、session 自体は残る

### 非対象（回帰確認）

- [ ] 通常メモを閉じる → 従来どおり Reopen に積まれ、再起動後も復元される
- [ ] ゴミ箱フロー（trash ボタン / Cmd+Delete）は変わらず動作する

---

## 回帰・副作用チェック

| チェック項目 | 懸念 | 対策 |
|---|---|---|
| `closedMemoRecords` | `isAutoDelete` メモが Reopen に混入しないか | `handleWindowClose` で `isAutoDelete` 時は append しない |
| `AutosaveScheduler` | 空メモがスケジュール済みの場合、終了時に flush されるか | `prepareForTermination` で空判定を先行させ、flush をスキップ |
| Home 一覧 | 空メモ削除後に stale データが残るか | close 経路では `handleWindowClose` → `onClosedStackChanged?()` → `viewModel.reload()` が即時に走るため、削除と同時に Home 一覧から消える（`AppDelegate.swift:47`） |
| session 整合 | `permanentDelete` で session との外部キー整合は崩れないか | `session_id` は `REFERENCES sessions(id)` の参照のみで CASCADE 設定なし。memo 行が消えるだけで sessions テーブルは無変更 |
| `isAutoDelete` フラグのデフォルト | 既存の close パスがすべて `isAutoDelete=false` になるか | デフォルト値 `false` で後方互換を維持 |

---

## 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-04-15 | 初版作成（planning guide 未準拠の仕様メモを全面改訂） |
| 2026-04-15 | SSOT に migration 側必須文書を追加、空判定 DRY 方針を static メソッドに一本化、Home reload 経路を経路別に明記 |
