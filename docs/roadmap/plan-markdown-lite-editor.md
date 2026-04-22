# Markdown Lite Editor Plan

作成: 2026-04-22  
ステータス: 計画中（実装未着手）  

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-22 | 初版作成。plain text 保存を維持した Markdown-lite 対応を計画化 |

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
- `docs/product/current-feature-summary.md`

### migration 上位文書の確認結果

`docs/roadmap/stickynative-ai-planning-guidelines.md` では `/Users/hori/Desktop/Sticky/migration/*` を SSOT として参照するよう定義されているが、2026-04-22 時点の作業環境では `/Users/hori/Desktop/Sticky/migration` が存在しない。

したがって、本計画では repo 内の `docs/product/*`、`docs/architecture/*`、`docs/roadmap/*` と現行実装を暫定 SSOT とする。migration 文書が復旧した場合は、実装前または次回計画更新時に再照合する。

### SSOT整合メモ

- `ux-principles.md`: 「速い」「自然」「軽い」を優先する。Markdown 対応は整理 mode を増やさず、直接 typing できる範囲に留める。
- `technical-decision.md`: editor surface は SwiftUI、text editing は AppKit `NSTextView`。Markdown parsing / decoration は editor 内部に置く。
- `persistence-boundary.md`: draft は plain text として保存する。初期 Markdown 対応では DB schema を変更しない。
- `plan-checkbox-feature.md`: 既存 checkbox は `☐` / `☑` plain text。Markdown task list へ全面移行する場合は別フェーズで互換方針を決める。
- `plan-editor-command-expansion.md`: editor command metadata は `EditorCommand`、文字列変換は `EditorTextOperations` に置く。Markdown command を追加する場合もこの境界を守る。
- `plan-smart-links.md`: URL 自動検出は既存 Smart Links を優先する。Markdown link `[label](url)` は別フェーズで扱う。

---

## 背景

StickyNative は軽い付箋 memo として、plain text 保存を前提に高速な入力・保存・reopen を実現している。一方で、チェック済みタスクの取り消し線、見出し、太字、Markdown link などの軽い構造表現が欲しくなる場面がある。

本計画では rich text 保存へ寄せず、plain text を Markdown-lite として解釈し、editor 上で一時的な表示装飾を行う方針を採る。

初期方針:

- 保存は plain text のまま
- DB schema 変更なし
- Markdown full spec は対象外
- 既存 checkbox / Smart Links / IME / autosave を壊さない
- まずは task completion と strikethrough 表示から開始する

---

## 今回触る関連ファイル

| ファイル | 扱い |
|----------|------|
| `StickyNativeApp/CheckableTextView.swift` | 主対象。Markdown decoration refresh、temporary attributes、IME guard を実装 |
| `StickyNativeApp/EditorCommand.swift` | Phase 3 以降で Markdown command を追加する場合のみ変更 |
| `StickyNativeApp/EditorTextOperations.swift` | Phase 3 以降で `~~` toggle などの text operation を追加する場合のみ変更 |
| `StickyNativeApp/MemoEditorView.swift` | 確認のみ。editor hosting / font size 反映に副作用がないことを確認 |
| `StickyNativeApp/PersistenceCoordinator.swift` | 変更しない。保存経路確認のみ |
| `StickyNativeApp/SQLiteStore.swift` | 変更しない。schema 変更なし |
| `docs/roadmap/plan-markdown-lite-editor.md` | 本計画書 |

---

## 対象外

- Markdown full spec 対応
- HTML inline parsing
- 画像埋め込み
- 表
- 脚注
- nested list の完全対応
- code block syntax highlight
- rich text / attributed string の永続化
- DB schema 変更
- WYSIWYG Markdown editor
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
| U-51 | UI | 任意テキストの取り消し線や軽い強調表現がない |
| U-52 | UI | Markdown full 対応を一度に入れると、軽いメモ editor が複雑化する |
| A-50 | Architecture | Markdown 表示装飾を保存形式に混ぜると plain text / autosave / search と衝突する |
| A-51 | Architecture | Smart Links の URL temporary attributes と Markdown temporary attributes が競合する可能性がある |
| A-52 | Architecture | command を増やす場合、`EditorCommand` / `EditorTextOperations` の既存境界を維持する必要がある |
| F-50 | Focus | Markdown decoration refresh が IME marked text を壊すリスクがある |
| P-50 | Persistence | rich text attributes を保存せず、既存 `draft TEXT` を維持する必要がある |
| K-50 | Knowledge | StickyNative が採用する Markdown subset と対象外を文書化する必要がある |

---

## Issue -> Phase 対応

| Issue | Phase | 対応内容 |
|-------|-------|----------|
| K-50 | Phase 0 | Markdown-lite の subset、対象外、plain text 保存方針を固定 |
| U-50 | Phase 1 | `☑` 行の automatic strikethrough decoration を追加 |
| A-50 | Phase 1 / Phase 2 | Markdown decoration は temporary attributes とし、保存形式を変更しない |
| A-51 | Phase 1 / Phase 2 | Smart Links と Markdown decoration の refresh order を定義する |
| F-50 | Phase 1 / Phase 4 | marked text 中は decoration refresh を避け、実機確認する |
| U-51 | Phase 2 / Phase 3 | `~~text~~` 表示、必要なら toggle command を追加する |
| A-52 | Phase 3 | command 追加時は `EditorCommand` / `EditorTextOperations` に分離する |
| U-52 | Phase 0 / Phase 4 | full spec を対象外にし、段階導入 Gate を置く |
| P-50 | Phase 4 | close / reopen / relaunch 後も plain text draft と decoration 再構築を確認する |

---

## Markdown-lite Scope

### Phase 1 で扱う

```text
☑ 完了したタスク
```

- `☑` で始まる checkbox line を editor 上だけ取り消し線表示する。
- 保存文字列は既存通り `☑` のまま。
- command は追加しない。

### Phase 2 候補

```md
~~取り消し線~~
```

- `~~...~~` に temporary strikethrough を付ける。
- marker を隠すかどうかは Phase 2 では決めない。初期実装では marker は表示したままが安全。

### Phase 3 候補

```md
**太字**
`code`
# 見出し
[label](https://example.com)
```

- 実装する場合は 1 feature ずつ別 Gate を置く。
- Smart Links の URL 検出と Markdown link parsing が衝突しやすいため、`[label](url)` は後回しにする。

### 採用しない

- raw HTML
- table
- footnote
- image embed
- code block syntax highlight
- nested list の完全互換
- CommonMark full compliance

---

## 技術方針

### 現行実装の事実

- `CheckableTextView` は `NSViewRepresentable` で、内部に `NSScrollView` と `CheckboxNSTextView` を持つ。
- `CheckboxNSTextView` は `NSTextView` subclass。
- `configureInitialTextView` は `textView.isRichText = false` を設定している。
- `Coordinator.textDidChange` は `parent.text = textView.string` で plain text を binding に戻す。
- `EditorCommand` は command identity / label / shortcut / context menu order を持つ。
- `EditorTextOperations` は checkbox / date / datetime の pure text operation を持つ。
- `SmartLinkDetector` は URL range を検出し、`layoutManager` temporary attributes で underline / link color を付けている。
- `SQLiteStore` の memo draft は text として保存される。

### 責務境界

`CheckableTextView.swift`:

- Markdown decoration refresh の orchestration
- `CheckboxNSTextView` 内の temporary attributes 適用
- Smart Links decoration との refresh order 管理
- IME marked text 中の refresh skip
- 保存文字列には触らない

`MarkdownLiteParser` または private helper:

- `String` から decoration range を抽出する
- NSTextView lifecycle、focus、menu、keyboard event は持たない
- Phase 1 では同一ファイル内 private type でよい
- Phase 2 以降で parsing が増えたら `MarkdownLiteParser.swift` へ分離を検討する

`EditorCommand.swift`:

- Phase 1 では変更しない。
- Phase 3 以降で `toggleStrikethrough` などの command を追加する場合、label / shortcut / context menu order をここに追加する。

`EditorTextOperations.swift`:

- Phase 1 では変更しない。
- Phase 3 以降で `~~` toggle など文字列変換を追加する場合、pure text operation としてここに追加する。

Persistence:

- 変更しない。
- Markdown decoration は保存しない。
- `draft TEXT` に保存する文字列だけが source of truth。

### メモリで持つ情報

`CheckboxNSTextView` または helper に transient state として以下を持つ。

- `markdownDecorationRanges: [MarkdownLiteDecoration]`

`MarkdownLiteDecoration` 候補:

```swift
private struct MarkdownLiteDecoration {
  let range: NSRange
  let kind: Kind

  enum Kind {
    case completedTaskLine
    case strikethrough
    case bold
    case inlineCode
    case heading(level: Int)
  }
}
```

Phase 1 では `completedTaskLine` のみでよい。

これらは reopen / relaunch 後に復元しない。`textView.string` から再解析する。

### Decoration refresh order

temporary attributes は複数 feature が同じ `layoutManager` に乗るため、順序を固定する。

推奨 order:

1. Markdown-lite 関連 temporary attributes を full text range から削除
2. Smart Links 関連 temporary attributes を full text range から削除
3. Markdown-lite parser を実行
4. Markdown-lite base decoration を適用
5. Smart Links detector を実行
6. Smart Links base decoration を適用
7. Smart Links hover decoration がある場合は最後に上書き

理由:

- URL は操作対象なので、link color / underline を最後寄りに保つ。
- completed task line の strikethrough は URL 上にも残ってよいが、link の色と underline は link として見える方を優先する。
- hover は最も一時的な state なので最後に上書きする。

### Phase 1 parser

対象:

- 行頭 indentation の後に `☑` または `☑ ` がある行

範囲:

- 原則として `☑` を含む行全体
- ただし改行文字は strikethrough 範囲に含めない

例:

```text
  ☑ 牛乳を買う
```

`  ☑ 牛乳を買う` の visible line range に `.strikethroughStyle` を付ける。

### `~~text~~` parser 方針

Phase 2 以降で追加する場合:

- 1 行内の simple pair のみ
- nested marker は対象外
- escaped marker は対象外
- marker を跨ぐ selection editing は標準 text editing に任せる
- marker は初期実装では表示したまま

理由:

- marker 非表示 WYSIWYG は caret position / selection / IME と競合しやすい。
- StickyNative の主目的は軽い memo であり、Markdown editor の完全性ではない。

### Command policy

Phase 1 の automatic completed-task strikethrough は command 不要。

Phase 3 以降で arbitrary strikethrough を入れる場合の候補:

- command: `toggleStrikethrough`
- text operation: selection を `~~selection~~` で wrap / unwrap
- context menu: `取り消し線`
- shortcut: 初期は割り当てない。必要になったら `Command-Shift-X` を候補にする。

理由:

- shortcut を増やすと lightweight editor の発見性・競合確認コストが上がる。
- まずは context menu のみにすると IME / macOS 標準 shortcut との衝突が少ない。

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
- bold attribute
- heading font attribute
- Markdown parser result
- link attribute
- hover state

将来 full rich text が必要になった場合は、本計画を拡張せず、別計画で document model / migration / export を扱う。

---

## 修正フェーズ

### Phase 0: Scope Fix

目的:

- Markdown full 対応ではなく Markdown-lite として導入範囲を固定する。

対象ファイル:

- `docs/roadmap/plan-markdown-lite-editor.md`

実装内容:

- plain text 保存を維持
- DB schema 変更なし
- Phase 1 は `☑` 行の automatic strikethrough のみに限定
- command 追加は Phase 3 以降に分離

Gate:

- 対象外が明記されている
- Issue -> Phase 対応が MECE
- Persistence 境界が明記されている

### Phase 1: Completed Task Line Decoration

目的:

- `☑` 行を editor 上だけ取り消し線表示する。

対象ファイル:

- `StickyNativeApp/CheckableTextView.swift`

実装内容:

- private `MarkdownLiteDecoration` を追加
- private parser で `☑` 行 range を抽出
- `layoutManager` temporary attributes で `.strikethroughStyle` を付ける
- `Coordinator.textDidChange` / `updateNSView` 後に decoration refresh
- `hasMarkedText()` が true の間は refresh を避ける
- Smart Links styling と refresh order を固定する

Gate:

- `☑` 行が取り消し線表示になる
- `☐` 行は取り消し線表示にならない
- 通常行は取り消し線表示にならない
- 保存される draft は `☑` 文字列のみ
- build が通る

### Phase 2: Optional `~~text~~` Rendering Probe

目的:

- 任意テキストの strikethrough 表現を Markdown marker で扱えるか確認する。

対象ファイル:

- `StickyNativeApp/CheckableTextView.swift`

実装内容:

- 1 行内の simple `~~...~~` range を抽出
- marker を含む範囲または marker 内側の範囲に `.strikethroughStyle` を付ける
- marker 非表示はしない
- nested / escaped marker は対象外

Gate:

- simple `~~text~~` が取り消し線表示になる
- 不完全な `~~` で表示が壊れない
- URL と重なっても link open / context menu が維持される
- IME 入力が壊れない

### Phase 3: Optional Strikethrough Command

目的:

- 任意テキストを context menu から `~~` wrap / unwrap できるようにする。

対象ファイル:

- `StickyNativeApp/EditorCommand.swift`
- `StickyNativeApp/EditorTextOperations.swift`
- `StickyNativeApp/CheckableTextView.swift`

実装内容:

- `EditorCommand.toggleStrikethrough` を追加
- `EditorTextOperations.toggleStrikethrough` を追加
- selection がある場合は `~~selection~~` に wrap
- selection が既に `~~...~~` 内なら unwrap
- selection がない場合は current word または空 marker `~~~~` のどちらにするかを実装前に決める
- 初期は shortcut を割り当てず、context menu のみにする

Gate:

- command metadata が `EditorCommand` に集約されている
- text operation が `EditorTextOperations` に分離されている
- IME marked text 中は command が発動しない
- undo / redo が自然に動く

### Phase 4: Regression Gate

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
- Smart Links の `Command-click` / context menu が正常
- hover feedback 計画が実装済みの場合、hover styling と競合しない
- close / reopen 後に plain text が復元され、decoration が再構築される
- relaunch 後に plain text が復元され、decoration が再構築される

---

## Gate条件

- `xcodebuild -project StickyNative.xcodeproj -scheme StickyNative -configuration Debug build` が成功する
- `git diff --check` が成功する
- `textView.isRichText = false` を維持する
- SQLite schema を変更しない
- `☑` 行の取り消し線は temporary attributes のみ
- `memo.draft` / SQLite に attributed string や decoration metadata が混ざらない
- marked text 中に decoration refresh で入力が消えない
- Smart Links の URL detection / opening policy が維持される
- command を追加する場合、`EditorCommand` / `EditorTextOperations` の責務境界を守る

---

## 回帰/副作用チェック

| 確認項目 | 理由 |
|----------|------|
| first mouse | decoration refresh が非アクティブ window からの 1 click 入力を邪魔しないことを確認 |
| global shortcut 後の入力 | focus token / first responder に副作用がないことを確認 |
| 日本語 IME | marked text 中の temporary attributes 更新が変換を壊さないことを確認 |
| checkbox toggle | `☐` / `☑` の文字列変換と取り消し線表示が競合しないことを確認 |
| Smart Links | URL temporary attributes と Markdown temporary attributes の重なりを確認 |
| editor commands | date / datetime / checkbox command の dispatch が維持されることを確認 |
| autosave | decoration が保存文字列に混ざらないことを確認 |
| search / Home preview | plain text 表示が維持されることを確認 |

---

## 実機確認項目

- [ ] `☑ 完了` の行が取り消し線表示になる
- [ ] `☐ 未完了` の行は取り消し線表示にならない
- [ ] 通常行は取り消し線表示にならない
- [ ] `☑` 行を checkbox toggle で通常行に戻すと取り消し線が消える
- [ ] `☐` 行を checkbox toggle で `☑` にすると取り消し線が付く
- [ ] URL を含む `☑` 行でも Smart Links が開ける
- [ ] 日本語 IME の入力・変換・確定が正常
- [ ] close / reopen 後に plain text と取り消し線表示が復元される
- [ ] relaunch 後に plain text と取り消し線表示が復元される
- [ ] Home / Trash / search の表示が壊れない
- [ ] Phase 2 実装時は simple `~~text~~` が取り消し線表示になる
- [ ] Phase 3 実装時は context menu から `~~` wrap / unwrap できる

---

## 技術詳細確認

- Markdown-lite parser は初期フェーズでは private helper として `CheckableTextView.swift` に置く。
- parser が複数構文へ増えた場合のみ `MarkdownLiteParser.swift` へ分離する。
- decoration result は transient state で、保存しない。
- temporary attributes は full text range から削除して再適用する。
- Smart Links と Markdown-lite の temporary attributes 更新順を固定する。
- marked text 中は decoration refresh を避ける。
- command 追加時は `EditorCommand` に metadata、`EditorTextOperations` に pure text operation を置く。
- `NSTextView` / AppKit 内で完結させ、SwiftUI state に decoration state を載せない。
- rich text 保存が必要になった場合は別計画で document model と migration を扱う。

---

## セルフチェック結果

### SSOT整合

[x] migration README は現環境に存在しないため unavailable として扱った
[x] repo 内 product / architecture / roadmap 文書を確認した
[x] checkbox / editor command / Smart Links 計画との境界を明記した

### 変更範囲

[x] 主目的は Markdown-lite の導入計画のみ
[x] 高リスク疎通確認テーマは editor decoration / persistence 境界のみ
[x] Markdown full spec と rich text 保存を対象外にした

### 技術詳細

[x] ファイルごとの責務が明確
[x] メモリ管理と persistence の境界が明確
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
