# 計画：フォルダ管理UI改善と未分類メモへのD&D

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-23 | 初版作成 |
| 2026-04-23 | レビュー指摘対応。SSOT参照宣言、問題ID、フェーズ分割、Gate条件、回帰/副作用チェック、技術詳細確認、@FocusState疎通確認、セルフチェック結果を追加 |
| 2026-04-23 | 再レビュー指摘対応。`FolderManagerView` 削除迂回方法、`FolderSidebarRowView` 分離判断、`Str` キー名、`commitRename` 再実装方針、`plan-folder-dnd.md` 側の差分反映を追記 |
| 2026-04-23 | 追加レビュー指摘対応。Phase 2 を production の小さい縦切りとして定義、All Memos D&D 受け入れ条件、sheet alert 方針、行選択とダブルクリック編集の構造、rename commit 再入防止、smoke check 方針を追記 |

---

## SSOT参照宣言

### migration 上位文書

`docs/roadmap/stickynative-ai-planning-guidelines.md` §2 は以下を必須 SSOT としている。

- `/Users/hori/Desktop/Sticky/migration/README.md`
- `/Users/hori/Desktop/Sticky/migration/01_product_decision.md`
- `/Users/hori/Desktop/Sticky/migration/02_ux_principles.md`
- `/Users/hori/Desktop/Sticky/migration/04_technical_decision.md`
- `/Users/hori/Desktop/Sticky/migration/06_roadmap.md`
- `/Users/hori/Desktop/Sticky/migration/07_project_bootstrap.md`
- `/Users/hori/Desktop/Sticky/migration/08_human_checklist.md`
- `/Users/hori/Desktop/Sticky/migration/09_seamless_ux_spec.md`

2026-04-23 時点の作業環境では `/Users/hori/Desktop/Sticky/migration` が存在せず参照不能だった。したがって、本計画では repo 内のローカル文書と現行実装を暫定 SSOT とする。migration 文書が復旧した場合は、実装前または次回計画更新時に再照合する。

特に `02_ux_principles.md` と `09_seamless_ux_spec.md` は今回の All Memos D&D / focus 操作に関係する可能性があるため、復旧時の再照合対象として明示する。現時点では、repo 内 `docs/product/ux-principles.md` と既存フォルダD&D計画を根拠に判断する。

### repo 内ローカル文書

| 文書 | 参照目的 | 判断 |
|------|----------|------|
| `docs/roadmap/stickynative-ai-planning-guidelines.md` | 計画書構成、フェーズ分割、@FocusState疎通確認の必須条件 | 本計画の構成をこの文書に合わせる |
| `docs/product/ux-principles.md` | 明快・自然・軽い操作の判断 | 右クリック削除、ダブルクリック名称変更、D&Dで未分類へ戻す操作は自然な管理操作として扱う |
| `docs/product/mvp-scope.md` | `@FocusState` がスコープに含まれることの確認 | 使用する場合は疎通確認 Gate を独立させる |
| `docs/architecture/persistence-boundary.md` | 保存責務の境界 | DB/APIは既存の `PersistenceCoordinator` / `FolderStore` 経由を維持 |
| `docs/architecture/domain-model.md` | Session/Folder と memo assignment の概念確認 | DB名は `sessions` / `session_id` のまま、UI表現は Folder |
| `docs/roadmap/plan-folder-dnd.md` | 既存 Folder D&D 判断 | All Memosドロップ禁止の旧判断を今回の明示要件で上書きする |
| `docs/roadmap/plan-dnd-row-rebuild.md` | D&D実装と `MemoTransferItem` / UTType の既存確認 | 新規転送型は作らず既存型を使う |

### SSOT整合メモ

`plan-folder-dnd.md` では All Memos 行へのドロップを禁止していた。今回の要件は「個別フォルダからドラッグ&ドロップですべてのメモに移動」であり、All Memos が `sessionID == nil` の未分類メモを表す現行仕様では、`onAssignFolder(memoID, nil)` と一致する。

旧判断の禁止理由は「誤操作と意図の曖昧さ」だったが、今回の操作対象は個別フォルダから未分類へ戻す明確な移動である。実装では Trash へのD&Dを引き続き無効にし、All Memosのドロップはフォルダ解除だけに限定することで、誤操作リスクを抑える。

この差分は `docs/roadmap/plan-folder-dnd.md` の変更履歴と Drag & Drop 節にも反映する。旧計画の「All Memos drop 禁止」は当時の Phase 3 判断として残すが、今回の `plan-folder-management-polish.md` を後続の上書き計画として明示し、SSOT衝突を未解消のまま実装しない。

---

## 今回触る関連ファイル

### 実装対象

| ファイル | 責務 |
|----------|------|
| `StickyNativeApp/HomeView.swift` | フォルダ管理ボタン、サイドバー行、削除確認、右クリック、ダブルクリック名称変更、All Memos D&D |
| `StickyNativeApp/Strings.swift` | 「フォルダ管理」「削除」「確認文言」などのローカライズ文字列 |

### 確認対象

| ファイル | 確認内容 |
|----------|----------|
| `StickyNativeApp/HomeViewModel.swift` | `.all` が `sessionID == nil` のメモを表示すること、削除時の fallback |
| `StickyNativeApp/HomeWindowController.swift` | `onDeleteFolder` / `onAssignFolder` の既存経路。原則変更しない |
| `StickyNativeApp/PersistenceCoordinator.swift` | folder CRUD と assign API の境界 |
| `StickyNativeApp/FolderStore.swift` | folder操作がSQLiteStoreへ委譲されていること |
| `StickyNativeApp/SQLiteStore.swift` | `updateMemoFolder(... nil)` と `deleteFolder` トランザクション |
| `StickyNativeApp/MemoTransferItem.swift` | D&D転送型を新規作成しないこと |

---

## 問題一覧

| ID | 種別 | 内容 | 対応 |
|----|------|------|------|
| U-01 | UI | サイドバー下部の「新規フォルダ」が実際の管理シート機能より狭い意味に見える | Phase 1 |
| U-02 | UI | フォルダ削除が即時実行され、誤操作に弱い | Phase 1 |
| U-03 | UI | サイドバー上のフォルダを右クリックして削除できない | Phase 1 |
| F-01 | Focus | サイドバーのダブルクリック名称変更で `@FocusState` を使う場合、focus挙動の疎通確認が必要 | Phase 2 |
| U-04 | UI | サイドバー上のフォルダ名をダブルクリックで名称変更できない | Phase 3 |
| U-05 | Interaction | 個別フォルダから All Memos へD&Dで戻せない | Phase 4 |
| P-01 | Persistence | フォルダ削除時に中のメモが失われないことをUI変更後も確認する必要がある | Phase 5 |
| K-01 | Knowledge | migration SSOT が参照不能で、特に 02/09 との整合が未確認 | Phase 0 / Gate |

---

## 現状調査

### 利用できる既存実装

| 領域 | 既存実装 | 判断 |
|------|----------|------|
| フォルダ管理シート | `HomeView.swift` の `FolderManagerView` | 作成・名称変更・削除UIを流用可能 |
| サイドバー行 | `SidebarRowView` | D&D ハイライトと `dropDestination` の仕組みを拡張可能 |
| メモD&D転送型 | `MemoTransferItem` | そのまま利用可能 |
| フォルダ割り当てAPI | `onAssignFolder(memoID, folderID)` | `folderID == nil` で未分類へ戻せる |
| 永続化 | `SQLiteStore.updateMemoFolder(id:folderID:)` | `NULL` バインドに対応済み |
| フォルダ削除 | `SQLiteStore.deleteFolder(id:)` | トランザクションでメモを未分類に戻してから削除済み |
| 既存確認モーダル | `MemoWindowView` の `.alert` | フォルダ削除確認に同じパターンを利用可能 |

### 修正不要な領域

DBスキーマや永続化境界は変更不要。`sessions` テーブル名と `session_id` 列名は既存方針どおり維持する。

`SQLiteStore.deleteFolder(id:)` はすでに以下の順序で動くため、フォルダ削除時に中のメモが消えるリスクは低い。

1. `BEGIN`
2. 対象フォルダのメモを `session_id = NULL` に戻す
3. フォルダ行を削除
4. `COMMIT`

---

## 仕様

### 1. 「新規フォルダ」ボタン名変更

サイドバー下部のボタン表示を「フォルダ管理」に変更する。

- 日本語: `フォルダ管理`
- 英語: `Manage Folders`

既存の `Str.newFolder` は新規作成入力のプレースホルダーとして残す。

### 2. フォルダ削除確認

フォルダ削除前に確認モーダルを出す。

- タイトル: `このフォルダを削除しますか？` / `Delete this folder?`
- 補足文: `中のメモはすべてのメモに移動します。` / `Memos in this folder will move to All Memos.`
- 実行ボタン: `削除` / `Delete`
- キャンセル: 既存 `Str.trashAlertCancel` を流用する

削除確定後は既存の `onDeleteFolder` を呼ぶ。選択中フォルダを削除した場合は、既存の `deleteFolderFallbackIfNeeded(id:)` により `.all` へ戻す。

### 3. サイドバー右クリック削除

フォルダ行に `contextMenu` を追加し、削除メニューを出す。

- 対象: `.folder(id)` の行のみ
- 表示: `削除` / `Delete`
- 実行: 直接削除せず、確認モーダルを開く

`All Memos` と `Trash` は右クリック削除対象外。

### 4. サイドバーダブルクリック名称変更

フォルダ名部分をダブルクリックしたら、同じ位置で `TextField` に切り替える。

- 対象: フォルダ名テキストのみ
- 確定: Enter またはフォーカス喪失
- キャンセル相当: 空文字の場合は元の名前に戻す
- 変更なし: trim 後に同名なら保存しない

`FolderManagerView.commitRename(for:)` は `private` であり、サイドバー側から直接呼べない。サイドバー名称変更では同じ trim / 空文字 / 同名判定ルールを `HomeView` 側の helper として再実装する。

### 5. フォルダから All Memos へのD&D

個別フォルダで表示中のメモを、サイドバーの「すべてのメモ」にドラッグ&ドロップできるようにする。

- ドロップ先: `.all` 行
- 実行: drop対象memoの `sessionID != nil` の場合のみ `onAssignFolder(memoID, nil)`
- すでに `sessionID == nil` の memo は no-op とする
- 結果: メモの `session_id` が `NULL` になり、未分類メモとして All Memos に表示される
- Trash 行へのD&Dは引き続き無効

表示スコープ別の仕様:

| 表示状態 | All Memos drop |
|----------|----------------|
| フォルダ表示中 | `sessionID != nil` のメモだけ未分類へ戻す |
| All Memos 表示中 | no-op |
| 検索中 | 検索結果にフォルダ内メモが含まれる場合は未分類へ戻す。未分類メモは no-op |
| Trash 表示中 | メモ行自体をドラッグ不可のまま維持する |

---

## 技術詳細確認

### 責務配置

| 責務 | 配置 | 理由 |
|------|------|------|
| UI表示・ユーザー操作 | `HomeView.swift` | 既存 Home 管理画面のローカル View が集約されている |
| ローカライズ文言 | `Strings.swift` | 既存の文字列管理に合わせる |
| サイドバー削除確認状態 | `HomeView` の `pendingDeleteFolder` | サイドバー右クリック削除は親HomeViewのalertで確認する |
| 管理シート削除確認状態 | `FolderManagerView` の `pendingDeleteFolderInSheet` | sheet表示中はsheet内alertで確認する |
| サイドバー名称編集中状態 | `HomeView` | サイドバーの表示状態であり永続化対象ではない |
| フォルダ永続化 | 既存 `HomeWindowController` → `PersistenceCoordinator` → `FolderStore` → `SQLiteStore` | 既存境界を維持 |
| D&D転送 | 既存 `MemoTransferItem` | 新規UTTypeや転送型を増やさない |

### View分割判断

`SidebarRowView` は現状、通常行表示と D&D 受け入れだけを担う。ダブルクリック名称変更、context menu、focus、rename commit を同じ View に押し込むと、All Memos / Trash まで編集用状態を持つ形になり責務が広がる。

したがって、本実装では以下に分ける。

- `SidebarRowView`: All Memos / Trash / 汎用D&D行に使う。既存責務を維持する。
- `FolderSidebarRowView`: フォルダ行専用。右クリック削除、ダブルクリック名称変更、`@FocusState`、フォルダへのD&Dを担当する。

どちらも `HomeView.swift` 内の `private struct` とし、新規ファイルは作らない。

`FolderSidebarRowView` は行全体を `Button` にしない。macOS SwiftUI で `Button` 内に `TextField` や double click gesture を入れると、single click選択、double click編集、focus が競合しやすいため、次の構造にする。

- 非編集中: `HStack` 全体に `.contentShape(Rectangle()).onTapGesture { onSelect() }`
- フォルダ名 `Text` のみ `.onTapGesture(count: 2) { beginEditing(folder) }`
- 編集中: フォルダ名部分を `TextField` に差し替え、行全体の選択gestureは外す
- context menu はフォルダ行のコンテナに付与する
- D&D dropDestination はフォルダ行のコンテナに付与する

### 文字列キー

`Strings.swift` に追加するキーは以下に固定する。

| Key | Japanese | English |
|-----|----------|---------|
| `folderManagement` | `フォルダ管理` | `Manage Folders` |
| `delete` | `削除` | `Delete` |
| `deleteFolderAlertTitle` | `このフォルダを削除しますか？` | `Delete this folder?` |
| `deleteFolderAlertMessage` | `中のメモはすべてのメモに移動します。` | `Memos in this folder will move to All Memos.` |

`Str.trashAlertCancel` は既存の `キャンセル` / `Cancel` として流用し、新規 cancel key は追加しない。

### メモリ管理と persistence 境界

メモリに持つもの:

- `HomeView.pendingDeleteFolder: Folder?`（サイドバー右クリック削除用）
- `FolderManagerView.pendingDeleteFolderInSheet: Folder?`（管理シート内削除用）
- `editingSidebarFolderID: UUID?`
- `editingSidebarFolderName: String`
- `isDropTargeted` など既存 hover/drop 表示状態

メモリに持たないもの:

- フォルダ削除後のメモ移動結果
- フォルダ名の永続値
- メモの folder assignment の永続値

永続化は既存の `onRenameFolder`、`onDeleteFolder`、`onAssignFolder` 経由に限定する。

### 削除確認設計

削除確認は導線ごとに alert の配置を分ける。

- サイドバー右クリック削除: `HomeView.pendingDeleteFolder` と `HomeView.alert`
- 管理シート内削除: `FolderManagerView.pendingDeleteFolderInSheet` と `FolderManagerView.alert`

現在の `FolderManagerView` は `onDelete: (UUID) -> Void` を直接呼ぶため、そのままでは確認モーダルを迂回する。実装では `FolderManagerView` の削除クロージャを次のように変更する。

```swift
private struct FolderManagerView: View {
  let folders: [Folder]
  let onCreate: (String) -> Void
  let onRename: (UUID, String) -> Void
  let onDeleteConfirmed: (UUID) -> Void

  @State private var pendingDeleteFolderInSheet: Folder?
}
```

`FolderManagerView` のゴミ箱ボタンは `pendingDeleteFolderInSheet = folder` だけを行う。シート内の `.alert` でユーザーが削除確定したときに `onDeleteConfirmed(folder.id)` を呼ぶ。

`HomeView` は sheet 作成時に次を渡す。

```swift
FolderManagerView(
  folders: viewModel.folders,
  onCreate: onCreateFolder,
  onRename: onRenameFolder,
  onDeleteConfirmed: onDeleteFolder
)
```

これにより `HomeWindowController` のクロージャシグネチャは変更しない。

サイドバー削除は `FolderSidebarRowView.onRequestDelete(folder)` → `HomeView.pendingDeleteFolder` → `HomeView.alert` を使う。管理シート削除は `FolderManagerView.pendingDeleteFolderInSheet` → `FolderManagerView.alert` を使う。どちらも最終的には既存 `onDeleteFolder(folder.id)` を呼ぶ。

`HomeView.alert` または `FolderManagerView.alert` → `onDeleteFolder(folder.id)` → `HomeWindowController.handleDeleteFolder` → `viewModel.deleteFolderFallbackIfNeeded(id:)` → `coordinator.deleteFolder(id:)` → `viewModel.reload()`

### AppKit ↔ SwiftUI の責務境界

本変更は管理画面内の SwiftUI 操作に閉じる。`NSWindowController`、`NSPanel`、`SeamlessWindow`、global shortcut、memo window focus には触らない。

AppKit側の責務:

- `HomeWindowController` が SwiftUI `HomeView` に handler を渡す
- window表示、reload呼び出し、既存 coordinator 経由の永続化

SwiftUI側の責務:

- ボタン/メニュー/alert/TextField/dropDestination のUI状態
- ユーザー操作を handler に変換する
- 一時的な編集状態と削除確認状態を持つ

### ユーザー操作のイベント経路

サイドバー右クリック削除:

1. ユーザーがサイドバーのフォルダ行を右クリックし、削除を押す
2. `FolderSidebarRowView.onRequestDelete(folder)` を呼ぶ
3. `HomeView.pendingDeleteFolder = folder`
4. `HomeView.alert` が表示される
5. ユーザーが削除確定する
6. `onDeleteFolder(folder.id)` を呼ぶ
7. `HomeWindowController.handleDeleteFolder` が `deleteFolderFallbackIfNeeded` → `coordinator.deleteFolder` → `viewModel.reload()` を実行する

管理シート内削除:

1. ユーザーが `FolderManagerView` のゴミ箱ボタンを押す
2. `FolderManagerView.pendingDeleteFolderInSheet = folder`
3. `FolderManagerView.alert` が表示される
4. ユーザーが削除確定する
5. `FolderManagerView.onDeleteConfirmed(folder.id)` を呼ぶ
6. `HomeView` から渡された既存 `onDeleteFolder(folder.id)` が実行される
7. `HomeWindowController.handleDeleteFolder` が `deleteFolderFallbackIfNeeded` → `coordinator.deleteFolder` → `viewModel.reload()` を実行する

サイドバー名称変更:

1. ユーザーがフォルダ名をダブルクリックする
2. `editingSidebarFolderID` と `editingSidebarFolderName` をセットする
3. 表示を `Text` から `TextField` に切り替える
4. Phase 2 の疎通確認を通過した場合のみ `FolderSidebarRowView` 内の `@FocusState` で focus を当てる
5. Enter または focus 喪失で trim して `onRenameFolder` を呼ぶ
6. `viewModel.reload()` 後に通常表示へ戻す

rename commit は再入可能なイベントから呼ばれるため、helper は idempotent にする。`commitSidebarRename()` は最初に現在の `editingSidebarFolderID` と `editingSidebarFolderName` をローカル定数へ退避し、その直後に `editingSidebarFolderID = nil` / `editingSidebarFolderName = ""` を実行する。その後に trim と保存判定を行う。これにより `onSubmit` と focus喪失が連続しても2回保存しない。

All Memos D&D:

1. ユーザーがメモ行をドラッグする
2. 既存 `MemoTransferItem(id:)` が転送される
3. All Memos行の `dropDestination` が受け取る
4. `viewModel.memos` から対象memoを引き、`sessionID != nil` の場合だけ `onAssignFolder(memoID, nil)` を呼ぶ
5. `HomeWindowController.handleAssignFolder` が `coordinator.assignFolder` → `viewModel.reload()` を実行する

### 状態遷移

| 対象 | 変更前 | 操作 | 変更後 |
|------|--------|------|--------|
| サイドバー削除確認 | `HomeView.pendingDeleteFolder == nil` | 右クリック削除 | `HomeView.pendingDeleteFolder == folder` |
| サイドバー削除確定 | `HomeView.pendingDeleteFolder == folder` | alert確定 | folder削除、選択中なら `.all`、`HomeView.pendingDeleteFolder == nil` |
| 管理シート削除確認 | `FolderManagerView.pendingDeleteFolderInSheet == nil` | ゴミ箱ボタン | `FolderManagerView.pendingDeleteFolderInSheet == folder` |
| 管理シート削除確定 | `FolderManagerView.pendingDeleteFolderInSheet == folder` | alert確定 | folder削除、`pendingDeleteFolderInSheet == nil` |
| サイドバー名称変更 | `editingSidebarFolderID == nil` | ダブルクリック | `editingSidebarFolderID == folder.id` |
| 名称変更確定 | 編集中 | Enter/focus喪失 | rename後に `editingSidebarFolderID == nil`、`editingSidebarFolderName == ""` |
| 名称変更キャンセル相当 | 編集中 | 空文字確定 | 保存せず `editingSidebarFolderID == nil`、元名表示 |
| D&D to All Memos | `memo.sessionID == folderID` | All Memosへdrop | `memo.sessionID == nil` |
| D&D to All Memos no-op | `memo.sessionID == nil` | All Memosへdrop | 変更なし |

close / reopen / pin:

- memo window の close / reopen / pin 状態は変更対象外。
- D&D やフォルダ削除でメモの `session_id` は変わるが、window open state / pinned state には触れない。
- 回帰確認では、開いているメモをフォルダ移動しても既存 window が閉じないことを実機で見る。

### 後続フェーズとの衝突確認

- DB schema / migration は変更しないため、後続の persistence 計画と衝突しない。
- `MemoTransferItem` と UTType は既存を使うため、D&D row rebuild との型重複は起こさない。
- Home管理画面のUIに閉じるため、memo editor、global shortcut、menu bar には触らない。
- `@FocusState` を使う場合は Phase 2 の疎通確認を通過するまで本実装に混ぜない。

---

## 修正フェーズ

### Phase 0: SSOT / 既存経路確認

主目的: migration unavailable の扱いと既存実装の利用可否を固定する。

対応Issue: K-01 / P-01

作業:

- migration SSOT が参照不能であることを記録する
- repo 内文書を暫定SSOTとして扱う
- `SQLiteStore.deleteFolder` と `updateMemoFolder(... nil)` の既存挙動を確認する

Gate:

- [x] migration SSOT が参照不能であることを明記した
- [x] repo 内ローカル文書の参照根拠を明記した
- [x] DB schema変更不要と判断した

### Phase 1: 低リスクUIポリッシュ

主目的: 削除の安全性とメニュー表現を改善する。

対応Issue: U-01 / U-02 / U-03

作業:

- 「新規フォルダ」ボタンを「フォルダ管理」に変更
- `HomeView.pendingDeleteFolder` と `HomeView.alert` をサイドバー右クリック削除用に追加
- `FolderManagerView.pendingDeleteFolderInSheet` と `FolderManagerView.alert` を管理シート削除用に追加
- `FolderManagerView` の削除ボタンを `pendingDeleteFolderInSheet` セットへ変更
- `FolderManagerView` の削除確定クロージャを `onDeleteConfirmed: (UUID) -> Void` に変更
- サイドバー右クリック削除メニューを追加

Gate:

- [ ] 管理シート削除が確認モーダルを経由する
- [ ] 管理シートを開いたまま削除確認が前面に出る
- [ ] サイドバー右クリック削除が確認モーダルを経由する
- [ ] キャンセルで削除されない
- [ ] 選択中フォルダ削除後に `.all` へ戻る
- [ ] `xcodebuild -project StickyNative.xcodeproj -scheme StickyNative -configuration Debug build` が通る

### Phase 2: @FocusState production縦切り

主目的: サイドバー名称変更に必要な focus 制御だけを、production code の小さい縦切りとして確認する。

このPhaseは破棄可能プローブではない。`FolderSidebarRowView` の最小版をproduction codeとして追加し、編集対象は1行、保存処理はno-opまたはローカル状態に閉じる。Phase 2完了時に残すコードは `FolderSidebarRowView` の構造、`@FocusState`、編集開始/終了の状態管理のみ。Phase 3で永続化rename、空文字/同名validation、reload後の整合を追加する。

Phase 2 は単独リリース対象にしない。production code として残すのは focus と編集状態の疎通済み土台だけで、ユーザー向け機能として完了扱いにするのは Phase 3 Gate 通過後とする。

対応Issue: F-01

作業:

- サイドバー行内 `TextField` へ `@FocusState` で focus できるか小さく確認する
- Enter確定と focus喪失確定が二重発火しないよう、state clear first の `commitSidebarRename()` 形を入れる
- 疎通確認で無理がある場合、`@FocusState` を使わずクリック後に手動選択させる fallback に切り替える

Gate:

- [ ] ダブルクリック後に TextField が表示される
- [ ] `@FocusState` 使用時に TextField へ focus が入る
- [ ] Enter確定が1回だけ発火する
- [ ] focus喪失確定が1回だけ発火する
- [ ] Home window の検索フィールド focus と競合しない
- [ ] Phase 2で残すproduction codeとPhase 3で追加するvalidation/永続化の境界が実装コメントまたは本計画に残っている
- [ ] Phase 2単独ではリリース完了扱いにせず、Phase 3へ続けることが明記されている

### Phase 3: サイドバー名称変更

主目的: フォルダ名のダブルクリック名称変更を実装する。

対応Issue: U-04

作業:

- Phase 2で追加した `FolderSidebarRowView` に永続化renameを接続する
- trim / 空文字 / 同名時の処理を `FolderManagerView` と同じルールで実装する
- `commitSidebarRename()` は state clear first で再入を防ぐ

Gate:

- [ ] ダブルクリックで編集状態になる
- [ ] Enterで名称変更できる
- [ ] focus喪失で名称変更できる
- [ ] Enter直後のfocus喪失で保存が二重発火しない
- [ ] 空文字確定で元名に戻る
- [ ] 同名確定で不要な保存をしない
- [ ] single click 選択後、double click で編集に入り、選択状態も壊れない
- [ ] `xcodebuild` が通る

### Phase 4: All Memos へのD&D

主目的: 個別フォルダから未分類へ戻すD&Dを追加する。

対応Issue: U-05

作業:

- `.all` の `SidebarRowView` に `onDrop` を渡す
- drop handler 内で対象memoを `viewModel.memos` から確認し、`sessionID != nil` の場合のみ `onAssignFolder(memoID, nil)` を呼ぶ
- Trash行へのD&Dは引き続き無効にする
- D&D後に `viewModel.reload()` で一覧とカウントを更新する

Gate:

- [ ] フォルダ内メモを All Memos へdropすると未分類へ戻る
- [ ] フォルダ側のカウントが減り、All Memos側のカウントが増える
- [ ] All Memos表示中の未分類メモをAll Memosへdropしても no-op で破綻しない
- [ ] 検索中にフォルダ内メモをAll Memosへdropすると未分類へ戻る
- [ ] 検索中に未分類メモをAll Memosへdropしても no-op で破綻しない
- [ ] Trash行にはdropできない
- [ ] `xcodebuild` が通る

### Phase 5: Regression Gate

主目的: Home管理画面と window/persistence への副作用がないことを確認する。

対応Issue: P-01

Gate:

- [ ] フォルダ削除後、中のメモが All Memos に移動する
- [ ] 開いているメモをD&D移動しても memo window が閉じない
- [ ] pin / list pin 状態が変わらない
- [ ] Home window を閉じて再表示してもフォルダ一覧とカウントが正しい
- [ ] アプリ再起動後、フォルダ名とメモ割り当てが維持されている
- [ ] global shortcut で新規メモを作成できる smoke check
- [ ] Home window のフォルダ行を1 clickで選択できる smoke check
- [ ] 既存 memo window のゼロクリック入力が壊れていない smoke check

---

## Issue → Phase 対応表

| Issue | Phase |
|-------|-------|
| K-01 | Phase 0 |
| P-01 | Phase 0 / Phase 5 |
| U-01 | Phase 1 |
| U-02 | Phase 1 |
| U-03 | Phase 1 |
| F-01 | Phase 2 |
| U-04 | Phase 3 |
| U-05 | Phase 4 |

---

## Gate条件

- [ ] Phase 1完了前に Phase 3/4 の新規インタラクションを混ぜない
- [ ] `@FocusState` を使う場合は Phase 2 Gate を通過してから Phase 3 に進む
- [ ] `docs/roadmap/plan-folder-dnd.md` に All Memos D&D 判断の上書き理由を反映してから Phase 4 に進む
- [ ] migration SSOT が復旧した場合は、02/09 を含む上位文書と再照合してから実装する
- [ ] 各Phaseで `xcodebuild` が通る
- [ ] Phase 5 の実機回帰確認を完了する

---

## 回帰 / 副作用チェック

| 観点 | リスク | 確認 |
|------|--------|------|
| Home sidebar selection | ダブルクリック編集が通常のフォルダ選択を妨げる | single click 選択、double click 編集を実機確認 |
| Search focus | `@FocusState` が検索フィールドやシート入力と競合する | 検索入力後、名称変更後のfocusを確認 |
| Sheet alert | 親View alert が sheet に隠れる | 管理シート内に alert を置き、シートを開いたまま確認が前面に出ることを確認 |
| Folder delete | 削除確認後に中のメモが消える | All Memosへ移動していることを確認 |
| D&D | All Memos drop が誤ってTrashや別フォルダ扱いになる | drop先ごとの挙動を確認 |
| Counts | D&D/削除後にサイドバーの件数が古い | `viewModel.reload()` 後の件数を確認 |
| Open memo window | フォルダ割り当て変更で開いているメモwindowが閉じる | 開いたまま移動して確認 |
| Persistence | relaunch後に割り当てや名称が戻る | アプリ再起動後に確認 |
| Existing context menu | メモ行の既存コンテキストメニューに影響する | pin / move / trash を確認 |

---

## 実機確認項目

- [ ] メモ管理画面下部ボタンが「フォルダ管理」になっている
- [ ] フォルダ管理シートで削除ボタンを押すと確認モーダルが出る
- [ ] フォルダ管理シートを開いたまま削除確認が前面に出る
- [ ] サイドバーのフォルダ右クリックで削除メニューが出る
- [ ] サイドバー右クリック削除も確認モーダルを経由する
- [ ] キャンセルで削除されない
- [ ] サイドバーのフォルダ名をダブルクリックして名称変更できる
- [ ] 空文字で確定してもフォルダ名が壊れない
- [ ] フォルダ内メモを All Memos にドロップすると未分類へ戻る
- [ ] Trash にはD&Dできない
- [ ] フォルダ削除後、中のメモが All Memos に移動する
- [ ] Home window を閉じて開き直しても表示が正しい
- [ ] アプリ再起動後もフォルダ名とメモ割り当てが維持される
- [ ] global shortcut で新規メモを作成できる
- [ ] 既存 memo window でゼロクリック入力が維持される

---

## 実装メモ

永続化層は現状のままで足りる。もし実装中に `HomeView.swift` の責務が重くなりすぎる場合は、`FolderSidebarRowView` か `FolderDeleteConfirmation` 相当の小コンポーネントへ分離する。ただし今回の要件では、新規ファイル追加より `HomeView.swift` 内の既存ローカルView拡張で十分対応できる見込み。

`@FocusState` は高リスク疎通確認対象なので、Phase 2 で production code の小さい縦切りとして独立確認する。疎通結果が不安定なら、ダブルクリック後に TextField は出すが自動focusに依存しない fallback を採用する。

---

## セルフチェック結果

### SSOT整合

[x] migration README は参照不能であることを確認した  
[x] 01_product_decision は参照不能であることを確認した  
[x] 02_ux_principles は参照不能であることを確認した  
[x] 06_roadmap は参照不能であることを確認した  
[x] 07_project_bootstrap は参照不能であることを確認した  
[x] 09_seamless_ux_spec は参照不能であることを確認した  
[x] repo 内ローカル文書を暫定SSOTとして明記した  
[x] All Memos D&D の旧判断との差分理由を明記した  

### 変更範囲

[x] 主目的は Home のフォルダ管理UI改善に限定した  
[x] 高リスク疎通確認テーマは `@FocusState` 1つとして独立Phase化した  
[x] 低リスクUIポリッシュと新規インタラクションをPhase分割した  
[x] ついで作業を入れていない  

### 技術詳細

[x] ファイルごとの責務が明確  
[x] メモリ管理と persistence の境界が明確  
[x] イベント経路と状態遷移を記載した  
[x] AppKit / SwiftUI の責務境界を記載した  

### Window / Focus

[x] Window 責務は `HomeWindowController` 既存境界から動かさない  
[x] Focus 制御は Phase 2 の疎通確認まで本実装に混ぜない  
[x] first mouse は変更対象外だが、Home window 操作の実機確認に含めた  

### Persistence

[x] 保存経路は既存 `PersistenceCoordinator` / `FolderStore` / `SQLiteStore` に一本化されている  
[x] frame と open 状態は変更対象外と明記した  
[x] relaunch 時の扱いを実機確認項目に含めた  

### 実機確認

[x] global shortcut は本変更の直接対象外。ただし Phase 5 smoke check で確認する  
[x] 1 click 操作は Home sidebar 選択の副作用確認として Phase 5 smoke check に含めた  
[x] ゼロクリック入力は memo window の副作用確認として Phase 5 smoke check に含めた  
[x] Home管理画面のフォルダ操作確認項目を列挙した  
