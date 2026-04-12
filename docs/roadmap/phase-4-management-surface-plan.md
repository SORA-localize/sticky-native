# Phase 4 Management Surface Plan

最終更新: 2026-04-12

## SSOT 参照宣言

- `/Users/hori/Desktop/Sticky/migration/01_product_decision.md`
- `docs/product/product-vision.md`
- `docs/product/ux-principles.md`
- `docs/product/mvp-scope.md`
- `docs/architecture/domain-model.md`
- `docs/architecture/technical-decision.md`
- `docs/roadmap/development-roadmap-revalidated.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`
- `docs/roadmap/phase-3-draft-persistence-plan.md`

## 今回触る関連ファイル

既存:
- `StickyNativeApp/SQLiteStore.swift`
- `StickyNativeApp/PersistenceModels.swift`
- `StickyNativeApp/PersistenceCoordinator.swift`
- `StickyNativeApp/WindowManager.swift`
- `StickyNativeApp/MenuBarController.swift`
- `StickyNativeApp/MemoWindowView.swift`
- `StickyNativeApp/MemoWindowController.swift`
- `StickyNativeApp/AppDelegate.swift`

新規（Phase 4-3 で追加）:
- `StickyNativeApp/HomeWindowController.swift`
- `StickyNativeApp/HomeView.swift`
- `StickyNativeApp/HomeViewModel.swift`

補足:
- Home は SeamlessWindow ではなく通常の NSWindow を使う（管理 UI であり memo ではない）
- 新規ファイルは Phase 4-3 の 3 つとし、planning guideline の原則 2 を超えるが、AppKit と SwiftUI の責務境界を保つための ViewModel 分離として許容する
- Settings は Phase 4 スコープ外とし、Phase 6 以降で検討する

## 問題一覧

- `P-05`: `is_trashed` フィールドが DB に存在せず、memo を削除する手段がない
- `P-06`: `title`, `created_at` が DB に存在せず、一覧表示に必要な情報が揃っていない
- `U-01`: memo window に削除操作の導線がない
- `U-02`: Home panel に trash タブ・restore・検索の導線がない
- `A-03`: title の生成ロジックが未定義
- `A-04`: Home panel の window lifecycle が未定義
- `K-02`: `MemoWindowView` に "Phase 2" プレースホルダーが残っている

## 目的

- 「書く」と「整理する」を分離する
- memo を安全に削除（trash）できる導線を作る
- すべての memo を一覧できる Home panel を作る
- 一覧から memo を検索・reopen できるようにする

## スコープ In

- DB schema 拡張（`is_trashed`, `title`, `created_at`）
- schema migration（既存 DB への安全な列追加）
- title 自動生成（draft の先頭行から最大 50 文字）
- memo window から trash 操作
- Home panel（一覧・reopen・trash）
- Trash view（restore・empty trash）
- 一覧内検索（クライアントサイドフィルタ）
- "Phase 2" プレースホルダーの除去

## スコープ Out

- Settings（Phase 6 以降）
- FTS（全文検索インデックス）による高速検索
- title の手動編集
- Session との紐付け
- クラウド同期

## 技術詳細確認

### ファイル責務

- `SQLiteStore.swift`
  - schema migration: `PRAGMA table_info` で列の有無を確認し `ALTER TABLE ADD COLUMN` を実行
  - `upsertTitle(id:title:)` の追加
  - `trash(id:)` / `restore(id:)` / `permanentDelete(id:)` の追加
  - `fetchAllMemos()` / `fetchTrashedMemos()` の追加

- `PersistenceCoordinator.swift`
  - `trashMemo(id:)` / `restoreMemo(id:)` / `emptyTrash()` の追加
  - `fetchAllMemos() -> [PersistedMemo]`（非 trash 全件）の追加
  - `fetchTrashedMemos() -> [PersistedMemo]`（trash 全件）の追加
  - title 保存: `saveDraft` 内で first line を切り出し `upsertTitle` を呼ぶ

- `WindowManager.swift`
  - `trashMemo(id:)`: open 中なら window close → coordinator.trashMemo
  - `openMemo(id:)`: open 中なら focus、closed なら reopen、未 open なら DB から新規起動

- `MemoWindowController.swift`
  - trash ボタンの callback `onTrash: (UUID) -> Void` を追加
  - trash 操作後は window close

- `MemoWindowView.swift`
  - "Phase 2" プレースホルダー除去
  - trash ボタン追加（close ボタンと pin ボタンの左に配置）
  - 見た目: xmark と区別するため `trash` / `trash.fill` アイコンを使用

- `MenuBarController.swift`
  - "All Memos" メニュー項目を追加
  - `onOpenHome: (() -> Void)?` コールバックを追加

- `HomeWindowController.swift`（新規）
  - 通常の NSWindow（SeamlessWindow ではない）
  - ウィンドウサイズ: 480×580 程度
  - `HomeView` を SwiftUI hosting で表示
  - singleton: AppDelegate が保持し、2度目以降は既存を front に出す

- `HomeViewModel.swift`（新規）
  - `@Published var refreshID: UUID` を持つ `ObservableObject`
  - `HomeWindowController` が保持し、操作後に `refreshID = UUID()` を更新する
  - `HomeView` が `@ObservedObject` で受け取る

- `HomeView.swift`（新規）
  - `@State var searchQuery: String` でフィルタ
  - `@State var showTrash: Bool` でビュー切替
  - リロードトリガーは `HomeViewModel` 経由で受け取る（後述）
  - memo 一覧: title・draft 先頭 60 文字・updated_at 相対時刻
  - 操作: 行クリックで reopen、trash ボタンで trash/restore
  - 空の場合: プレースホルダー表示

- `AppDelegate.swift`
  - `HomeWindowController` を `var homeWindowController: HomeWindowController?` として保持
  - `menuBarController.onOpenHome` を `homeWindowController.show()` に紐付け

### DB スキーマ変更

追加列:
- `is_trashed INTEGER NOT NULL DEFAULT 0`
- `title TEXT NOT NULL DEFAULT ''`
- `created_at REAL`

migration 方針:
- `SQLiteStore.init()` 内で `PRAGMA table_info(memos)` を実行し、列が存在しなければ `ALTER TABLE ADD COLUMN` を実行
- `DROP TABLE` は使わない

### イベント経路

- memo window trash 操作
  - `MemoWindowView`（trash ボタン）
  - `MemoWindowController`（`onTrash` callback）
  - `WindowManager.trashMemo(id:)`
  - window close → `PersistenceCoordinator.trashMemo(id:)`
  - `HomeView` が次回開いたとき一覧から消える

- Home から reopen
  - `HomeView`（行クリック）
  - `HomeWindowController`（`onOpenMemo(id:)` callback）
  - `WindowManager.openMemo(id:)`
  - open 中: focus / closed: reopen / 未起動: DB から起動

- Home から trash
  - `HomeView`（trash ボタン）
  - `HomeWindowController`（`onTrashMemo(id:)` callback）
  - `WindowManager.trashMemo(id:)` → `PersistenceCoordinator.trashMemo(id:)`
  - `homeViewModel.refreshID = UUID()` → `HomeView` が再フェッチ

- trash restore
  - `HomeView`（restore ボタン、trash タブ）
  - `HomeWindowController`（`onRestoreMemo(id:)` callback）
  - `PersistenceCoordinator.restoreMemo(id:)`（`is_trashed=0` のみ変更、`is_open` は変更しない）
  - WindowManager を経由しない理由: restore は window を開かない操作であり、is_open も変更しないため
  - restore 後に window を開く場合はユーザーが Home から行クリック → `WindowManager.openMemo(id:)` を経由する
  - `homeViewModel.refreshID = UUID()` → `HomeView` が再フェッチ

- empty trash
  - `HomeView`（"Empty Trash" ボタン）
  - `HomeWindowController`（`onEmptyTrash()` callback）
  - `PersistenceCoordinator.emptyTrash()`（`is_trashed=1` の行を全件 hard delete）
  - `homeViewModel.refreshID = UUID()` → `HomeView` が再フェッチ

### title 生成ルール

- draft の先頭行（最初の `\n` 以前）を使用
- 空白 trim 後に最大 50 文字でカット
- 結果が空なら空文字（`HomeView` 側で "Untitled" と表示する）
- 保存タイミング: `saveDraft` 内で計算し `upsertTitle` を呼ぶ

### Home panel の window ライフサイクル

- `AppDelegate` が `HomeWindowController?` を保持
- `show()` 呼び出し時:
  - nil なら新規作成
  - 既存なら `makeKeyAndOrderFront` + `orderFrontRegardless`
- `HomeWindowController` は `windowWillClose` で自身を nil に戻さない（再利用する）

### HomeView のリロード方式

- pull 型を採用する: DB フェッチは `HomeView` の `onAppear` と `HomeViewModel.refreshID` 変化時のみ実行する
- `HomeViewModel: ObservableObject` を新設し、`@Published var refreshID: UUID` を持たせる
- `HomeWindowController` が `HomeViewModel` を保持し、操作後に `homeViewModel.refreshID = UUID()` を呼ぶ
- `HomeView` は `@ObservedObject var viewModel: HomeViewModel` で受け取り、`.onChange(of: viewModel.refreshID)` で再フェッチ
- `HomeWindowController` → `homeViewModel.refreshID = UUID()` → `HomeView` が再フェッチ
- `HomeViewModel` は `HomeView` の `@State` ではないため、AppKit 側から安全に更新できる
- Combine や PersistenceCoordinator への変更通知は Phase 4 では導入しない
- `HomeViewModel` は新規ファイルとして追加する（Phase 4 の新規ファイル上限を 3 に修正）

## 修正フェーズ

### Phase 4-1: DB Migration + Title

目的:
- 既存 DB に安全に列を追加する
- title を draft の先頭行から自動生成・保存する
- "Phase 2" プレースホルダーを除去する

Gate:
- 既存 DB が壊れずに起動できる
- draft を入力すると title が DB に保存される
- MemoWindowView に "Phase 2" テキストが表示されない

### Phase 4-2: Trash

目的:
- memo window から memo を trash に送る操作を作る

Gate:
- trash ボタンを押すと window が閉じ、`is_trashed=1` になる
- trash した memo は "Reopen Last Closed" に出ない

コードレビュー Gate:
- `trashMemo` の経路が `WindowManager → PersistenceCoordinator → SQLiteStore` に一本化されている
- close 経路と trash 経路が混在していない

### Phase 4-3: Home Panel

目的:
- 全 memo を一覧表示し、reopen できる Home panel を作る

Gate:
- menu bar "All Memos" で Home panel が開く
- 非 trash memo が一覧表示される
- 行クリックで memo window が前面に出る

コードレビュー Gate:
- `openMemo(id:)` の経路が `HomeWindowController → WindowManager` に一本化されている
- `SeamlessWindow` が Home panel に混入していない

### Phase 4-4: Trash View + Search

目的:
- Home panel 内で trash 管理と検索ができるようにする

対応 Issue: U-02

Gate:
- "Trash" タブで trash した memo が表示される
- restore と empty trash が動作する
- search bar でフィルタが動作する

## Gate 条件

- 「書く」（memo window）と「整理する」（Home panel）が分離する
- memo の作成 → 編集 → trash → restore → 完全削除の lifecycle が成立する
- 全 memo を一覧から探して reopen できる

## コードレビュー Gate

- trash 経路と close 経路が二重にならない
- Home panel の window lifecycle が `AppDelegate` で一元管理されている
- DB フェッチが `onAppear` と `HomeViewModel.refreshID` 変化時のみ実行され、それ以外から呼ばれない

## 回帰 / 副作用チェック

- trash した memo が "Reopen Last Closed" に混入しない
- Home panel が memo window の focus 挙動に干渉しない
- schema migration が失敗してもアプリが起動不能にならない
- title 保存が autosave 経路に追加負荷を与えすぎない
- SeamlessWindow が Home panel に使われていない
- memo window 側からの trash 操作は Home panel をリアルタイム更新しない（pull 型の想定内挙動）

## 実機確認項目

1. 既存 DB がある状態でアップデートして起動し、memo が失われないこと
2. draft を入力すると title が先頭行から生成されること
3. trash ボタンを押すと window が閉じ、Reopen から出ないこと
4. Home panel を開くと全 memo が表示されること
5. Home から行クリックで memo window が前面に出ること
6. trash タブで restore → memo が一覧に戻ること
7. empty trash で DB から完全削除されること
8. search bar でタイトル・draft の内容を絞り込めること
9. app 再起動後も Home panel が同じ memo 一覧を出すこと
10. memo window と Home panel を両方開いても focus・shortcut が正常に動くこと

## 変更履歴

- 2026-04-12: 初版作成
- 2026-04-12: レビュー指摘対応（U-02 追加、HomeView リロード方式明確化、restore の is_open 挙動明記、SSOT参照宣言に migration 文書と Phase 3 計画を追加）
- 2026-04-12: 再レビュー指摘対応（HomeViewModel 導入で AppKit→SwiftUI のリロードトリガー設計を修正、コードレビュー Gate の表現を修正、新規ファイル数を 3 に更新）
- 2026-04-12: 三次レビュー指摘対応（イベント経路の refreshToken 表現を homeViewModel.refreshID に統一、HomeViewModel のファイル責務記述を追加）
- 2026-04-12: 四次レビュー指摘対応（memo window trash 操作が Home panel をリアルタイム更新しない想定内挙動を回帰チェックに追記）
