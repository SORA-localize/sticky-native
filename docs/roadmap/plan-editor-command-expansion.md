# Editor Command Expansion Plan

作成: 2026-04-19  
ステータス: 計画中（`CheckableTextView` 実機 Gate 通過後に着手）

---

## SSOT参照宣言

本計画は以下を上位文書として扱う。

### migration 上位文書

- `/Users/hori/Desktop/Sticky/migration/README.md`
- `/Users/hori/Desktop/Sticky/migration/01_product_decision.md`
- `/Users/hori/Desktop/Sticky/migration/02_ux_principles.md`
- `/Users/hori/Desktop/Sticky/migration/04_technical_decision.md`
- `/Users/hori/Desktop/Sticky/migration/06_roadmap.md`
- `/Users/hori/Desktop/Sticky/migration/07_project_bootstrap.md`
- `/Users/hori/Desktop/Sticky/migration/08_human_checklist.md`
- `/Users/hori/Desktop/Sticky/migration/09_seamless_ux_spec.md`

### StickyNative ローカル補助文書

- `docs/product/product-vision.md`
- `docs/product/ux-principles.md`
- `docs/product/mvp-scope.md`
- `docs/architecture/technical-decision.md`
- `docs/roadmap/roadmap.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`
- `docs/roadmap/plan-checkbox-feature.md`

---

## 背景

`CheckableTextView` により、memo editor は SwiftUI `TextEditor` から AppKit `NSTextView` ベースへ移行した。  
これにより、選択範囲、現在行、クリック位置、キー入力を editor 層で扱えるようになった。

ただし editor は StickyNative の中核であり、`first mouse`、global shortcut 後のゼロクリック入力、IME、autosave と密接に絡む。  
したがって、編集コマンドは一括投入せず、`CheckableTextView` の実機 Gate 通過後に 1 目的ずつ追加する。

---

## 今回触る関連ファイル

既存:

- `StickyNativeApp/CheckableTextView.swift`
- `StickyNativeApp/MemoEditorView.swift`
- `StickyNativeApp/ShortcutsWindowController.swift`

今回触らない:

- `StickyNativeApp/AppSettings.swift`
  - date / datetime format は本計画内で固定し、ユーザー設定は追加しない
- `docs/roadmap/roadmap.md`
  - Phase 7 を正式ロードマップへ昇格する判断までは、本計画書を詳細計画として扱う

新規:

- `StickyNativeApp/EditorCommand.swift`
  - editor command の enum / label / shortcut / context menu order を保持する
- `StickyNativeApp/EditorTextOperations.swift`
  - editor command の text operation を分離する

スキーマ変更:

- なし。すべて `draft` のプレーンテキスト変換として扱う。

---

## 問題一覧

| ID | 分類 | 内容 |
|---|---|---|
| F-01 | Focus | `CheckableTextView` 移行後の first mouse / ゼロクリック入力が実機 Gate 未通過 |
| K-01 | Knowledge | 追加 command と shortcut の表示 SSOT が未定義で、`CheckableTextView` / context menu / shortcut list が分岐するリスクがある |
| A-01 | Architecture | editor command が `CheckableTextView` 内に増え続けると NSTextView ラッパーが肥大化する |
| U-01 | UI | checkbox 以外の編集コマンドに発見可能な導線がない |
| U-02 | UI | 日付・時刻を軽く挿入する手段がない |
| U-03 | UI | 完了済み checkbox 行を整理する手段がない |
| U-04 | UI | 選択行を箇条書き化する軽量 command がない |
| P-01 | Persistence | editor command 実行後も autosave 経路が既存の `draft` 更新一本に保たれる必要がある |

---

## 技術詳細確認

### 責務境界

`CheckableTextView.swift`:

- `NSTextView` の生成、focus、first mouse、クリック位置、キーイベントを扱う
- 既存の `@Binding<String>` に text change を戻す
- `EditorCommand` を dispatch し、`EditorTextOperations` の結果を NSTextStorage に適用する
- command ごとの行変換ロジックは持たない

`EditorCommand.swift`:

- command の識別子、表示名、ショートカット、context menu 表示順を持つ
- NSTextView そのものの lifecycle は持たない
- Phase 7-1 で必ず新規作成する
- `CheckableTextView` / `ShortcutsWindowController` / context menu は `EditorCommand` の label / shortcut を参照する

抽出条件:

- Phase 7-1 の時点で `EditorCommand.swift` を追加し、checkbox command も含めて command metadata を移す
- 2 個目の command family（Phase 7-2 date / time）へ進む前に、command 表示 SSOT が `EditorCommand` に集約されていることを Gate とする
- Phase 7-1 の時点では既存 `toggleCheckbox` operation を一時的に `CheckableTextView` 内へ残してよい
- Phase 7-2 着手前に `EditorTextOperations.swift` を追加し、`toggleCheckbox`, `insertDate`, `insertDateTime` を移す
- Phase 7-2 以降、行単位変換や文字列挿入の本体を `CheckableTextView` に追加しない
- Phase 7-3 以降の `moveCompletedLinesDown`, `clearCompletedLines`, `toggleBulletList` は最初から `EditorTextOperations` に実装する
- `CheckableTextView` は selection / range 抽出、operation 呼び出し、NSTextStorage への適用だけを担当する

`EditorTextOperations.swift`:

- `String` / `NSString` / `NSRange` / command context を入力として、replacement string と replacement range を返す pure operation を持つ
- NSTextView lifecycle、focus、menu、keyboard event は持たない
- SQLite / PersistenceCoordinator には触れない
- Date / time operation は `Date` を引数で受け取り、内部で現在時刻を取得しない
- `Date.now` の取得は `CheckableTextView` 側の command dispatch または薄い adapter で行い、`EditorTextOperations` には渡された `Date` の formatting だけを置く

`ShortcutsWindowController.swift`:

- keyboard shortcut と user-facing command list の表示だけを扱う
- command 実行ロジックは持たない

Persistence:

- 変更なし
- editor command は `textView.didChangeText()` を通して `Coordinator.textDidChange` に戻り、既存 autosave debounce に乗る
- SQLite / Home / Trash / Session には直接触れない

### イベント経路

keyboard command:

```text
keyDown
  -> CheckboxNSTextView
  -> command dispatch
  -> NSTextStorage replace
  -> didChangeText
  -> Coordinator.textDidChange
  -> memo.draft
  -> AutosaveScheduler
  -> PersistenceCoordinator.saveDraft
```

context menu command:

```text
right click
  -> NSTextView menu
  -> command action
  -> NSTextStorage replace
  -> didChangeText
  -> 既存 autosave 経路
```

### 保存形式

- checkbox: `☐` / `☑`
- bullet list: `- `
- date: `YYYY-MM-DD`
- datetime: `YYYY-MM-DD HH:mm`
- completed task sort/delete: plain text 行単位変換

DB schema は変更しない。

日付・時刻の生成:

- `Calendar(identifier: .gregorian)` を使う
- `TimeZone.current` を使う
- `Locale(identifier: "en_US_POSIX")` を使い、数字・区切り文字を固定する
- 24 時間表記に固定する
- date format:
  - date: `yyyy-MM-dd`
  - datetime: `yyyy-MM-dd HH:mm`

---

## 修正フェーズ

### Phase 7-0: CheckableTextView Regression Gate

目的:

- editor 基盤移行後の high risk 項目を実機で確認し、追加 command の前提を固める。

対象ファイル:

- コード変更なし
- 実機確認結果は `docs/roadmap/plan-checkbox-feature.md` に追記する

Gate:

- global shortcut 後にゼロクリック入力できる
- 非アクティブ状態から 1 click で入力できる
- 日本語 IME の入力・変換・確定が正常
- `⌘L` が IME と致命的に競合しない
- close / reopen 後に checkbox text が復元される
- font size 設定が `CheckableTextView` に反映される

### Phase 7-1: Command Discovery Surface

目的:

- editor command を発見できる右クリックメニューを追加する。

対象ファイル:

- `CheckableTextView.swift`
- `ShortcutsWindowController.swift`
- `EditorCommand.swift`（新規）

実装内容:

- context menu に `Toggle Checkbox` を追加
- 既存 `⌘L` と同じ処理を呼ぶ
- `EditorCommand.swift` を追加し、command metadata の SSOT にする
- `toggleCheckbox` の表示名、shortcut、context menu 表示順を `EditorCommand` に移す
- 既存 `toggleCheckbox` text operation は Phase 7-1 では `CheckableTextView` 内に残してよい
- Phase 7-2 の前提として `EditorTextOperations.swift` へ移す

Gate:

- 右クリックメニューから checkbox toggle が実行できる
- 通常の macOS text context menu（Copy / Paste 等）を壊さない
- `⌘L` と右クリックが同じ結果になる
- `ShortcutsWindowController` の checkbox 表示が `EditorCommand` の metadata と一致している
- Phase 7-2 へ進む前に、追加 command の label / shortcut / context menu order を `EditorCommand` に集約済み
- Phase 7-2 へ進む前に、checkbox text operation を `EditorTextOperations` へ移す作業項目が残タスクとして明示されている

### Phase 7-2: Date / Time Insert

目的:

- 現在カーソル位置に日付または日時を挿入する。

対象ファイル:

- `CheckableTextView.swift`
- `ShortcutsWindowController.swift`
- `EditorCommand.swift`
- `EditorTextOperations.swift`（新規）

実装内容:

- `Insert Date`: `YYYY-MM-DD`
- `Insert Date Time`: `YYYY-MM-DD HH:mm`
- date / datetime は `Calendar(identifier: .gregorian)`, `TimeZone.current`, `Locale(identifier: "en_US_POSIX")` で生成する
- 表記は 24 時間制に固定する
- 採用 shortcut:
  - `⌘D`: date
  - `⌘⇧D`: datetime
- shortcut conflict が実機確認で見つかった場合は、その command の shortcut を割り当てず context menu のみにする
- context menu からも実行可能にする
- Phase 7-2 着手時に `toggleCheckbox`, `insertDate`, `insertDateTime` を `EditorTextOperations` に集約する

Gate:

- `EditorTextOperations.swift` が追加され、`CheckableTextView` から checkbox / date / datetime の text operation 本体が分離されている
- カーソル位置に挿入される
- 選択範囲がある場合は選択範囲を置換する
- autosave に乗る
- 日本語 IME 変換中に誤挿入しない
- `⌘D` / `⌘⇧D` が既存 app shortcut と競合しない。競合する場合は shortcut を外し、context menu のみで提供する

### Phase 7-3: Move Completed Lines Down

目的:

- `☑` で始まる完了行を現在のメモ末尾へ移動し、TODO リストを整理しやすくする。

対象ファイル:

- `CheckableTextView.swift`
- `ShortcutsWindowController.swift`
- `EditorCommand.swift`
- `EditorTextOperations.swift`

実装内容:

- 対象は本文全体
- `☑` 行を順序維持で末尾へ移動
- 未完了ブロックと完了ブロックの間には空行を 1 行だけ入れる
- 既存の末尾空行は正規化し、連続空行を増やさない
- 対象行は indentation 後に `☑` または `☑ ` で始まる行のみとする
- 削除ではなく移動に留める

Gate:

- 未完了行の順序が維持される
- 完了行の順序が維持される
- 未完了ブロックと完了ブロックの間に空行が 1 行だけ入る
- checkbox 以外の行が消えない
- undo 1 回で戻せる

### Phase 7-4: Clear Completed Lines

目的:

- `☑` 行を明示操作で削除する。

対象ファイル:

- `CheckableTextView.swift`
- `ShortcutsWindowController.swift`
- `EditorCommand.swift`
- `EditorTextOperations.swift`

実装内容:

- context menu に `Clear Completed` を追加
- ショートカットは初期実装では割り当てない
- 初期実装は confirmation なしとする
- 誤操作対策は「context menu 限定」「ショートカットなし」「undo 1 回で復元可能」の 3 点で担保する
- confirmation dialog は入れない。理由: editor command は軽量操作として扱い、macOS text editing の undo 前提に揃えるため

Gate:

- `☑` 行だけ削除される
- `☐` 行や通常行は残る
- undo 1 回で戻せる
- keyboard shortcut が割り当てられていない
- 空メモ自動削除と衝突しない

### Phase 7-5: Toggle Bullet List

目的:

- 現在行または選択行を `- ` 箇条書きに切り替える。

対象ファイル:

- `CheckableTextView.swift`
- `ShortcutsWindowController.swift`
- `EditorCommand.swift`
- `EditorTextOperations.swift`

実装内容:

- 通常行 -> `- ` 行
- `- ` 行 -> 通常行
- 複数行選択に対応
- checkbox 行（indentation 後に `☐` / `☑` で始まる行）は対象外とし、変換しない
- 空行は対象外とし、`- ` を付けない

Gate:

- 単一行 / 複数行で正しく動く
- indentation を維持する
- checkbox 行を壊さない
- 空行に bullet marker を追加しない

---

## Gate条件

- 各 phase の主目的が 1 つに収まっている
- `CheckableTextView` の focus / first mouse regression がない
- editor command 実行後の保存経路が `memo.draft -> AutosaveScheduler` のまま
- SQLite schema 変更がない
- Home / Trash / Session の管理 UI と衝突しない
- command list に追加済み shortcut が反映されている
- command label / shortcut / context menu order の SSOT が `EditorCommand` に集約されている
- Phase 7-2 完了時点で、command の text operation 本体が `EditorTextOperations` に集約されている

---

## 回帰 / 副作用チェック

| 確認項目 | 懸念 | 対策 |
|---|---|---|
| first mouse | `NSTextView` menu / keyDown 拡張で 1 click 入力が壊れる | Phase 7-0 と各 phase 後に実機確認 |
| IME | `keyDown` hook が変換中の入力に干渉する | command key のみ処理し、通常入力は super へ渡す |
| Undo | 複数行変換が細かい undo になる | `shouldChangeText` / `didChangeText` 経路を維持し、1 回の undo で戻らない場合は同 phase 内で undo grouping を追加する |
| Autosave | textStorage 直接変更が binding に戻らない | `didChangeText` を必ず呼ぶ |
| Context menu | Copy / Paste 等の標準 menu を消す | 標準 menu に項目追加する方式を優先 |
| Scope creep | editor command が増えすぎる | Phase ごとに 1 command family まで |
| Wrapper bloat | `CheckableTextView` が text operation を抱え続ける | Phase 7-2 着手前に `EditorTextOperations` へ抽出し、以後の operation はそこに追加する |

---

## 実機確認項目

- [ ] global shortcut 後にゼロクリック入力できる
- [ ] 非アクティブ状態から 1 click で入力できる
- [ ] 日本語 IME 入力・変換・確定が正常
- [ ] checkbox toggle が `⌘L` と右クリックの両方で動く
- [ ] 日付挿入がカーソル位置 / 選択範囲置換で動く
- [ ] 完了行移動で本文が欠落しない
- [ ] 完了行削除後に undo できる
- [ ] bullet toggle が checkbox 行を壊さない
- [ ] close / reopen 後も本文が復元される
- [ ] Home 検索で command 後の本文が検索対象になる

---

## セルフチェック結果

### SSOT整合

[x] migration README を確認対象に含めた  
[x] 01_product_decision を確認対象に含めた  
[x] 02_ux_principles を確認対象に含めた  
[x] 06_roadmap を確認対象に含めた  
[x] 07_project_bootstrap を確認対象に含めた  
[x] 09_seamless_ux_spec を確認対象に含めた  
[x] `stickynative-ai-planning-guidelines.md` を確認した

### 変更範囲

[x] 親計画は editor command expansion とし、実装 phase は 1 目的ずつに分割した  
[x] high risk な `CheckableTextView` regression Gate を先頭に置いた  
[x] SQLite / Home / Trash / Session をスコープ外にした

### 技術詳細

[x] ファイルごとの責務を定義した  
[x] persistence の保存経路を既存 autosave 一本に固定した  
[x] keyboard / context menu のイベント経路を明記した
[x] metadata は `EditorCommand`、text operation は `EditorTextOperations` へ分離する閾値を明記した

### Window / Focus

[x] Window lifecycle は変更しない計画にした
[x] Focus の高リスク確認を Phase 7-0 Gate に置いた
[x] first mouse の実機確認を各 phase の前提にした

### Persistence

[x] 保存経路は `memo.draft -> AutosaveScheduler` に固定した
[x] SQLite schema 変更なしと明記した
[x] Home / Trash / Session に直接触れないと明記した

---

## 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-04-19 | 初版作成。`CheckableTextView` 導入後の editor command 拡張計画として、right click command surface / date insert / completed line organization / bullet toggle を phase 分割 |
| 2026-04-19 | レビュー指摘対応。K-01 を表示 SSOT 問題に更新、`EditorCommand.swift` 抽出を Phase 7-1 必須化、date/time の timezone/locale/calendar、完了行移動の空行仕様、Clear Completed の確認 UX、bullet 対象外ルール、セルフチェックを明文化 |
| 2026-04-19 | 二次レビュー指摘対応。`AppSettings` をスコープ外に固定、`EditorTextOperations.swift` 抽出閾値を追加、date/time shortcut を採用値として明記し競合時の fallback を定義 |
