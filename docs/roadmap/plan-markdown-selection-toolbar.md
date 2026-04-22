# Markdown Selection Toolbar Plan

作成: 2026-04-22  
ステータス: 計画中（Markdown-lite Phase 1 Gate 通過後に再レビュー）  

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-22 | 初版作成。LINE 風 selection formatting toolbar を Markdown-lite 本体計画から分離 |

---

## SSOT参照宣言

本計画は以下を上位文書として扱う。

- `docs/roadmap/stickynative-ai-planning-guidelines.md`
- `docs/product/product-vision.md`
- `docs/product/ux-principles.md`
- `docs/product/mvp-scope.md`
- `docs/architecture/technical-decision.md`
- `docs/architecture/persistence-boundary.md`
- `docs/roadmap/roadmap.md`
- `docs/roadmap/plan-markdown-lite-editor.md`
- `docs/roadmap/plan-editor-command-expansion.md`
- `docs/product/current-feature-summary.md`

`docs/roadmap/stickynative-ai-planning-guidelines.md` では `/Users/hori/Desktop/Sticky/migration/*` を SSOT として参照するよう定義されているが、2026-04-22 時点の作業環境では `/Users/hori/Desktop/Sticky/migration` が存在しない。したがって、本計画では repo 内 docs と現行実装を暫定 SSOT とする。

---

## 背景

LINE の chat input のように、テキスト選択中だけ formatting toolbar を selection 近くに出し、太字 / 斜体 / 取り消し線 / テキスト強調 / 段落強調をアイコンで選べる UI は StickyNative にも応用できる。

ただし、selection toolbar は editor decoration とは別の高リスク UI / focus 変更である。`NSPopover` / `NSPanel` は first responder、selection、first mouse、IME marked text に影響し得るため、Markdown-lite 本体計画から分離し、feasibility probe と command 実行を別フェーズにする。

---

## 今回触る関連ファイル

| ファイル | 扱い |
|----------|------|
| `StickyNativeApp/CheckableTextView.swift` | Phase 1 主対象。selection rect 解決、toolbar 表示 / 非表示、focus / IME guard を probe |
| `StickyNativeApp/MarkdownFormattingToolbar.swift` | Phase 1 で分離が必要な場合のみ新規候補 |
| `StickyNativeApp/EditorCommand.swift` | Phase 2 以降。toolbar button 実行時の command metadata を追加 |
| `StickyNativeApp/EditorTextOperations.swift` | Phase 2 以降。Markdown marker wrap / unwrap を追加 |
| `StickyNativeApp/MemoEditorView.swift` | 確認のみ |
| `docs/roadmap/plan-markdown-selection-toolbar.md` | 本計画書 |

---

## 対象外

- Markdown-lite Phase 1 の `☑` 行 decoration 実装
- rich text / attributed string 永続化
- 常設 formatting toolbar
- preview pane
- marker 非表示 WYSIWYG
- formatting shortcut の初期追加
- DB schema 変更
- window lifecycle / global shortcut / folder / trash の仕様変更

---

## 問題一覧

| ID | 分類 | 内容 |
|----|------|------|
| U-60 | UI | 選択範囲に対する formatting 操作が発見しづらい |
| U-61 | UI | 常設 toolbar は軽い editor 体験を重くする |
| A-60 | Architecture | toolbar state を SwiftUI app state に載せると selection / focus 更新と競合する |
| A-61 | Architecture | toolbar button が独自 text operation を持つと `EditorCommand` / `EditorTextOperations` と重複する |
| F-60 | Focus | `NSPopover` / `NSPanel` が first responder、first mouse、IME marked text を壊すリスクがある |
| K-60 | Knowledge | toolbar feasibility と command 実行の依存関係を分ける必要がある |

---

## Issue -> Phase 対応

| Issue | Phase | 対応内容 |
|-------|-------|----------|
| K-60 | Phase 0 | Markdown-lite Phase 1 Gate 通過後に再レビューする開始条件を固定 |
| U-61 | Phase 0 | 常設 toolbar / preview / rich text 保存を対象外にする |
| A-60 | Phase 1 | toolbar visibility / position / lifetime を AppKit transient state に閉じる |
| F-60 | Phase 1 | display-only toolbar probe で first responder / first mouse / IME を確認 |
| U-60 | Phase 1 | 選択中だけ toolbar が出るか probe する |
| A-61 | Phase 2 | 実行可能 button は `EditorCommand` / `EditorTextOperations` 経由に限定する |

---

## 技術方針

### 開始条件

本計画はすぐ実装しない。以下を満たした後に再レビューして着手する。

- `docs/roadmap/plan-markdown-lite-editor.md` Phase 1 が実装済み
- `☑` 行 decoration の実機 Gate が通過済み
- Smart Links / hover feedback / IME に回帰がない

### Toolbar Scope

Phase 1 では表示 probe のみ。

- selection がある時だけ toolbar を表示
- toolbar button は disabled または no-op
- `EditorCommand` / `EditorTextOperations` は変更しない
- positioning / dismissal / focus 影響だけを確認する

Phase 2 以降で実行可能 button を追加する。

候補:

| UI label | Icon | Markdown-lite operation |
|----------|------|-------------------------|
| 太字 | `B` | `**selection**` |
| 斜体 | `I` | `*selection*` |
| 取り消し線 | `S` | `~~selection~~` |
| テキストを強調 | highlighter icon | `==selection==` |
| 段落を強調 | quote / callout icon | selected lines に `> ` prefix |

「大文字」が inline large text を意味する場合、plain text Markdown-lite では扱いにくい。実装前に `bold` か `heading` かを固定する。

### 責務境界

`CheckableTextView.swift`:

- selection change detection
- selection rect から toolbar position を計算
- toolbar 表示 / 非表示 orchestration
- first responder / marked text guard

`MarkdownFormattingToolbar.swift`:

- Phase 1 で toolbar UI が肥大化する場合のみ新規作成
- icon-only button layout
- tooltip / accessibility label
- command 実行ロジックは持たない

`EditorCommand.swift`:

- Phase 2 以降で formatting command metadata を追加

`EditorTextOperations.swift`:

- Phase 2 以降で marker wrap / unwrap の pure text operation を追加

Persistence:

- 変更しない
- toolbar state は保存しない

### AppKit UI 候補

初期候補:

- `NSPopover`

理由:

- dismissal と positioning が比較的簡単
- display-only probe に向く

fallback:

- borderless `NSPanel`

切り替え条件:

- `NSPopover` が editor first responder を奪う
- first mouse / zero-click input を乱す
- selection が toolbar 表示で不自然に消える

### 表示条件

- `selectedRange.length > 0`
- `hasMarkedText() == false`
- editor が first responder または key window 内で selection を持つ
- selection drag 中は表示更新を遅延してよい

### 非表示条件

- selection が空になった
- IME marked text が始まった
- editor focus を失った
- scroll / resize / text container width 変更で selection rect が解決できない
- Escape または toolbar 外 click

### Positioning

- `layoutManager` から selection glyph range の bounding rect を取得する
- text container origin を足して view / window coordinates に変換する
- 原則 selection の上に出す
- 上に余白がない場合は下に出す
- 複数行 selection では first line rect または selection union rect を使う。初期 probe では first line rect を推奨する

---

## 修正フェーズ

### Phase 0: Scope And Preconditions

目的:

- toolbar 計画を Markdown-lite Phase 1 から分離し、開始条件を固定する。

対象ファイル:

- `docs/roadmap/plan-markdown-selection-toolbar.md`

Gate:

- Markdown-lite Phase 1 Gate 通過後に着手することが明記されている
- Phase 1 が display-only probe に限定されている
- command 実行は Phase 2 以降に分離されている

### Phase 1: Display-Only Toolbar Feasibility Probe

目的:

- selection 近くに toolbar を表示しても focus / selection / IME が壊れないか確認する。

対象ファイル:

- `StickyNativeApp/CheckableTextView.swift`
- `StickyNativeApp/MarkdownFormattingToolbar.swift`（必要な場合のみ）

実装内容:

- selection がある時だけ display-only toolbar を出す
- button は disabled または no-op
- `EditorCommand` / `EditorTextOperations` は変更しない
- `NSPopover` を初期候補にする
- `NSPopover` が focus を乱す場合だけ `NSPanel` へ切り替える

Gate:

- text selection 中だけ toolbar が出る
- selection が空になると toolbar が消える
- toolbar 表示後も editor が自然に first responder を維持する
- toolbar 表示後に selection / caret が破綻しない
- 日本語 IME marked text 中に toolbar が出ない
- first mouse / zero-click input が壊れない
- build が通る

### Phase 2: Formatting Command Integration

目的:

- toolbar button から Markdown marker wrap / unwrap を実行できるようにする。

対象ファイル:

- `StickyNativeApp/EditorCommand.swift`
- `StickyNativeApp/EditorTextOperations.swift`
- `StickyNativeApp/CheckableTextView.swift`
- `StickyNativeApp/MarkdownFormattingToolbar.swift`（存在する場合）

実装内容:

- `EditorCommand.toggleStrikethrough` など command metadata を追加
- `EditorTextOperations` に marker wrap / unwrap を追加
- toolbar button は `EditorCommand` 経由で command を実行
- toolbar 専用の text mutation は持たない
- 初期 shortcut は割り当てない

Gate:

- command metadata が `EditorCommand` に集約されている
- text operation が `EditorTextOperations` に分離されている
- IME marked text 中は command が発動しない
- undo / redo が自然に動く
- autosave は既存 `textDidChange` 経路に乗る

### Phase 3: Regression Gate

目的:

- editor の主操作を壊していないことを確認する。

Gate:

- global shortcut 後にゼロクリック入力できる
- 非アクティブ状態から 1 click で入力できる
- 日本語 IME の入力・変換・確定が正常
- checkbox toggle が正常
- Smart Links / hover が正常
- toolbar state が persistence に混ざらない

---

## Gate条件

- `xcodebuild -project StickyNative.xcodeproj -scheme StickyNative -configuration Debug build` が成功する
- `git diff --check` が成功する
- Phase 1 では `EditorCommand` / `EditorTextOperations` に変更がない
- Phase 1 では toolbar button は実行可能 command を持たない
- Phase 2 以降の button は `EditorCommand` 経由で `EditorTextOperations` を呼ぶ
- toolbar state は SwiftUI app state / persistence / SQLite に渡さない
- IME marked text 中は toolbar を表示せず command も実行しない

---

## 回帰/副作用チェック

| 確認項目 | 理由 |
|----------|------|
| first mouse | toolbar 表示が非アクティブ window からの 1 click 入力を邪魔しないことを確認 |
| global shortcut 後の入力 | focus token / first responder に副作用がないことを確認 |
| 日本語 IME | marked text 中に toolbar が出ないことを確認 |
| selection | toolbar 表示 / 非表示で selection が壊れないことを確認 |
| checkbox toggle | editor mouse / keyboard handling が維持されることを確認 |
| Smart Links | link hover / click / context menu が維持されることを確認 |
| autosave | toolbar state が保存文字列に混ざらないことを確認 |

---

## 実機確認項目

- [ ] selection 中だけ toolbar が出る
- [ ] selection が空になると toolbar が消える
- [ ] toolbar 外 click で toolbar が消える
- [ ] toolbar 表示後も editor focus が自然
- [ ] toolbar 表示後も selection / caret が自然
- [ ] 日本語 IME marked text 中に toolbar が出ない
- [ ] global shortcut 後にゼロクリック入力できる
- [ ] 非アクティブ状態から 1 click で入力できる
- [ ] checkbox toggle が正常
- [ ] Smart Links / hover が正常

---

## 技術詳細確認

- selection toolbar は Markdown-lite Phase 1 Gate 通過後に着手する。
- Phase 1 は display-only feasibility probe に限定する。
- Phase 1 では `EditorCommand` / `EditorTextOperations` を変更しない。
- Phase 2 以降の toolbar button は `EditorCommand` 経由で `EditorTextOperations` を呼ぶ。
- toolbar state は `NSTextView` 近傍の AppKit transient UI とし、SwiftUI app state には載せない。
- `NSPopover` を初期候補にし、focus / first mouse に問題が出る場合だけ borderless `NSPanel` へ切り替える。
- rich text 保存が必要になった場合は別計画で document model と migration を扱う。

---

## セルフチェック結果

### SSOT整合

[x] migration README は現環境に存在しないため unavailable として扱った
[x] repo 内 product / architecture / roadmap 文書を確認した
[x] Markdown-lite Phase 1 計画から toolbar を分離した

### 変更範囲

[x] Phase 1 の主目的は display-only toolbar feasibility probe のみ
[x] command 実行を Phase 2 へ分離した
[x] rich text 保存を対象外にした

### 技術詳細

[x] ファイルごとの責務が明確
[x] メモリ管理と persistence の境界が明確
[x] focus / first mouse / IME の Gate が明確

### Window / Focus

[x] Window 責務を変更しない
[x] Focus 制御リスクを Gate に入れた
[x] first mouse の確認項目を明記した

### Persistence

[x] 保存経路は変更しない
[x] toolbar state を保存しない
[x] relaunch 時に復元しない transient UI とした

### 実機確認

[x] global shortcut を確認する
[x] 1 click 操作を確認する
[x] ゼロクリック入力を確認する
