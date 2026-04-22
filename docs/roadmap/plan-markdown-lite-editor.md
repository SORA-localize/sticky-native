# Markdown Lite Editor Plan

作成: 2026-04-22  
ステータス: 計画中（Phase 1 実装対象を `☑` 行 decoration に固定）

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-22 | 初版作成。plain text 保存を維持した Markdown-lite 対応を計画化 |
| 2026-04-22 | Phase 1 の `☑` 行取り消し線 decoration に実装対象を限定。selection toolbar / formatting commands は別計画へ分離 |

---

## SSOT参照宣言

本計画は以下を上位文書として扱う。

### StickyNative ローカル補助文書

- `docs/roadmap/stickynative-ai-planning-guidelines.md`
- `docs/product/product-vision.md`
- `docs/product/ux-principles.md`
- `docs/product/mvp-scope.md`
- `docs/architecture/technical-decision.md`
- `docs/architecture/persistence-boundary.md`
- `docs/roadmap/roadmap.md`
- `docs/roadmap/plan-checkbox-feature.md`
- `docs/roadmap/plan-editor-command-expansion.md`
- `docs/roadmap/plan-smart-links.md`
- `docs/roadmap/plan-smart-link-hover-feedback.md`
- `docs/product/current-feature-summary.md`

### migration 上位文書の確認結果

`docs/roadmap/stickynative-ai-planning-guidelines.md` では `/Users/hori/Desktop/Sticky/migration/*` を SSOT として参照するよう定義されているが、2026-04-22 時点の作業環境では `/Users/hori/Desktop/Sticky/migration` が存在しない。

したがって、本計画では repo 内の `docs/product/*`、`docs/architecture/*`、`docs/roadmap/*` と現行実装を暫定 SSOT とする。migration 文書が復旧した場合は、実装前または次回計画更新時に再照合する。

### SSOT整合メモ

- `ux-principles.md`: 「速い」「自然」「軽い」を優先する。Markdown-lite は整理 mode や常設 toolbar を増やさず、既存 editor 上の表示 polish に留める。
- `technical-decision.md`: editor surface は SwiftUI、text editing は AppKit `NSTextView`。Markdown decoration は AppKit 側に置く。
- `persistence-boundary.md`: draft は plain text として保存する。DB schema は変更しない。
- `plan-checkbox-feature.md`: 既存 checkbox は `☐` / `☑` plain text。本計画は `☑` 行を視覚的に completed と見せるだけで、保存形式は変えない。
- `plan-smart-links.md` / `plan-smart-link-hover-feedback.md`: Smart Links は `.underlineStyle` / `.foregroundColor` の temporary attributes を使う。本計画の Phase 1 は `.strikethroughStyle` のみを所有し、link styling を消さない。
- `plan-editor-command-expansion.md`: command metadata は `EditorCommand`、文字列変換は `EditorTextOperations` に置く。本計画では command は追加しない。

---

## 背景

StickyNative は軽い付箋 memo として、plain text 保存を前提に高速な入力・保存・reopen を実現している。チェックボックス機能により `☐` / `☑` の task 表現は入っているが、`☑` 行は視覚的に完了済みだと分かりにくい。

本計画では rich text 保存や Markdown full spec へ寄せず、まず `☑` 行だけを editor 上で取り消し線表示する。これは Markdown-lite の最小導入であり、保存文字列・DB schema・autosave 経路を変更しない。

---

## 本計画の実装対象

実装対象:

- `☑` で始まる checkbox line の本文部分だけを editor 上で取り消し線表示する
- checkbox marker `☑` 自体と直後の空白には取り消し線を付けない
- 保存文字列は既存通り plain text の `☑` 行のまま維持する
- temporary attribute は `.strikethroughStyle` のみを所有する

本計画で実装しないもの:

- `~~text~~`
- 太字 / 斜体 / highlight / heading
- Markdown link `[label](url)`
- LINE 風 selection formatting toolbar
- formatting command / shortcut / context menu
- rich text / attributed string 永続化

---

## 今回触る関連ファイル

| ファイル | 扱い |
|----------|------|
| `StickyNativeApp/CheckableTextView.swift` | 主対象。`☑` 行 detection、temporary `.strikethroughStyle`、IME guard、Smart Links との refresh order を実装 |
| `StickyNativeApp/EditorCommand.swift` | 変更しない。Phase 1 は command を追加しない |
| `StickyNativeApp/EditorTextOperations.swift` | 変更しない。Phase 1 は text transformation を追加しない |
| `StickyNativeApp/MemoEditorView.swift` | 確認のみ。editor hosting / font size 反映に副作用がないことを確認 |
| `StickyNativeApp/PersistenceCoordinator.swift` | 変更しない。保存経路確認のみ |
| `StickyNativeApp/SQLiteStore.swift` | 変更しない。schema 変更なし |
| `docs/roadmap/plan-markdown-lite-editor.md` | 本計画書 |

---

## 対象外

- Markdown full spec 対応
- `~~text~~` rendering
- 太字 / 斜体 / highlight / heading rendering
- Markdown link parsing
- selection formatting toolbar
- formatting command / shortcut / context menu
- HTML inline parsing
- 画像埋め込み
- 表
- 脚注
- nested list の完全対応
- code block syntax highlight
- rich text / attributed string の永続化
- DB schema 変更
- WYSIWYG Markdown editor
- 常設 formatting toolbar
- preview pane
- Markdown export UI
- 既存 `☐` / `☑` checkbox の即時廃止
- autosave 戦略変更
- window lifecycle / global shortcut / folder / trash の仕様変更

---

## 問題一覧

| ID | 分類 | 内容 |
|----|------|------|
| U-50 | UI | チェック済み行が視覚的に完了済みと分かりにくい |
| U-52 | UI | Markdown full 対応を一度に入れると、軽いメモ editor が複雑化する |
| A-50 | Architecture | Markdown 表示装飾を保存形式に混ぜると plain text / autosave / search と衝突する |
| A-51 | Architecture | Smart Links の URL temporary attributes と Markdown temporary attributes が競合する可能性がある |
| F-50 | Focus | Markdown decoration refresh が IME marked text を壊すリスクがある |
| P-50 | Persistence | rich text attributes を保存せず、既存 `draft TEXT` を維持する必要がある |
| K-50 | Knowledge | Phase 1 の Markdown-lite subset と future scope の境界を文書化する必要がある |

---

## Issue -> Phase 対応

| Issue | Phase | 対応内容 |
|-------|-------|----------|
| K-50 | Phase 0 | Phase 1 の subset、対象外、plain text 保存方針を固定 |
| U-52 | Phase 0 | Markdown full spec / toolbar / commands を対象外へ明記 |
| A-50 | Phase 1 | decoration は temporary attributes とし、保存形式を変更しない |
| A-51 | Phase 1 | Markdown-lite ownership key を `.strikethroughStyle` のみに固定し、Smart Links の keys を消さない |
| F-50 | Phase 1 / Phase 2 | marked text 中は decoration refresh を避け、実機確認する |
| U-50 | Phase 1 | `☑` 行の automatic strikethrough decoration を追加 |
| P-50 | Phase 2 | close / reopen / relaunch 後も plain text draft と decoration 再構築を確認する |

---

## 技術方針

### 現行実装の事実

- `CheckableTextView` は `NSViewRepresentable` で、内部に `NSScrollView` と `CheckboxNSTextView` を持つ。
- `CheckboxNSTextView` は `NSTextView` subclass。
- `configureInitialTextView` は `textView.isRichText = false` を設定している。
- `Coordinator.textDidChange` は `parent.text = textView.string` で plain text を binding に戻す。
- `EditorCommand` は command identity / label / shortcut / context menu order を持つ。
- `EditorTextOperations` は checkbox / date / datetime の pure text operation を持つ。
- `SmartLinkDetector` は URL range を検出し、`layoutManager` temporary attributes で `.underlineStyle` / `.foregroundColor` を付けている。
- Smart Link hover feedback も `.underlineStyle` / `.foregroundColor` を使う。
- `SQLiteStore` の memo draft は text として保存される。

### 責務境界

`CheckableTextView.swift`:

- `☑` 行 decoration refresh の orchestration
- `CheckboxNSTextView` 内の temporary `.strikethroughStyle` 適用
- Smart Links decoration との refresh order 管理
- IME marked text 中の refresh skip
- 保存文字列には触らない

`MarkdownLiteParser` または private helper:

- Phase 1 では `String` から `☑` 行 range のみ抽出する
- NSTextView lifecycle、focus、menu、keyboard event は持たない
- Phase 1 では同一ファイル内 private type / helper でよい

`EditorCommand.swift`:

- 変更しない。
- Phase 1 では command は追加しない。

`EditorTextOperations.swift`:

- 変更しない。
- Phase 1 では text transformation は追加しない。

Persistence:

- 変更しない。
- Markdown decoration は保存しない。
- `draft TEXT` に保存する文字列だけが source of truth。

### メモリで持つ情報

`CheckboxNSTextView` または helper に transient state として以下を持つ。

- `markdownDecorationRanges: [MarkdownLiteDecoration]`

Phase 1 の decoration kind:

```swift
private struct MarkdownLiteDecoration {
  let range: NSRange
  let kind: Kind

  enum Kind {
    case completedTaskLine
  }
}
```

これらは reopen / relaunch 後に復元しない。`textView.string` から再解析する。

### Temporary Attribute Ownership

Phase 1 の Markdown-lite ownership key:

- `.strikethroughStyle`

Phase 1 で cleanup してよい key:

- `.strikethroughStyle` のみ

Phase 1 で cleanup してはいけない key:

- `.underlineStyle`
- `.foregroundColor`
- `.backgroundColor`
- `.font`
- `.obliqueness`

理由:

- 既存 Smart Links / hover は `.underlineStyle` / `.foregroundColor` を所有している。
- Markdown-lite が temporary attributes を広く削除すると link styling / hover styling を消すリスクがある。
- Phase 1 は completed line の取り消し線だけが目的なので `.strikethroughStyle` に限定する。

将来、bold / italic / highlight / heading を入れる場合は、`.font`, `.obliqueness`, `.backgroundColor` などの ownership と refresh order を別計画で追加定義してから実装する。

### Decoration Refresh Order

Phase 1 の refresh order:

1. full text range から Markdown-lite ownership key `.strikethroughStyle` だけを削除
2. `☑` 行 parser を実行
3. `☑` 行の本文 range に `.strikethroughStyle` を適用
4. Smart Links refresh は既存経路で `.underlineStyle` / `.foregroundColor` を管理する
5. Smart Link hover がある場合は既存 hover refresh が `.underlineStyle` / `.foregroundColor` を上書きする

注意:

- Markdown-lite は Smart Links ownership keys を削除しない。
- Smart Links は Markdown-lite ownership key `.strikethroughStyle` を削除しない。
- `☑` 行内の URL は、取り消し線と link styling が重なってよい。

### Phase 1 Parser

対象:

- 行頭 indentation の後に `☑` または `☑ ` がある行

範囲:

- indentation、`☑`、`☑` 直後の空白は範囲に含めない
- 原則として `☑` marker 後の本文だけ
- 改行文字は strikethrough 範囲に含めない

例:

```text
  ☑ 牛乳を買う
```

`  ☑ 牛乳を買う` のうち `牛乳を買う` の range に `.strikethroughStyle` を付ける。

### IME / Marked Text

- `hasMarkedText()` が true の間は decoration refresh を避ける。
- editor command の marked text guard は変更しない。
- marked text 中に temporary attributes 更新で変換中文字が消えないことを実機確認する。

### AppKit / SwiftUI 境界

SwiftUI 側には Markdown decoration state を渡さない。

理由:

- decoration は editor 内部の transient view state。
- SwiftUI state に載せると text change ごとに view update が増え、入力の軽さを損ねる。
- `NSTextView` と layout manager の temporary attributes だけで完結できる。

### Persistence 境界

保存するもの:

- plain text draft

保存しないもの:

- strikethrough attribute
- Markdown parser result
- link attribute
- hover state

将来 full rich text が必要になった場合は、本計画を拡張せず、別計画で document model / migration / export を扱う。

---

## 修正フェーズ

### Phase 0: Scope Fix

目的:

- Markdown full 対応ではなく Phase 1 の `☑` 行 decoration に導入範囲を固定する。

対象ファイル:

- `docs/roadmap/plan-markdown-lite-editor.md`

実装内容:

- plain text 保存を維持
- DB schema 変更なし
- Phase 1 は `☑` 行の automatic strikethrough のみに限定
- `~~text~~`, bold, italic, highlight, heading, Markdown link は Future Plans に分離
- selection toolbar は `docs/roadmap/plan-markdown-selection-toolbar.md` に分離
- command 追加は本計画の対象外にする

Gate:

- 対象外が明記されている
- Issue -> Phase 対応が MECE
- Persistence 境界が明記されている
- Phase 1 の temporary attribute ownership key が `.strikethroughStyle` のみに固定されている

### Phase 1: Completed Task Line Decoration

目的:

- `☑` 行の本文部分だけを editor 上で取り消し線表示する。

対象ファイル:

- `StickyNativeApp/CheckableTextView.swift`

実装内容:

- private `MarkdownLiteDecoration` または同等 helper を追加
- private parser で `☑` 行の本文 range を抽出
- full text range から `.strikethroughStyle` だけを cleanup
- `layoutManager` temporary attributes で `.strikethroughStyle` を付ける
- `Coordinator.textDidChange` / `updateNSView` 後に decoration refresh
- `hasMarkedText()` が true の間は refresh を避ける
- Smart Links styling と ownership key が衝突しないようにする

Gate:

- `☑` 行が取り消し線表示になる
- checkbox marker `☑` 自体には取り消し線が付かない
- `☐` 行は取り消し線表示にならない
- 通常行は取り消し線表示にならない
- URL を含む `☑` 行で link styling / hover styling が消えない
- 保存される draft は `☑` 文字列のみ
- build が通る

### Phase 2: Regression Gate

目的:

- editor の主操作と persistence を壊していないことを確認する。

対象ファイル:

- コード変更なし
- 必要なら本計画書へ実機確認結果を追記

Gate:

- global shortcut 後にゼロクリック入力できる
- 非アクティブ状態から 1 click で入力できる
- 日本語 IME の入力・変換・確定が正常
- checkbox toggle が正常
- date / datetime command が正常
- Smart Links の `Command-click` / context menu / hover が正常
- close / reopen 後に plain text が復元され、decoration が再構築される
- relaunch 後に plain text が復元され、decoration が再構築される

---

## Future Plans

以下は本計画では実装しない。Phase 1 実装・実機 Gate 通過後、別計画で再レビューしてから扱う。

- `~~text~~` rendering
- `**bold**`
- `*italic*`
- `==highlight==`
- `# heading`
- `[label](url)` Markdown link
- formatting command / shortcut / context menu
- LINE 風 selection formatting toolbar

関連計画:

- `docs/roadmap/plan-markdown-selection-toolbar.md`

---

## Gate条件

- `xcodebuild -project StickyNative.xcodeproj -scheme StickyNative -configuration Debug build` が成功する
- `git diff --check` が成功する
- `textView.isRichText = false` を維持する
- SQLite schema を変更しない
- `☑` 行の取り消し線は temporary `.strikethroughStyle` のみ
- Markdown-lite cleanup は `.strikethroughStyle` のみに限定されている
- Smart Links の `.underlineStyle` / `.foregroundColor` を Markdown-lite 側で削除しない
- `memo.draft` / SQLite に attributed string や decoration metadata が混ざらない
- marked text 中に decoration refresh で入力が消えない
- Smart Links の URL detection / opening policy / hover feedback が維持される
- `EditorCommand` / `EditorTextOperations` に変更がない

---

## 回帰/副作用チェック

| 確認項目 | 理由 |
|----------|------|
| first mouse | decoration refresh が非アクティブ window からの 1 click 入力を邪魔しないことを確認 |
| global shortcut 後の入力 | focus token / first responder に副作用がないことを確認 |
| 日本語 IME | marked text 中の temporary attributes 更新が変換を壊さないことを確認 |
| checkbox toggle | `☐` / `☑` の文字列変換と取り消し線表示が競合しないことを確認 |
| Smart Links | URL temporary attributes と Markdown temporary attributes の ownership が分離されていることを確認 |
| Smart Link hover | hover の underline / color が `☑` 行 decoration で消えないことを確認 |
| editor commands | date / datetime / checkbox command の dispatch が維持されることを確認 |
| autosave | decoration が保存文字列に混ざらないことを確認 |
| search / Home preview | plain text 表示が維持されることを確認 |

---

## 実機確認項目

- [ ] `☑ 完了` の行が取り消し線表示になる
- [ ] `☑` 自体には取り消し線が付かない
- [ ] indentation 付き `  ☑ 完了` の行が取り消し線表示になる
- [ ] `☐ 未完了` の行は取り消し線表示にならない
- [ ] 通常行は取り消し線表示にならない
- [ ] `☑` 行を checkbox toggle で通常行に戻すと取り消し線が消える
- [ ] `☐` 行を checkbox toggle で `☑` にすると取り消し線が付く
- [ ] URL を含む `☑` 行でも Smart Links が開ける
- [ ] URL を含む `☑` 行でも Smart Link hover の色 / 下線が維持される
- [ ] 日本語 IME の入力・変換・確定が正常
- [ ] close / reopen 後に plain text と取り消し線表示が復元される
- [ ] relaunch 後に plain text と取り消し線表示が復元される
- [ ] Home / Trash / search の表示が壊れない

---

## 技術詳細確認

- Markdown-lite parser は Phase 1 では private helper として `CheckableTextView.swift` に置く。
- Phase 1 の parser は `☑` 行の本文 range のみ返す。
- decoration result は transient state で、保存しない。
- Phase 1 の temporary attribute ownership key は `.strikethroughStyle` のみ。
- temporary attributes cleanup は `.strikethroughStyle` のみに限定する。
- Smart Links の `.underlineStyle` / `.foregroundColor` は Markdown-lite 側で削除しない。
- Smart Links と Markdown-lite の temporary attributes 更新順を固定する。
- marked text 中は decoration refresh を避ける。
- `EditorCommand` / `EditorTextOperations` は変更しない。
- `NSTextView` / AppKit 内で完結させ、SwiftUI state に decoration state を載せない。
- rich text 保存が必要になった場合は別計画で document model と migration を扱う。

---

## セルフチェック結果

### SSOT整合

[x] migration README は現環境に存在しないため unavailable として扱った
[x] repo 内 product / architecture / roadmap 文書を確認した
[x] checkbox / Smart Links / hover feedback 計画との境界を明記した

### 変更範囲

[x] 主目的は `☑` 行 decoration のみ
[x] 高リスク疎通確認テーマは editor decoration / temporary attribute ownership のみ
[x] Markdown full spec、commands、selection toolbar、rich text 保存を対象外にした

### 技術詳細

[x] ファイルごとの責務が明確
[x] メモリ管理と persistence の境界が明確
[x] temporary attribute ownership が明確
[x] イベント経路と状態遷移が説明できる

### Window / Focus

[x] Window 責務を変更しない
[x] Focus 制御を変更しない
[x] first mouse の確認項目を明記した

### Persistence

[x] 保存経路は変更しない
[x] Markdown decoration を保存しない
[x] relaunch 時は plain text から再解析とした

### 実機確認

[x] global shortcut を確認する
[x] 1 click 操作を確認する
[x] ゼロクリック入力を確認する
