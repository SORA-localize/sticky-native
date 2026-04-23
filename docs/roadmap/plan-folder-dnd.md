# 計画：Session→Folder改名・サイドバー再構成・D&D・メモ数表示

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-21 | 初版作成 |
| 2026-04-21 | レビュー指摘を反映：P-03矛盾修正・ID体系修正・Phase1例外理由追記・reload()確認・Issue→Phase対応表追加 |
| 2026-04-21 | レビュー指摘2回目を反映：MemoTransferItem定義ファイル明記・ゴミ箱D&D無効化方法追記・All Memos行ドロップ禁止理由追記 |
| 2026-04-23 | 後続計画 `plan-folder-management-polish.md` により All Memos 行へのD&D禁止判断を限定的に上書き。個別フォルダから未分類へ戻す明示操作として `onAssignFolder(memoID, nil)` を許可する方針を追記 |

---

## SSOT 参照宣言

| 文書 | 参照箇所 | 判断への影響 |
|------|----------|-------------|
| `docs/architecture/domain-model.md` | Session モデル・SQLite スキーマ | DB 列名は変更しない方針の根拠。Swift レイヤのみリネーム |
| `docs/product/ux-principles.md` | 「明快」「自然」「軽い」 | サイドバーをフォルダ中心に簡略化する方向と整合 |
| `docs/architecture/technical-decision.md` | SwiftUI / SQLite 採用 | D&D は SwiftUI 標準 API（`.draggable` / `.dropDestination`）で実現可能と判断 |
| `docs/architecture/persistence-boundary.md` | 保存責務 | Session CRUD は Phase 5-1 実装済み。今回は名称変更と UI 変更のみ |

migration 文書（`/Users/hori/Desktop/Sticky/migration/`）：02・09 ともに本変更（リネームと UI 再構成）に関係する仕様の記載なし。影響なし。

---

## 問題一覧

| ID | 種別 | 内容 |
|----|------|------|
| K-01 | 仕様整合 | "Session" という名称がユーザーモデルと乖離している。Apple Notes 相当の「Folder」が適切 |
| U-01 | UI | メモ行にフォルダ名を表示しているが、新構成では文脈が常に明確なため不要かつ視覚的なノイズ |
| U-02 | UI | Pinned / Today / Last 7 Days がサイドバーを占有しているが、フォルダ中心ナビに不要（後述） |
| U-03 | インタラクション | フォルダへの移動がコンテキストメニュー経由のみで、D&D で直感的に操作できない |
| U-04 | UI | 各サイドバー項目にメモ数が表示されておらず、中身の把握に項目選択が必要 |

### U-02 の根拠（P-03 矛盾の解消）

Pinned / Today / Last 7 Days を削除する理由は「All Memos で視認できる」ではない。**ナビゲーションのパラダイムがフォルダ中心に移行するため、時間軸・属性ベースのスマートフォルダが主要ナビ項目として不要になる**、が正しい根拠。

- All Memos（新）= 未分類メモのみ。フォルダ割り当て済みメモは含まれない
- 各フォルダ・All Memos 内ではメモが `content_edited_at` 降順で表示されるため、最近のメモは自然に上位に来る
- Apple Notes も標準サイドバーに「Today」「Last 7 Days」相当の項目を持たない
- 全メモを横断して見る手段は意図的に持たない（フォルダが整理の単位であるため）

---

## Issue → Phase 対応表

| Issue | 内容（要約） | 解決 Phase |
|-------|------------|------------|
| K-01 | Session → Folder リネーム | Phase 1 |
| U-01 | メモ行のフォルダ名表示を削除 | Phase 2 |
| U-02 | Pinned / Today / Last 7 Days をサイドバーから削除 | Phase 2 |
| U-03 | Drag & Drop 実装 | Phase 3 |
| U-04 | メモ数バッジ表示 | Phase 2 |

---

## 実装方針

### DB 変更なし

`sessions` テーブル・`session_id` 列は名前変更しない（migration リスク回避）。
Swift モデル・メソッド名・UI テキストのみ `Session` → `Folder` にリネームする。

### サイドバー新構成

```
All Memos  [N]   ← sessionID == nil のメモのみ（旧 Unsorted 相当）
Folder 1   [N]
Folder 2   [N]
  ...
──────────────
Trash      [N]
```

削除するスコープ：`.pinned` / `.today` / `.last7Days` / `.unsorted`

### All Memos の意味変更

| | 旧 | 新 |
|---|---|---|
| `.all` | 全非ゴミ箱メモ | sessionID == nil のメモ（未分類） |
| `.unsorted` | sessionID == nil | 廃止（`.all` と統合） |

### メモ行からフォルダ名表示を削除

どのビューでも「今どのコンテキストを見ているか」はサイドバーで明示されるため不要。

### Drag & Drop

- **ドラッグ元**：`MemoRowView` に `.draggable(MemoTransferItem(id: memo.id))` を付与
- **ドロップ先**：サイドバーの各フォルダ行に `.dropDestination(for: MemoTransferItem.self)` を付与
- ドロップ時に `onAssignFolder(memoID, folderID)` を呼ぶ
- Trash 行へのドロップは**受け付けない**（ゴミ箱移動はコンテキストメニューで行う。D&D と混在すると誤操作が生じやすい）
- All Memos 行へのドロップは本計画時点では**受け付けない**（フォルダ解除は D&D ではなくコンテキストメニューの「Remove from Folder」で行う。どのフォルダビューからでもドロップ先として All Memos が表示されると誤操作が生じやすく、意図が曖昧になるため）
- ただし、後続計画 `docs/roadmap/plan-folder-management-polish.md` では、個別フォルダから未分類へ戻す明示操作として All Memos 行への drop を限定的に許可する。実装時は Trash 行へのD&Dを引き続き無効化し、All Memos drop は `onAssignFolder(memoID, nil)` のみに限定する。

```swift
// 転送型：MemoTransferItem.swift として HomeView.swift と同じファイルグループに新規作成する
struct MemoTransferItem: Transferable {
    let id: UUID
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .memoItem)
    }
}
extension UTType {
    static let memoItem = UTType(exportedAs: "com.stickynative.memo-item")
}
```

ドロップ対象フォルダは `isTargeted` でハイライト表示（背景色変化）する。

### フォルダ管理 UI

既存の `SessionManagerView` を `FolderManagerView` にリネーム。
サイドバー下部の「Sessions」ボタン → 「+ New Folder」ボタンに変更（フォルダ作成に直接遷移）。
フォルダ行の長押し/右クリックコンテキストメニューで Rename / Delete を提供。

---

## 技術リスク評価

### D&D クロスコンテナ（低）

`List`（メモ一覧）と `ScrollView`（サイドバー）は別コンテナだが、SwiftUI の `Transferable` ベース D&D はコンテナをまたいで動作する。macOS 13+ の標準挙動。

### UTType 登録（中）

カスタム `UTType` は `Info.plist` の `UTExportedTypeDeclarations` に登録が必要。未登録だとドロップが受理されない。Phase 3 の Gate 条件に含める。

### `.all` スコープ意味変更（中）

`HomeViewModel.scopeMemos` の `.all` case が変わるため、既存の「全メモ」を参照しているコードが他にないか確認が必要。`fetchAllMemos()` は変更しない（SQLiteStore レベルは全メモ取得のまま）。

---

## フェーズ分割

### Phase 1：Session → Folder リネーム（純粋リネーム、動作変更なし）

> **単一レイヤ原則の例外：** Phase 1 は Persistence / ViewModel / View / Controller の4レイヤに同時に触れる。ただしコンパイラが型・メソッド名の漏れをすべて検出できるため、リネームに限り複数レイヤ一括変更を低リスクと判断する。

**変更対象：** `PersistenceModels.swift` / `SessionStore.swift` / `SQLiteStore.swift` / `PersistenceCoordinator.swift` / `HomeViewModel.swift` / `HomeView.swift` / `HomeWindowController.swift`

- `Session` struct → `Folder`
- `SessionStore` クラス → `FolderStore`（ファイルも改名）
- SQLiteStore のメソッド名：`insertSession` → `insertFolder`、`updateSession` → `updateFolder`、`deleteSession` → `deleteFolder`、`fetchAllSessions` → `fetchAllFolders`、`updateMemoSession` → `updateMemoFolder`
- `PersistenceCoordinator`：`createSession` → `createFolder` 等
- `HomeViewModel`：`sessions` → `folders`、`HomeScope.session` → `.folder`、`sessionName(for:)` → `folderName(for:)` → 後の Phase で削除
- `HomeView`：UI テキスト "Sessions" → "Folders"、"Move to Session" → "Move to Folder"、`SessionManagerView` → `FolderManagerView`
- `HomeWindowController`：ハンドラ名変更

**Gate 条件：**
- [ ] ビルドが通ること
- [ ] フォルダ作成・リネーム・削除が動作すること
- [ ] メモのフォルダ割り当てが動作すること
- [ ] 動作が Phase 1 前と変わらないこと（リネームのみ）

---

### Phase 2：サイドバー再構成・メモ数表示・行のフォルダ名削除

**変更対象：** `HomeViewModel.swift` / `HomeView.swift`

1. `HomeScope` から `.pinned` / `.today` / `.last7Days` / `.unsorted` を削除
2. `.all` の `scopeMemos` を `sessionID == nil` に変更
3. `HomeViewModel` にメモ数プロパティを追加：
   - `allMemosCount: Int` （sessionID == nil）
   - `folderCount(id: UUID) -> Int`
   - `trashCount: Int`
4. サイドバーを新構成（All Memos / Folders / Trash）に変更
5. 各サイドバー行に右詰めでカウントバッジを追加
6. サイドバー下部ボタンを「+ New Folder」に変更
7. `MemoRowView` から `sessionName` / `isSessionReady` パラメータと表示を削除
8. コンテキストメニューに「Remove from Folder」（= nil へ assign）を追加

**Gate 条件：**
- [ ] ビルドが通ること
- [ ] All Memos にフォルダ未割り当てメモのみ表示されること
- [ ] フォルダビューに当該フォルダのメモのみ表示されること
- [ ] 各カウントが実態と一致すること（フォルダ移動後に即時反映）
- [ ] メモ行にフォルダ名が表示されないこと
- [ ] Pinned / Today / Last 7 Days がサイドバーに存在しないこと

---

### Phase 3：Drag & Drop 実装

**変更対象：** `HomeView.swift` / `MemoTransferItem.swift`（新規）/ `Info.plist`

1. `Info.plist` に `UTExportedTypeDeclarations` を追加（`com.stickynative.memo-item`）
2. `MemoTransferItem.swift` を新規作成し、`MemoTransferItem: Transferable` と `UTType.memoItem` を定義
3. `MemoRowView` に `.draggable(MemoTransferItem(id: memo.id))` を付与。無効化は `isTrashView` フラグで条件分岐し、`isTrashView == true` のときは `.draggable` モディファイア自体を付与しない（`if !isTrashView { ... .draggable(...) }` のビュー分岐または `@ViewBuilder` 条件で実現）
4. サイドバーのフォルダ行に `.dropDestination(for: MemoTransferItem.self)` を付与
5. `isTargeted` でドロップ先フォルダ行をハイライト
6. ドロップ時に `onAssignFolder(memoID, folderID)` → `viewModel.reload()`（`reload()` は `HomeViewModel` の既存メソッド。新規追加不要）

**Gate 条件：**
- [ ] ビルドが通ること
- [ ] `Info.plist` の UTType 登録が正しいこと
- [ ] メモ行をフォルダ行にドラッグするとフォルダ名がハイライトされること
- [ ] ドロップ後、メモが対象フォルダに移動し、カウントが更新されること
- [ ] All Memos・Trash 行へのドロップが無視されること
- [ ] ゴミ箱ビューのメモがドラッグできないこと
- [ ] すでに同フォルダのメモをそのフォルダにドロップしても壊れないこと

---

## 変更しないこと

- SQLiteStore の DB テーブル名（`sessions`）・列名（`session_id`）
- `SQLiteStore.fetchAll()` / `fetchTrashed()` の返す内容（全メモ取得は維持）
- フォルダ内のピン留め（`isListPinned`）の動作

---

## 回帰・副作用チェック

| 観点 | 確認方法 |
|------|----------|
| リネーム漏れ | ビルドエラーで検出 |
| `.all` 意味変更による既存データの見え方 | フォルダ割り当て済みメモが All Memos に表示されないこと |
| カウントの即時性 | D&D / コンテキストメニュー操作後に `reload()` が呼ばれること |
| ゴミ箱内 D&D の誤操作 | ゴミ箱ビューでドラッグが発動しないこと |

---

## 実機確認項目

### Phase 1 完了後
- [ ] フォルダ作成・リネーム・削除が動作すること
- [ ] メモへのフォルダ割り当て・解除が動作すること

### Phase 2 完了後
- [ ] All Memos：未分類メモのみ表示・カウント正確
- [ ] Folder X：当該フォルダのメモのみ表示・カウント正確
- [ ] Trash：カウント正確
- [ ] フォルダ移動後、元ビューからメモが消え、移動先カウントが増えること

### Phase 3 完了後
- [ ] D&D でフォルダ移動が完了すること
- [ ] ドラッグ中にフォルダ行がハイライトされること
- [ ] All Memos 行・Trash 行へのドロップが無視されること
- [ ] ゴミ箱ビューではドラッグが無効なこと

---

## Section 12 セルフチェックリスト

- [ ] 問題に ID が振られており、実装方針と対応が追える
- [ ] DB 変更なしの判断が明記されている
- [ ] 全フェーズに Gate 条件が定義されている
- [ ] 高リスク変更（UTType 登録）が Gate 条件に含まれている
- [ ] `.all` スコープの意味変更が副作用チェックに含まれている
- [ ] 変更しないことが明示されている
- [ ] 実機確認項目がフェーズ単位で定義されている
- [ ] 変更履歴が記載されている
