# Home Management Apple Notes UI Plan

作成: 2026-04-21  
ステータス: 計画中（実装未着手）

---

## SSOT参照宣言

本計画は以下を上位文書として扱う。

### StickyNative ローカル補助文書

- `docs/product/product-vision.md`
- `docs/product/ux-principles.md`
- `docs/product/mvp-scope.md`
- `docs/architecture/domain-model.md`
- `docs/architecture/technical-decision.md`
- `docs/roadmap/roadmap.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`
- `docs/roadmap/phase-4-management-surface-plan.md`
- `docs/roadmap/plan-home-memo-preview-source.md`

### Apple 参照

- Apple Human Interface Guidelines: Sidebars
  - sidebar は app の情報階層や peer area を横断する navigation に向く
  - macOS sidebar は system accent color や sidebar row sizing に寄せ、固定色で過剰に装飾しない
  - 階層が深い場合は disclosure control を使い、原則2階層以内に収める
- Apple Notes User Guide: pinned notes / folders / smart folders
  - Notes は sidebar で folders / smart folders を扱い、important notes を pin して list 上部に置ける
  - Smart Folder は実体を移動せず、条件に合う note への参照として扱う

### migration 上位文書の確認結果

`docs/roadmap/stickynative-ai-planning-guidelines.md` では `/Users/hori/Desktop/Sticky/migration/*` を SSOT として参照するよう定義されているが、2026-04-21 時点の作業環境では `/Users/hori/Desktop/Sticky` が存在しない。

本計画は Home 管理画面の navigation / list UI / list pin persistence を変更するため、Phase 6G-2 の schema 変更実装へ進む前に以下のどちらかを必須 Gate とする。

- `/Users/hori/Desktop/Sticky/migration/*` を復旧し、planning guide の migration SSOT と再照合する
- migration SSOT 未確認のまま進める例外理由を本計画書へ追記し、影響範囲が Home 管理画面と `is_list_pinned` 追加に限定されることを明文化する

---

## 背景

現在の Home 管理画面は、上部 toolbar の segmented picker、session menu、search、plain list で構成されている。memo が増えると、日付・session・重要 memo の見通しが弱くなり、Apple Notes のような sidebar + note list の情報設計に寄せた方が探しやすい。

ただし StickyNative の中心体験は `1 memo = 1 window` であり、管理画面は「読む・探す・開く・整理する」ための surface に留める。Apple Notes の detail editor まで取り込むと memo window の責務と衝突するため、本計画では右側 editor / preview pane は作らない。

また、既存の `is_pinned` は memo window の floating / always-on-top pin として使われている。管理画面 list pin は意味が異なるため、既存 `is_pinned` を流用しない。

---

## 今回触る関連ファイル

既存:

- `StickyNativeApp/HomeView.swift`
  - toolbar 中心の構成から sidebar + grouped memo list へ変更する
  - row style、pin action、scope selection、group section を持つ
- `StickyNativeApp/HomeViewModel.swift`
  - sidebar scope、date grouping、search filtering、list pin 更新後 reload を担当する
- `StickyNativeApp/PersistenceModels.swift`
  - `PersistedMemo` に list pin 用 field を追加する
- `StickyNativeApp/PersistenceCoordinator.swift`
  - list pin update API を追加する
- `StickyNativeApp/SQLiteStore.swift`
  - `is_list_pinned` column migration、select、row mapping、update API を追加する
- `StickyNativeApp/HomeWindowController.swift`
  - 必要なら Home window の初期サイズ / min size を sidebar 前提に調整する

確認のみ:

- `StickyNativeApp/SessionStore.swift`
  - session CRUD は既存のまま使う
- `StickyNativeApp/AppDelegate.swift`
  - Home window 起動導線が維持されることを確認する
- `StickyNativeApp/WindowManager.swift`
  - row open / trash / restore 経路が既存責務から逸脱しないことを確認する

触らない:

- `StickyNativeApp/MemoWindowController.swift`
- `StickyNativeApp/MemoWindowView.swift`
- `StickyNativeApp/SeamlessWindow.swift`
- `StickyNativeApp/CheckableTextView.swift`
- editor command / shortcut
- memo window resize / focus / first mouse

明示的にスコープ外:

- `Cmd+D` / `Cmd+Shift+D` の割り当て
- tag / smart folder の本実装
- Home 内 detail editor
- multi-select bulk actions
- session の階層化

---

## 問題一覧

| ID | 分類 | 内容 |
|---|---|---|
| U-01 | UI | Home 管理画面が toolbar + flat list 中心で、memo が増えた時に日付・session・trash・重要 memo の見通しが弱い |
| U-02 | UI | Apple Notes 的な sidebar navigation がなく、整理 surface としての情報階層が弱い |
| U-03 | UI | memo list row に list pin の affordance がなく、重要 memo を上部固定できない |
| U-04 | UI | date grouping がなく、最近触った memo と古い memo の境界が見えにくい |
| A-01 | Architecture | `is_pinned` を list pin に流用すると window floating pin と意味が衝突する |
| A-02 | Architecture | HomeView に filter / grouping / sort ロジックを直書きすると UI 変更時に分岐が増える |
| P-01 | Persistence | list pin は relaunch 後も残る必要があるが、現行 schema に専用 field がない |
| P-02 | Persistence | `is_list_pinned` migration 失敗時の fail-fast / degraded 方針を固定しないと fetch 全体が壊れる可能性がある |
| K-01 | Knowledge | migration SSOT が現環境で unavailable であり、schema 変更へ進む条件が未定義 |

---

## 目標仕様

Home 管理画面を Apple Notes に寄せた「sidebar + grouped memo list」にする。

### Sidebar

上部 group:

- `All Memos`
- `Pinned`
- `Today`
- `Last 7 Days`
- `Unsorted`
- `Trash`

Session group:

- 既存 `sessions` を sidebar の2階層目として表示する
- session が空の場合は group を出さない、または disabled empty state にする
- session の作成・rename・delete は既存 `SessionManagerView` を維持し、sidebar の詳細編集にはしない

将来候補:

- `Smart Folders`
- `Tags`
- custom date ranges

### Main List

選択中 sidebar scope に応じて memo list を表示する。

- `All Memos`: pinned section + date sections
- `Pinned`: list pinned memo のみを date sections で表示
- `Today`: updatedAt が今日の memo
- `Last 7 Days`: updatedAt が直近7日以内の memo
- `Unsorted`: `sessionID == nil`
- `Trash`: trashed memo のみ。list pin affordance は非表示
- `Session`: 該当 session の memo。pinned section + date sections

Date sections:

- `Pinned`（All / Session / Today / Last 7 Days / Unsorted の先頭。該当 scope に含まれる pinned memo のみ）
- `Today`
- `Yesterday`
- `Previous 7 Days`
- `Previous 30 Days`
- `Earlier`

重複回避:

- `Pinned` section に出した memo は、同じ list 内の date section には重複表示しない
- `Pinned` scope では `Pinned` section 名を重ねず、date sections のみで表示する

Search:

- search query は選択中 scope の中で絞り込む
- search 中も list pin 状態は表示するが、`Pinned` section で分離せず `Search Results` の単一 section にする
- 検索対象は現状どおり `memo.title` と `memo.draft`

### List Pin

list pin は管理画面内の重要 memo 固定であり、window floating pin とは別概念。

- 新規 DB column: `is_list_pinned INTEGER NOT NULL DEFAULT 0`
- `PersistedMemo.isListPinned: Bool` を追加する
- 既存 `PersistedMemo.isPinned` / SQLite `is_pinned` は window pin のまま維持する
- list pin toggle は Home list row / context menu から操作する
- list pin しても memo window の floating level は変わらない
- memo window で window pin しても Home list pin は変わらない
- trash へ移動しても `is_list_pinned` は保持するが、Trash view では pin affordance を出さない
- restore 後は trash 前の list pin 状態に戻る
- list pin / unpin は `updated_at` を変更しない
  - list pin は content update ではなく管理上の固定操作である
  - `updatedAt` grouping が pin 操作だけで `Today` や section 上部へ移動しないようにする
- pinned section 内の相対順も `updatedAt DESC` とし、pin した瞬間に pinned group の先頭へは上げない
  - pin 操作順を表す `list_pinned_at` は今回追加しない
  - 「pin した順」や「pin した直後に先頭」へ変える場合は、別計画で `list_pinned_at` を追加する

---

## 技術詳細確認

### 型と責務

`HomeViewModel.swift`:

```swift
enum HomeScope: Hashable {
  case all
  case pinned
  case today
  case last7Days
  case unsorted
  case trash
  case session(UUID)
}

struct MemoListSection: Identifiable {
  let id: String
  let title: String
  let memos: [PersistedMemo]
}
```

責務:

- `@Published var selectedScope: HomeScope = .all`
- `@Published var searchQuery: String = ""`
- `reload()` で memos / trashedMemos / sessions を取得する
- `sections(for:) -> [MemoListSection]` 相当で scope + search + grouping を作る
- `toggleListPinned(id:)` または `setListPinned(id:isPinned:)` を coordinator に委譲し、reload する

`HomeView.swift`:

- `NavigationSplitView` または `HStack` + sidebar `List` を使う
- sidebar selection と main list rendering を持つ
- filter / sort / grouping の判断は `HomeViewModel` に寄せる
- row は title、preview、updated date、session label、list pin icon を表示する

採用優先:

- macOS 14 以上なので `NavigationSplitView` を第一候補にする
- SwiftUI sidebar selection が Home window のサイズや List row hover と衝突する場合は、AppKit window は維持したまま `HStack` + `.listStyle(.sidebar)` 相当へ fallback する

`SQLiteStore.swift`:

- `createSchema()` の `memos` table に `is_list_pinned` default 0 を追加する
- `migrate()` で既存 DB に `ALTER TABLE memos ADD COLUMN is_list_pinned INTEGER NOT NULL DEFAULT 0;` を追加する
- `selectColumns` に `is_list_pinned` を追加する
- `memoRow(from:)` で `isListPinned` を map する
- `updateListPinned(id:isPinned:)` を追加する
- `updateListPinned(id:isPinned:)` は `updated_at` を更新しない

### List pin migration policy

`is_list_pinned` migration は fail-fast とする。

理由:

- `PersistedMemo.isListPinned` は non-optional として扱う
- Home list grouping / Pinned scope は `isListPinned` を常時参照する
- session migration のように `isSessionReady` で UI を degraded disable にすると、`selectColumns` / `memoRow` / Home UI の分岐が広がり、今回の管理画面 UI 改善から逸脱する

実装方針:

- `createSchema()` には `is_list_pinned INTEGER NOT NULL DEFAULT 0` を含める
- `migrate()` は `is_list_pinned` 追加に失敗した場合、error を握りつぶさず throw する
- `SQLiteStore.init()` は `is_list_pinned` migration failure を起動失敗として扱う
- `selectColumns` は常に `is_list_pinned` を含める
- `memoRow(from:)` は常に `isListPinned` を non-optional bool として map する
- `HomeView` は `isListPinReady` のような degraded flag を持たない
- session_id migration の degraded 起動方針は既存維持し、list pin migration には適用しない

`PersistenceCoordinator.swift`:

- `saveListPinned(id:isPinned:)` を追加する

`PersistenceModels.swift`:

- `PersistedMemo` に `let isListPinned: Bool` を追加する

### Date grouping source of truth

- grouping は `updatedAt` を基準にする
- `createdAt` は表示・grouping の source にはしない
- Calendar は `Calendar.current` を使い、local timezone の「今日」「昨日」を判定する
- `Last 7 Days` は今日を含む直近7日以内とし、Trash は対象外

### Sort order

- pinned section 内: `updatedAt DESC`
- date section 内: `updatedAt DESC`
- sidebar session order: 既存どおり `createdAt ASC`
- Trash: `updatedAt DESC`
- pin 操作は sort key を変えないため、pin / unpin 後も同一 section 内の相対順は `updatedAt DESC` のまま維持する

### Home state lifecycle

`HomeWindowController` は現在 `HomeViewModel` を保持して再利用する。新しい sidebar UI でもこの方針を維持する。

- `selectedScope` は Home window を閉じて再表示しても保持する
  - 管理作業中に window を一時的に閉じても同じ場所へ戻れるため
- `searchQuery` は `HomeWindowController.show()` ごとに `""` へ戻す
  - 前回の検索が残って「memo が消えた」ように見える状態を避けるため
- session delete 時に削除対象 session を選択中なら `selectedScope = .all` へ戻す
- trash empty 後に `Trash` scope を選択中なら scope は維持し、empty state を表示する

### Event paths

Open:

```text
HomeView row click
  -> HomeWindowController.onOpenMemo
  -> WindowManager.openMemo(id:)
```

Trash:

```text
HomeView row trash action
  -> HomeWindowController.onTrashMemo
  -> WindowManager.trashMemo(id:)
  -> viewModel.reload()
```

Restore:

```text
HomeView row restore action
  -> HomeWindowController.onRestoreMemo
  -> PersistenceCoordinator.restoreMemo(id:)
  -> viewModel.reload()
```

List pin:

```text
HomeView row pin action / context menu
  -> HomeViewModel.setListPinned(id:isPinned:)
  -> PersistenceCoordinator.saveListPinned(id:isPinned:)
  -> SQLiteStore.updateListPinned(id:isPinned:)
  -> viewModel.reload()
```

Session assign:

```text
HomeView row context menu
  -> HomeWindowController.onAssignSession
  -> PersistenceCoordinator.assignSession(memoID:sessionID:)
  -> viewModel.reload()
```

Window pin:

```text
MemoWindowView pin button
  -> MemoWindowController.pinWindow
  -> PersistenceCoordinator.savePinned
  -> SQLiteStore.updatePinned
```

Window pin と list pin は別経路のまま維持する。

---

## 修正フェーズ

### Phase 6G-0: UI Skeleton Probe

目的:

- Home window に sidebar + main list の2カラム構成を置けるかだけを確認する。
- 本 phase では schema 変更をしない。
- 本 phase では既存 toolbar / filter UI を恒久置換しない。

対象ファイル:

- `StickyNativeApp/HomeView.swift`
- 必要なら `StickyNativeApp/HomeWindowController.swift`

実装内容:

- static sidebar mock を HomeView 内に置く、または local-only `enum ProbeScope` を使う
- `All / Today / Last 7 Days / Unsorted / Trash / Sessions` 相当の見た目だけを表示する
- main pane は既存 `displayedMemos` の flat list を流用するか、少数の既存 row を表示する
- row click / trash / restore / session assign の本実装経路を変更しない
- `HomeScope` / `MemoListSection` / persistence API は導入しない

Gate:

- Home window が開く
- sidebar + main list の幅、min size、resize が破綻しない
- `NavigationSplitView` が Home window で不自然なら `HStack` + sidebar `List` fallback を採用判断できる
- memo window focus / resize / first mouse に触れていない
- probe 結果を本計画または別 result 文書へ追記する
- probe 差分を本実装へ昇格する前に不要な仮コードを除去する
- 失敗時は Phase 6G-0 の差分を残さず、既存 toolbar UI に戻して Phase 6G-1 へ進まない

昇格条件:

- sidebar width と main list width が 480x580 の現行 Home window で破綻しない
- min window size を上げる必要がある場合、HomeWindowController の責務として明記できる
- keyboard focus / row click / scroll が現行 List と同等に扱える
- `NavigationSplitView` と fallback のどちらを採用するかを Phase 6G-1 前に文書へ追記する

### Phase 6G-1: Grouped List Rendering

目的:

- sidebar selection、scope 別 filter、date grouping を ViewModel に集約する。

対象ファイル:

- `StickyNativeApp/HomeView.swift`
- `StickyNativeApp/HomeViewModel.swift`
- 必要なら `StickyNativeApp/HomeWindowController.swift`

実装内容:

- `HomeScope` を導入する
- `MemoListSection` を導入する
- current `showTrash` / `selectedFilter` UI を sidebar selection に置き換える
- `All / Today / Last 7 Days / Unsorted / Trash / Sessions` を sidebar に表示する
- `updatedAt` 基準の date section を作る
- search 中は `Search Results` 単一 section にする
- `HomeWindowController.show()` で `viewModel.searchQuery = ""` を呼ぶ
- row style を Apple Notes 風に調整する
  - no card
  - stable row height
  - title + preview + relative/short date
  - selected / hover state
  - session label は短く控えめに表示

Gate:

- `All` で date grouping される
- `Today / Last 7 Days / Unsorted / Session` の filter が正しい
- search は選択中 scope 内だけで絞り込む
- Home window close / reopen 後に selected scope は保持され、search query は空に戻る
- 既存 preview source は `MemoTitleFormatter.previewText(from:)` のまま維持する
- text が row 内で見切れず、1行 truncation が安定する

### Phase 6G-2: List Pin Persistence

目的:

- list pin を window pin と別概念として永続化する。

対象ファイル:

- `StickyNativeApp/SQLiteStore.swift`
- `StickyNativeApp/PersistenceModels.swift`
- `StickyNativeApp/PersistenceCoordinator.swift`
- `StickyNativeApp/HomeViewModel.swift`
- `StickyNativeApp/HomeView.swift`

実装内容:

- `is_list_pinned` column を migration で追加する
- `is_list_pinned` migration は fail-fast とし、失敗時は起動を止める
- `PersistedMemo.isListPinned` を追加する
- `saveListPinned` / `updateListPinned` を追加する
- `updateListPinned` は `updated_at` を更新しない
- Home row に list pin toggle を追加する
- context menu に `Pin in List` / `Unpin from List` を追加する
- `Pinned` scope と `Pinned` section を有効化する

Gate:

- list pin しても window floating pin は変わらない
- window pin しても list pin は変わらない
- list pin / unpin しても `updatedAt` は変わらない
- list pin / unpin だけで date section は移動しない
- pinned section 内でも pin 操作直後に先頭へ移動せず、`updatedAt DESC` の相対順を維持する
- relaunch 後も list pin が残る
- `All / Session / Today / Last 7 Days / Unsorted` で pinned memo が上部に出る
- pinned section と date section で同じ memo が重複しない
- Trash view では pin affordance が出ない
- restore 後に list pin 状態が戻る
- migration 失敗を模擬しても既存 memo rows が失われない
- migration 失敗後の partial schema 状態では Home fetch を実行しない
- migration 失敗後に schema が未完了のままなら、次回起動で `is_list_pinned` migration を再試行できる

### Phase 6G-3: Sidebar Polish and Session Ergonomics

目的:

- sidebar を管理画面として使いやすい見た目と操作に整える。

対象ファイル:

- `StickyNativeApp/HomeView.swift`
- `StickyNativeApp/HomeViewModel.swift`
- 必要なら `StickyNativeApp/HomeWindowController.swift`

実装内容:

- sidebar width / Home window min size を調整する
- session group の disclosure を追加する
- session manager 起動ボタンを sidebar header 付近に移す
- empty state を scope ごとに整理する
- row context menu の order を整理する

Gate:

- sidebar が狭くても label が破綻しない
- session が多い場合に list area が過度に狭くならない
- Home window close / reopen 後も selected scope が不自然に壊れない
- Empty / Trash / Session empty state が正しい

---

## Issue → Phase 対応

| Issue | 対応 Phase | 解決 / 確認内容 |
|---|---|---|
| U-01 | Phase 6G-0, 6G-1 | flat list から sidebar + grouped list へ移行する |
| U-02 | Phase 6G-0, 6G-3 | sidebar navigation と session group を導入する |
| U-03 | Phase 6G-2 | list pin toggle と Pinned scope / section を導入する |
| U-04 | Phase 6G-1 | updatedAt 基準の date grouping を導入する |
| A-01 | Phase 6G-2 | `is_pinned` ではなく `is_list_pinned` を追加する |
| A-02 | Phase 6G-1 | filtering / grouping を HomeViewModel に集約する |
| P-01 | Phase 6G-2 | list pin を SQLite に永続化する |
| P-02 | Phase 6G-2 | `is_list_pinned` migration は fail-fast、`selectColumns` は常時 list pin 列ありとして固定する |
| K-01 | Phase 6G-2 Gate | migration SSOT 復旧または例外理由追記を必須化する |

---

## Gate条件

- 主目的は Home 管理画面の Apple Notes 風 information architecture への改善 1 つ
- `Cmd+D` / shortcut 変更を含めない
- memo window の window lifecycle / focus / resize に触れない
- Home 内に editor/detail pane を作らない
- `1 memo = 1 window` を維持する
- list pin と window pin の persistence / UI / event path が分離されている
- list pin / unpin は `updated_at` を変更しない
- `is_list_pinned` schema 変更前に migration SSOT 復旧または例外理由を文書化する
- `is_list_pinned` migration 失敗時は fail-fast とし、degraded UI 分岐を作らない
- `xcodebuild -project StickyNative.xcodeproj -scheme StickyNative -configuration Debug build` が通る

---

## 回帰 / 副作用チェック

- Home window が menu bar から開く
- Home window を閉じて再度開いても crash しない
- global shortcut で新規 memo を作れる
- memo window の pin / close / trash が既存どおり動く
- Home row click で open 中 memo は focus、closed memo は reopen する
- trash / restore / empty trash が既存どおり動く
- session create / rename / delete / assign が既存どおり動く
- search が title / draft 対象のまま動く
- list pin migration 後も既存 DB の memo が失われない
- `is_list_pinned` migration 失敗時は起動失敗として扱い、partial schema のまま Home を表示しない
- migration 失敗を模擬しても既存 memo rows が保持される
- migration 失敗後に再起動すると、未完了 schema に対して migration を再試行できる

---

## 実機確認項目

### Sidebar

- `All Memos`, `Pinned`, `Today`, `Last 7 Days`, `Unsorted`, `Trash` を切り替える
- session を選ぶと、その session の memo だけが表示される
- session がない状態で sidebar が破綻しない
- Home window を狭めた時に sidebar / list が破綻しない

### Grouped List

- 今日更新した memo が `Today` に出る
- 昨日以前の memo が適切な section に出る
- search 中は選択中 scope 内だけが対象になる
- title / preview / date / session label が重ならない

### List Pin

- Home row から list pin / unpin できる
- list pin / unpin しても updated date 表示と date section が変わらない
- pinned memo が `All` の上部に出る
- pinned memo が `Pinned` scope に出る
- relaunch 後も pinned 状態が残る
- window pin と list pin が互いに影響しない
- trash 中は pin affordance が出ない
- restore 後に list pin 状態が戻る

### Existing Lifecycle

- row click で memo window が開く
- open 中 memo の row click は既存 window を focus する
- trash / restore / empty trash が動く
- global shortcut 後のゼロクリック入力が壊れていない

---

## セルフチェック結果

### SSOT整合

- [x] `docs/product/product-vision.md` を確認した
- [x] `docs/product/ux-principles.md` を確認した
- [x] `docs/architecture/domain-model.md` を確認した
- [x] `docs/architecture/technical-decision.md` を確認した
- [x] `docs/roadmap/stickynative-ai-planning-guidelines.md` を確認した
- [x] `docs/roadmap/phase-4-management-surface-plan.md` を確認した
- [ ] migration README を確認した（現環境で unavailable）
- [ ] migration 01/02/06/07/09 を確認した（現環境で unavailable）

### 変更範囲

- [x] 主目的は1つ
- [x] shortcut 変更を含めていない
- [x] memo window resize / focus を含めていない
- [x] Home detail editor を含めていない

### 技術詳細

- [x] ファイルごとの責務が明確
- [x] list pin と window pin の境界が明確
- [x] grouping / filtering の source of truth が明確
- [x] event path が説明できる

### Persistence

- [x] schema 変更対象が `is_list_pinned` に限定されている
- [x] 既存 `is_pinned` を流用しない
- [x] migration SSOT unavailable の Gate がある

---

## 変更履歴

- 2026-04-21: 初版作成
