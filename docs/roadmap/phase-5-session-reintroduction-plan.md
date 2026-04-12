# Phase 5 Session Reintroduction Plan

最終更新: 2026-04-12

## SSOT 参照宣言

migration 上位文書（planning guideline §2 必須参照セット）:
- `/Users/hori/Desktop/Sticky/migration/README.md`
- `/Users/hori/Desktop/Sticky/migration/01_product_decision.md`
- `/Users/hori/Desktop/Sticky/migration/02_ux_principles.md`
- `/Users/hori/Desktop/Sticky/migration/03_domain_and_data.md`
- `/Users/hori/Desktop/Sticky/migration/04_technical_decision.md`
- `/Users/hori/Desktop/Sticky/migration/06_roadmap.md`
- `/Users/hori/Desktop/Sticky/migration/07_project_bootstrap.md`
- `/Users/hori/Desktop/Sticky/migration/08_human_checklist.md`
- `/Users/hori/Desktop/Sticky/migration/09_seamless_ux_spec.md`

StickyNative ローカル補助文書:
- `docs/product/product-vision.md`
- `docs/product/ux-principles.md`
- `docs/product/mvp-scope.md`
- `docs/architecture/domain-model.md`
- `docs/architecture/technical-decision.md`
- `docs/roadmap/development-roadmap-revalidated.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`
- `docs/roadmap/phase-4-management-surface-plan.md`

## 今回触る関連ファイル

既存:
- `StickyNativeApp/SQLiteStore.swift`
- `StickyNativeApp/PersistenceModels.swift`
- `StickyNativeApp/PersistenceCoordinator.swift`
- `StickyNativeApp/HomeView.swift`
- `StickyNativeApp/HomeViewModel.swift`
- `StickyNativeApp/HomeWindowController.swift`
- `StickyNativeApp/AppDelegate.swift`
- `docs/architecture/domain-model.md`

新規（Phase 5-2 で追加）:
- `StickyNativeApp/SessionStore.swift`（session CRUD を SQLiteStore から分離）

補足:
- Session は「表示単位」ではなく「論理グループ（データ単位）」として実装する（03_domain_and_data.md §2）
- 旧アプリの 15 スロット固定配置・9 枚 session 概念は採用しない
- `WindowManager` は session_id を一切知らない（window lifecycle への session 混入禁止）

## 問題一覧

- `A-05`: `sessions` テーブルが DB に存在せず、論理グループ単位での管理ができない
- `A-06`: `memos.session_id` が存在せず、memo を session に紐付けられない
- `U-03`: session を作成・命名・削除する UI がない（Home panel に導線なし）
- `U-04`: memo を session に割り当てる UI がない
- `U-05`: Home panel で session 単位のフィルタができない
- `K-03`: `domain-model.md` が Phase 4 以降の実装と同期していない（Phase 5-1 で対応）

## 目的

- memo を論理グループ（session）でまとめる手段を作る
- Home panel で session を作成・命名・削除し、memo を割り当てられるようにする
- Home panel で session 単位に絞り込めるようにする
- 複雑化ではなく整理価値として機能する最小 session を実装する

## スコープ In

- DB: `sessions` テーブル追加（id, name, created_at, updated_at）
- DB: `memos.session_id` 列追加（nullable FK）
- session の作成・命名（rename）・削除（U-03）
- Home panel に session フィルタドロップダウン（U-05）
- Home panel の memo 行から session への割り当て変更（U-04）
- 新規 memo は session 未割り当て（NULL = Unsorted）として作成
- `domain-model.md` を現状の実装に同期して更新（K-03）

## スコープ Out

- session 間の memo ドラッグ空間操作
- memo window から直接 session を指定して作成
- session ごとの一括 close / open
- session の並び替え
- Settings（Phase 6）

## 技術詳細確認

### Session の意味と UX 方針

- session = 論理グループ。window とは独立。「コンテキスト（仕事・個人・プロジェクト X）」程度の粒度
- memo は session に属するか、未割り当て（Unsorted）のどちらかの状態を持つ
- 新規 memo は常に Unsorted として作成される（作成時に session 選択を要求しない）
- session フィルタは **Memos タブにのみ適用する**。Trash タブは session に関係なく全件表示する
  - 理由: trash は「削除予定」の bin であり、session 分類より上位の状態として扱う

### ファイル責務

- `SQLiteStore.swift`
  - sessions テーブルの CREATE TABLE IF NOT EXISTS を追加
  - `memos.session_id` 列の migration 追加
  - session CRUD の raw SQL メソッド: `insertSession`, `updateSession(id:name:)`, `deleteSession(id:)`, `fetchAllSessions`
  - `updateMemoSession(id:sessionID:)` の追加（session_id を NULL に戻す場合も同メソッドで扱う）

- `SessionStore.swift`（新規）
  - session CRUD を SQLiteStore のメソッドへ委譲するラッパー
  - `PersistenceCoordinator` が保持する
  - SQLiteStore がすでに大きいため、session 操作ロジックを独立ファイルに置くことで責務分離を維持する

- `PersistenceModels.swift`
  - `Session` struct 追加（id: UUID, name: String, createdAt: Date, updatedAt: Date）
  - `PersistedMemo` に `sessionID: UUID?` を追加

- `PersistenceCoordinator.swift`
  - session 操作の public API:
    - `createSession(name:) -> Session`
    - `renameSession(id:name:)`
    - `deleteSession(id:)`（memo を Unsorted に戻す → session 行削除、の 2 ステップ）
    - `fetchAllSessions() -> [Session]`
    - `assignSession(memoID:sessionID:)`
    - `unassignSession(memoID:)`

- `HomeViewModel.swift`
  - `@Published var sessions: [Session] = []` を追加
  - `SessionFilter` enum: `.all`, `.unsorted`, `.session(UUID)` を追加（ファイル内 private）
  - `@Published var selectedFilter: SessionFilter = .all` を追加
  - `reload()` で sessions も取得するよう拡張
  - `filteredMemos` 計算プロパティを追加（`selectedFilter` × `searchQuery` × `memos` の合成）

- `HomeView.swift`
  - toolbar レイアウト:
    ```
    [ Memos | Trash ]  [All ▼]  [⋯]  [search bar]
                        ↑        ↑
                     フィルタ  管理ボタン
    ```
  - session フィルタ Picker（`.menu` スタイル）はフィルタ専用とする
    - 項目: All / Unsorted / ─ / Session A / Session B
    - CRUD 操作はここには置かない
    - SwiftUI Picker の menu 項目には contextMenu が安定して動作しないため、CRUD 導線を Picker 内に混在させない
  - 管理ボタン（`⋯` または `ellipsis.circle` アイコン）を Picker 横に配置
    - クリックで `.sheet` を表示し、セッション管理シートを開く
    - シート構成: セッション名一覧 + 各行に rename（TextField インライン編集）/ delete（trash icon）ボタン + 末尾に "+" 追加ボタン
  - rename 確定条件: TextField の `onSubmit`（Return キー）またはフォーカス外れ（`onChange` + `onDisappear`）で確定。空文字または空白のみの場合は変更を破棄し、元の名前に戻す
    - シートは `isSessionManagerPresented: Bool` の `@State` で制御する
  - Trash タブ選択中は session フィルタ Picker と管理ボタンを `.disabled(true)` にする
  - `displayedMemos` を `viewModel.filteredMemos` に置き換える

- `HomeWindowController.swift`
  - session 操作のコールバックを追加:
    - `onCreateSession: ((String) -> Void)?`
    - `onRenameSession: ((UUID, String) -> Void)?`
    - `onDeleteSession: ((UUID) -> Void)?`
    - `onAssignSession: ((UUID, UUID?) -> Void)?`（sessionID=nil で Unsorted に戻す）
  - 各ハンドラで coordinator を直接呼び、`viewModel.reload()` を実行

- `AppDelegate.swift`
  - `homeWindowController` への session コールバック配線を追加
  - WindowManager は経由しない（session は window lifecycle と無関係）

### DB スキーマ変更

新テーブル:
```sql
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL DEFAULT '',
  created_at REAL NOT NULL,
  updated_at REAL NOT NULL
)
```

追加列（migration）:
- `memos.session_id TEXT REFERENCES sessions(id)`（nullable）

migration 方針:
- `PRAGMA table_info(memos)` で `session_id` 列の有無を確認し、なければ `ALTER TABLE ADD COLUMN` を実行
- sessions テーブルは `CREATE TABLE IF NOT EXISTS` で常時実行（冪等）
- `PRAGMA foreign_keys = ON` を `SQLiteStore.init` で設定する

migration 失敗時の扱い:
- `ALTER TABLE` は `do { try } catch {}` で包む
- 失敗した場合でも `SQLiteStore.init` はエラーを throw せず、degraded 状態で起動する
- `SQLiteStore` は `var isSessionReady: Bool = false` を持ち、migration 成功時のみ `true` にする
- `PersistenceCoordinator` は `isSessionReady` を公開し、`HomeViewModel` がこれを参照する
- `HomeViewModel` で `isSessionReady == false` の場合:
  - `sessions` は空のまま
  - `selectedFilter` を `.all` に固定
  - session フィルタ Picker と管理ボタンを `isSessionReady` で `.disabled` にする
- 「session UI が表示されない正常系（session ゼロ件）」と「degraded（migration 失敗）」の区別:
  - `isSessionReady == false` → Picker と管理ボタンが disabled 表示になる
  - `isSessionReady == true` かつ sessions 空 → Picker は enabled、All/Unsorted のみ表示
- Phase 5-3 / 5-4 の Gate は `isSessionReady == true` の場合にのみ適用される

### session フィルタの絞り込みロジック（Swift 側クライアントフィルタ）

```
.all         → memos（全件、is_trashed=0）
.unsorted    → memos.filter { $0.sessionID == nil }
.session(id) → memos.filter { $0.sessionID == id }
```

- Trash タブでは `selectedFilter` を無視し、`trashedMemos` をそのまま使う
- 件数が増えた場合は Phase 6 で DB 側クエリに移行できる構造にしておく

### session 削除時の memo 扱い

```
1. memos の session_id = id → session_id = NULL（Unsorted に戻す）
2. sessions の id = id を DELETE
```

- `PersistenceCoordinator.deleteSession(id:)` 内でこの 2 ステップをトランザクション内で実行する
- cascade は使わない（SQLite の FK cascade は `PRAGMA foreign_keys = ON` 時のみ動作し、誤削除リスクがあるため）

### WindowManager との関係

- session は memo の「論理属性」であり、window の生成・表示には影響しない
- `WindowManager` は `session_id` を参照しない
- `openMemo(id:)` は session_id を知らずに動作する

## 修正フェーズ

### Phase 5-1: DB Schema + Session Model + K-03

目的:
- sessions テーブルと memos.session_id を安全に追加する
- Session struct / SessionFilter を定義する
- domain-model.md を現状の実装に同期させる（K-03）

対象ファイル: `SQLiteStore.swift`, `PersistenceModels.swift`, `PersistenceCoordinator.swift`, `docs/architecture/domain-model.md`

逸脱理由: domain-model.md 更新（K-03）はコード変更ゼロで影響範囲が文書のみ。DB schema 変更と同フェーズにまとめることで「DB 変更時に文書が古いまま」にならない。

Gate:
- 既存 DB がある状態で起動しても memo が失われない
- sessions テーブルが作成される
- memos.session_id 列が追加される（失敗しても起動できる）
- `PersistenceCoordinator.createSession(name:)` / `fetchAllSessions()` が呼べる
- domain-model.md が現状の実装を反映している

### Phase 5-2: Session CRUD（Persistence 層）

目的:
- session の作成・命名変更・削除を Persistence 層で完結させる

対象ファイル: `SessionStore.swift`（新規）, `PersistenceCoordinator.swift`

逸脱理由: `SessionStore.swift` 新規作成を伴うが、UI は一切触らない単一レイヤ変更。新規ファイル上限（原則 2）は 1 本で収まる。

Gate:
- `createSession`, `renameSession`, `deleteSession` が DB を正しく更新する
- `deleteSession` 実行後、属していた memo の `session_id` が NULL になる
- memo が消えない

### Phase 5-3: Session フィルタ UI（Home panel）

目的:
- Home panel に session フィルタドロップダウンを追加し、session を作成・命名変更・削除できるようにする（U-03, U-05）

対象ファイル: `HomeViewModel.swift`, `HomeView.swift`, `HomeWindowController.swift`, `AppDelegate.swift`

逸脱理由: U-03（CRUD UI）と U-05（フィルタ）は同一の session ドロップダウン UI コンポーネント上で実現される。分割すると「ドロップダウンは出るが操作できない」中間状態が生じ、テスト不能になる。1 UI コンポーネントに閉じた変更として扱い逸脱を許容する。

Gate（前提: `isSessionReady == true`）:
- toolbar に session フィルタ Picker と管理ボタン（⋯）が表示される
- 管理ボタンから管理シートを開き、session を作成できる
- 管理シート内で rename・delete ができる
- session を選択すると Memos タブの一覧が絞り込まれる
- "All" で全件表示に戻る
- "Unsorted" で session 未割り当て memo だけ表示される
- Trash タブでは Picker と管理ボタンが disabled になる
- `isSessionReady == false` 時は Picker と管理ボタンが disabled のまま（正常）
- 既存の Trash / Search 機能が regression しない

### Phase 5-4: Memo ↔ Session 割り当て（U-04）

目的:
- Home panel の memo 行から session への割り当てを変更できるようにする

対象ファイル: `HomeView.swift`, `HomeWindowController.swift`, `PersistenceCoordinator.swift`

Gate（前提: `isSessionReady == true`）:
- memo 行を右クリック → session 一覧が contextMenu で表示される
- session を選択すると memo.session_id が更新される
- "Unsorted" を選択すると session_id が NULL に戻る
- 割り当て変更後に一覧が再フェッチされ、フィルタ結果に反映される

## Gate 条件

- session が複雑化ではなく整理価値として機能する
- memo の作成フローが変わらない（新規 memo は常に Unsorted）
- Home panel の既存機能（Trash, Search）が regression しない

## コードレビュー Gate

- session 操作が `HomeWindowController → PersistenceCoordinator` に一本化されている
- `WindowManager` が session_id を参照していない
- session フィルタが Swift 側クライアントフィルタとして実装されている（Phase 5 の想定内）
- session 削除が 2 ステップ（memo を Unsorted に戻す → session 行削除）になっている
- Trash タブで session フィルタが無効化されている
- `isSessionReady` が `SQLiteStore` → `PersistenceCoordinator` → `HomeViewModel` → `HomeView` まで漏れなく伝播しており、どの UI 要素も `isSessionReady == false` 時に有効化されていないこと

## 回帰 / 副作用チェック

- 既存 memo の session_id が NULL のまま正常に表示される（Unsorted として扱われる）
- Home panel の Trash タブと Search が session フィルタと干渉しない
- memo window の動作（pin, close, reopen）が session の影響を受けない
- Reopen Last Closed が session_id を気にしない
- schema migration が失敗してもアプリが起動不能にならない（degraded 起動）
- session 削除で memo が消えない

## 実機確認項目

1. 既存 DB がある状態で起動し、memo が失われないこと
2. Home panel の toolbar に session ドロップダウンが表示されること
3. "New Session" で session を作成できること
4. session を選択すると Memos タブに対象 memo だけ表示されること
5. "All" で全件に戻ること
6. "Unsorted" で session 未割り当て memo だけ表示されること
7. 管理ボタン（⋯）から管理シートを開き、session を rename できること
8. 管理シートから session を delete でき、属していた memo が Unsorted に戻ること
9. Trash タブに切り替えると session ドロップダウンが無効化されること
10. memo 行の右クリックで session を割り当て・変更・解除できること
11. 新規 memo が常に Unsorted として作成されること
12. Trash / Search と session フィルタを組み合わせて正しく動作すること
13. app 再起動後も session と割り当てが保持されていること

## 変更履歴

- 2026-04-12: 初版作成
- 2026-04-12: レビュー指摘対応（SSOT 参照宣言補完、U-03 rename/delete の Gate 明記、rename/delete UI 導線を技術詳細に追加、フェーズを 4 分割し逸脱理由を明記、migration 失敗時の degraded 起動方針を追記、Trash タブと session フィルタの衝突を解消、K-03 の対応フェーズを 5-1 に明示）
- 2026-04-12: 二次レビュー指摘対応（Picker 内 contextMenu を廃止し管理ボタン＋シート方式に変更、isSessionReady フラグによる degraded/正常 の区別を明確化、Phase 5-3/5-4 の Gate に isSessionReady 前提を明記）
- 2026-04-12: 三次レビュー残留リスク対応（rename 確定条件と空文字破棄ルールを技術詳細に追記、isSessionReady 伝播漏れをコードレビュー Gate に追記）
