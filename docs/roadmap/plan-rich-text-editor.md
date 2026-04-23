# Rich Text Editor Plan

作成: 2026-04-23  
ステータス: 計画中（Markdown 記号挿入方式を停止し、装飾付き editor / persistence へ移行）

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-23 | 初版作成。selection formatting を Markdown marker 挿入ではなく `NSAttributedString` 属性として保存する方針を計画化 |

---

## SSOT参照宣言

本計画は以下を上位文書として扱う。

### StickyNative ローカル補助文書

- `docs/roadmap/stickynative-ai-planning-guidelines.md`
- `docs/product/product-vision.md`
- `docs/product/ux-principles.md`
- `docs/product/mvp-scope.md`
- `docs/product/current-feature-summary.md`
- `docs/architecture/technical-decision.md`
- `docs/architecture/persistence-boundary.md`
- `docs/architecture/domain-model.md`
- `docs/roadmap/roadmap.md`
- `docs/roadmap/plan-checkbox-feature.md`
- `docs/roadmap/plan-editor-command-expansion.md`
- `docs/roadmap/plan-markdown-lite-editor.md`
- `docs/roadmap/plan-markdown-selection-toolbar.md`
- `docs/roadmap/plan-smart-links.md`
- `docs/roadmap/plan-smart-link-hover-feedback.md`

### migration 上位文書の確認結果

`docs/roadmap/stickynative-ai-planning-guidelines.md` では `/Users/hori/Desktop/Sticky/migration/*` を SSOT として参照するよう定義されているが、2026-04-23 時点の作業環境では `/Users/hori/Desktop/Sticky/migration` が存在しない。

したがって、本計画では repo 内の `docs/product/*`、`docs/architecture/*`、`docs/roadmap/*` と現行実装を暫定 SSOT とする。migration 文書が復旧した場合は、実装前または次回計画更新時に再照合する。

### SSOT整合メモ

- `product-vision.md`: 主体験は `Cmd+Option+Enter -> すぐ書く -> 元作業に戻る -> 1 click で再編集`。rich text 化はこの入力速度を落とさない範囲に限定する。
- `ux-principles.md`: 「自然」「軽い」を優先する。装飾 UI は macOS native editor の自然な selection 操作に寄せ、常設の重い formatting surface は入れない。
- `technical-decision.md`: UI は SwiftUI、text editing / window / focus は AppKit を活用する。rich text 操作は `NSTextView` / `NSTextStorage` 側へ置く。
- `persistence-boundary.md`: 既存 Phase 3 は local draft 永続化。rich text 化では `draft TEXT` を互換・検索・preview 用 SSOT として残し、装飾情報を追加データとして保存する。
- `current-feature-summary.md`: 現行 editor は plain text `CheckableTextView` と autosave 経路を持つ。rich text 化後も checkbox、date insert、context menu、IME、undo は regression gate として守る。
- `plan-markdown-lite-editor.md` / `plan-markdown-selection-toolbar.md`: 既存計画は plain text / Markdown marker 前提。ユーザー期待は marker 表示ではなく native rich text 装飾なので、本計画が後続実装の優先計画となる。

---

## 背景

現行 selection formatting は、太字なら `**selection**`、斜体なら `*selection*`、取り消し線なら `~~selection~~`、ハイライトなら `==selection==`、引用なら行頭 `> ` を本文に挿入し、`MarkdownLiteParser` が temporary attributes を当てる構造になっている。

この方式は editor UI が WYSIWYG 装飾に見える一方で、保存本文には Markdown marker が残る。特に以下の不一致が発生している。

- 太字 / 斜体が期待通り見えない
- 取り消し線 / ハイライトは効いても `~~` / `==` が見える
- 引用は `> ` が見え、機能意図も分かりにくい
- Markdown-lite 計画では対象外だった `.font` / `.backgroundColor` cleanup まで実装が広がっている

本計画では、selection formatting を Markdown marker 変換として扱わず、`NSAttributedString` の属性として保持・保存する rich text editor に移行する。

---

## 本計画の目的

主目的:

- 選択範囲の太字 / 斜体 / 取り消し線 / ハイライトを、本文 marker ではなく `NSAttributedString` 属性として保存・復元する。

保持する制約:

- `1 memo = 1 window` は変更しない
- SQLite は継続する
- オンデバイス保存のみとする
- `draft TEXT` は残し、title / preview / search / fallback のための plain text として継続保存する
- 既存メモは破壊しない
- 装飾なしメモは `rich_text_data` を持たなくても表示できる
- focus / first mouse / IME / undo の自然な編集体験を壊さない

---

## 対象外

- Markdown full spec 対応
- Markdown marker 非表示 live preview editor
- HTML editor
- cloud sync / share / collaboration
- 画像埋め込み
- table / code block / footnote
- 文字色 / フォントファミリ変更 / 任意サイズ変更
- permanent style toolbar
- export UI
- 既存 `☐` / `☑` checkbox の即時廃止
- Smart Links の仕様変更
- Home / Trash / Session / Folder の仕様変更
- window lifecycle / global shortcut の仕様変更

引用 / callout は Phase 1 の対象外とする。段落属性、複数行 selection、解除操作、見た目定義が絡むため、太字 / 斜体 / 取り消し線 / ハイライトの Gate 通過後に再判断する。

---

## 今回触る関連ファイル

| ファイル | 扱い |
|----------|------|
| `StickyNativeApp/PersistenceModels.swift` | `PersistedMemo` に `richTextData: Data?` を追加する候補 |
| `StickyNativeApp/SQLiteStore.swift` | `rich_text_data BLOB` migration、select / row decode、upsert 更新 |
| `StickyNativeApp/PersistenceCoordinator.swift` | plain text + rich text data を保存する API を追加 |
| `StickyNativeApp/AutosaveScheduler.swift` | autosave payload を `String` から editor content payload へ拡張 |
| `StickyNativeApp/MemoWindow.swift` | `draft` と rich text state の保持方法を定義 |
| `StickyNativeApp/MemoWindowController.swift` | draft change subscription / flush の payload を更新 |
| `StickyNativeApp/WindowManager.swift` | memo open / persist 経路で rich text data を受け渡す |
| `StickyNativeApp/MemoEditorView.swift` | editor binding を rich text 対応に変更 |
| `StickyNativeApp/CheckableTextView.swift` | plain text Markdown decoration から attributed editor に移行 |
| `StickyNativeApp/EditorCommand.swift` | formatting command identity を追加する候補 |
| `StickyNativeApp/EditorTextOperations.swift` | plain text marker wrap は撤去。checkbox / date など plain text operation は継続 |
| `StickyNativeApp/MemoTitleFormatter.swift` | plain text `draft` から title / preview を生成し続ける |
| `StickyNativeApp/HomeViewModel.swift` / `HomeView.swift` | search / preview が `draft` を使い続けることを確認 |
| `docs/roadmap/plan-rich-text-editor.md` | 本計画書 |

---

## 保存形式方針

SQLite は継続する。`memos` に追加カラムを持たせる。

```sql
ALTER TABLE memos ADD COLUMN rich_text_data BLOB;
```

保存ルール:

- `draft TEXT NOT NULL`: 常に `attributedString.string` を保存する
- `rich_text_data BLOB NULL`: 装飾がある場合のみ RTF data を保存する
- 装飾がない場合は `rich_text_data = NULL` を許可する
- `title` は従来通り `draft` から生成する
- search / preview / empty memo 判定も従来通り `draft` を使う

読み込みルール:

1. `rich_text_data` が存在し、RTF として decode できる場合は rich text として editor に渡す。
2. `rich_text_data` が `NULL` または decode 失敗の場合は、`draft` から plain `NSAttributedString` を作る。
3. decode 失敗時も `draft` を fallback として使い、メモを開けない状態にしない。

容量方針:

- 短いメモでは RTF の固定ヘッダにより倍率は大きく見えるが、絶対量は数 KB 程度に収まる想定。
- `draft` と `rich_text_data` の二重保存は意図的に許容する。互換性、検索、preview、fallback の価値を優先する。
- 装飾なしメモは `rich_text_data = NULL` とし、既存メモの容量増を避ける。

---

## 問題一覧

| ID | 分類 | 内容 |
|----|------|------|
| U-70 | UI | selection toolbar が native formatting に見えるのに Markdown marker が本文に残る |
| U-71 | UI | 引用 / callout の意図が曖昧で、`> ` prefix がユーザーに露出している |
| A-70 | Architecture | `CheckableTextView` が Markdown parser、toolbar、temporary attributes、text operation を抱えて肥大化している |
| A-71 | Architecture | plain text operation と rich text operation の責務境界が未定義 |
| A-72 | Architecture | Smart Links の temporary attributes と永続 rich text attributes の ownership が未定義 |
| A-73 | Architecture | RTF encode / decode / fallback の責務配置が未定義 |
| A-74 | Architecture | attribute-only edit の autosave trigger / undo grouping が未定義 |
| A-75 | Architecture | bold / italic を `.font` そのものとして保存すると editor font size / family 設定と衝突する |
| P-70 | Persistence | `draft TEXT` だけでは装飾 range を保存できない |
| P-71 | Persistence | 既存メモを破壊せずに rich text 保存へ移行する fallback が必要 |
| P-72 | Persistence | autosave payload が `String` 固定で rich text data を運べない |
| F-70 | Focus | formatting toolbar / attributed text mutation が first mouse、selection、IME marked text を壊すリスクがある |
| K-70 | Knowledge | 既存 Markdown-lite 計画と rich text 方針の優先関係が未整理 |
| K-71 | Knowledge | 容量増、SQLite 継続、オンデバイス保存の判断基準を文書化する必要がある |

---

## Issue -> Phase 対応

| Issue | Phase | 対応内容 |
|-------|-------|----------|
| K-70 | Phase 0 | Markdown-lite / selection toolbar 計画を再位置付けし、本計画を優先計画にする |
| K-71 | Phase 0 | SQLite + `draft TEXT` + `rich_text_data BLOB` の保存方針を固定する |
| P-70 | Phase 1 | `rich_text_data BLOB` migration probe を行う |
| P-71 | Phase 2 | model / store API に nullable `richTextData` を通し、既存 `draft` 読み込みを維持する |
| A-73 | Phase 3 | `RichTextContentCodec` / `EditorContentFactory` の責務を固定する |
| P-72 | Phase 4 | `EditorContent` value と save API を導入する |
| P-72 | Phase 5 | Window / flush / autosave wiring を `EditorContent` に切り替える |
| A-72 | Phase 6 | Smart Links と永続 rich text attributes の ownership / refresh order を固定する |
| A-75 | Phase 6 | font family / size を信頼せず、current editor base font + traits へ正規化する方針を固定する |
| A-70 | Phase 7 | editor を attributed binding に変換する |
| A-70 | Phase 8 | Markdown marker parser / temporary decoration を撤去する |
| A-74 | Phase 9a | attribute-only edit の autosave trigger / undo grouping probe を行う |
| A-71 | Phase 9b | rich text formatting operation と toolbar / command wiring を実装する |
| U-70 | Phase 9b | 太字 / 斜体 / 取り消し線 / ハイライトを native attribute 操作として実装 |
| F-70 | Phase 9b | selection / first mouse / IME / undo regression gate を通す |
| U-71 | Phase 10 | 引用 / callout を後続判断に分離する |

---

## 修正フェーズ

### Phase 0: Scope Reset And Plan Alignment

目的:

- Markdown marker 挿入方式を selection formatting の本線から外す。
- 既存計画との関係を明確にする。

対象ファイル:

- `docs/roadmap/plan-rich-text-editor.md`
- 必要に応じて `docs/roadmap/plan-markdown-lite-editor.md`
- 必要に応じて `docs/roadmap/plan-markdown-selection-toolbar.md`

作業:

1. 本計画を追加する。
2. Markdown-lite は checkbox completed line decoration など plain text polish に限定する。
3. selection formatting は rich text editor 計画へ移す。
4. 引用 / callout は Phase 10 以降に分離する。

Gate:

- rich text 化の保存形式が `draft TEXT` + `rich_text_data BLOB` に固定されている
- 既存 Markdown marker selection formatting を延命しない方針が明記されている
- migration 文書不在時の暫定 SSOT が明記されている

### Phase 1: Persistence Probe

目的:

- SQLite に nullable `rich_text_data` を追加しても、既存 DB open / fetch / reopen が壊れないことだけを確認する。

対象ファイル:

- `SQLiteStore.swift`

作業:

1. `memos.rich_text_data BLOB` を nullable column として追加する。
2. migration 後も既存 `selectColumns` / `memoRow` は `rich_text_data` を読まない。
3. 既存 DB を開き、既存 memo の fetch / open / reopen が従来通り動くことを確認する。
4. `PRAGMA table_info(memos)` で column 追加だけを確認する。
5. probe 結果を `docs/roadmap/plan-rich-text-editor-probe-result.md` に記録し、次 Phase へ進めるか判断する。

Gate:

- 既存 DB を開いて migration が成功する
- 既存メモの title / preview / search / reopen が変わらない
- `rich_text_data` column が追加されても reader が無視できる
- migration 失敗時の扱いが session migration と同等以上に安全
- `PersistedMemo` / save API / editor model はまだ変更していない
- `docs/roadmap/plan-rich-text-editor-probe-result.md` に日時、対象 DB、確認結果、次 Phase 可否が記録されている

### Phase 2: Store Model Wiring

目的:

- nullable `rich_text_data` を model / SQLite API に通す。ただし RTF decode はまだ行わない。

対象ファイル:

- `PersistenceModels.swift`
- `SQLiteStore.swift`
- `PersistenceCoordinator.swift`

作業:

1. `PersistedMemo` に `richTextData: Data?` を追加する。
2. `selectColumns` / `memoRow` を更新し、BLOB を optional `Data` として読む。
3. `SQLiteStore` に plain text + optional BLOB を upsert できる API を追加する。
4. `PersistenceCoordinator` に save API の薄い入口を追加する。
5. 既存 `saveDraft` 呼び出しは互換のため残すか、内部で新 API に委譲する。

Gate:

- `rich_text_data == NULL` の既存メモが `PersistedMemo.richTextData == nil` として読める
- `draft` / title / preview / search の挙動が変わらない
- BLOB 読み書きはできるが、editor はまだ rich text として使わない
- RTF decode / fallback の責務は Phase 3 まで実装しない

### Phase 3: Rich Text Codec And Fallback Boundary

目的:

- RTF encode / decode / fallback の責務を一本化し、実装者が迷わない境界を作る。

対象ファイル:

- `RichTextContentCodec.swift`（新規候補）
- `EditorContentFactory.swift`（新規候補）
- `PersistenceCoordinator.swift`（呼び出し確認のみ）
- `WindowManager.swift`（reopen 入力確認のみ）

作業:

1. `RichTextContentCodec` を定義する。
   - `encode(_ attributedString: NSAttributedString) -> Data?`
   - `decode(_ data: Data) -> NSAttributedString?`
   - 装飾なし判定 helper を持つ候補
2. `EditorContentFactory` を定義する。
   - `makeDisplayContent(draft: String, richTextData: Data?) -> NSAttributedString`
   - `richTextData` が `nil` の場合は `draft` から plain attributed string を作る
   - decode 失敗時も `draft` fallback を返す
3. decode 失敗 logging は factory 呼び出し側、または factory の result type で一箇所に集約する。
4. `SQLiteStore` は RTF decode を持たないことを明記する。

Gate:

- decode / fallback の場所が `EditorContentFactory` に固定されている
- RTF decode 失敗時に memo window を開ける
- SQLite layer が RTF の意味を知らない
- `draft` fallback の plain attributed string が editor 表示に使える

### Phase 4: EditorContent Value And Save API

目的:

- editor content を plain text と rich text data の両方で表す value と保存 API を作る。

対象ファイル:

- `EditorContent.swift`（新規候補）
- `RichTextContentCodec.swift`
- `PersistenceCoordinator.swift`
- `SQLiteStore.swift`

作業:

1. `EditorContent` 相当の value type を追加する。
   - `plainText: String`
   - `richTextData: Data?`
2. `NSAttributedString` から `EditorContent` を作る factory を定義する。
3. 装飾なしの場合は `richTextData = nil` にする。
4. `PersistenceCoordinator.saveMemoContent` を追加する。
5. `draft` は `plainText` として必ず保存する。
6. `richTextData` は optional BLOB として保存する。

Gate:

- `EditorContent` が save payload の唯一の型になっている
- `saveMemoContent` が `draft` / `title` / `rich_text_data` を一度に扱う
- `saveDraft` 互換 API がある場合も内部委譲のみで二重経路になっていない
- 空メモ判定は引き続き `plainText` に対して行う

### Phase 5: Window And Autosave Wiring

目的:

- existing window / close / flush / autosave 経路を `EditorContent` payload に切り替える。

対象ファイル:

- `AutosaveScheduler.swift`
- `MemoWindow.swift`
- `MemoWindowController.swift`
- `WindowManager.swift`

作業:

1. `AutosaveScheduler` の payload を `String` から `EditorContent` に変更する。
2. `MemoWindow` は `draft` plain text と display attributed content を同期できる state を持つ。
3. `MemoWindowController` の draft subscription / flush callback を `EditorContent` に切り替える。
4. `WindowManager.persistDraft` 相当を `persistContent` に移行する。
5. close 時 flush / manual save / autosave が同じ save API を使う。

Gate:

- autosave 経路が一本化されている
- manual flush / close flush / explicit save が同じ `EditorContent` save API を使う
- 空メモ auto delete が `plainText` 基準で従来通り動く
- `contentEditedAt` は本文または rich text data 変更時だけ更新される

### Phase 6: Attribute Ownership And Smart Links Boundary

目的:

- 永続化する rich text attributes と Smart Links の temporary attributes を分離する。

対象ファイル:

- `CheckableTextView.swift`
- `RichTextContentCodec.swift`
- `SmartLinkDetector` 周辺

作業:

1. RTF 保存対象 attributes を明文化する。
   - 保存対象: bold / italic trait、`.strikethroughStyle`, `.backgroundColor`
   - 直接信頼しない対象: `.font` の family / size
   - 非保存対象: Smart Link hover 用 `.underlineStyle`, `.foregroundColor`
2. RTF に `.font` が含まれる場合でも、decode 後に current editor base font + persisted traits へ正規化する。
3. encode 前に editor base font size / family を永続意味として扱わないよう、bold / italic trait だけを抽出する方針を固定する。
4. Smart Links は保存された attributed string へ temporary attributes として重ねる。
5. hover styling は `layoutManager` temporary attributes に限定し、`textStorage` へ永続書き込みしない。
6. refresh order を固定する。
   - rich text content を textStorage に反映
   - current editor base font + traits normalization
   - Smart Links detection
   - link temporary attributes apply
   - hover temporary attributes apply
7. RTF encode 前に temporary-only attributes が混入しないことを確認する。

Gate:

- URL hover / underline が RTF data に保存されない
- 保存済み太字 / ハイライトと Smart Links 表示が共存する
- link hover を動かしても autosave が発火しない
- Smart Links の open / copy / hover behavior が regression しない
- editor font size setting を変更すると、既存 rich text の本文サイズも現在設定へ追従する
- RTF 内の font family / size をそのまま UI 表示の SSOT にしない
- bold / italic は current editor base font の trait として復元される

### Phase 7: Attributed Editor Binding Conversion

目的:

- editor を `String` binding から attributed content input/output に移行する。

対象ファイル:

- `MemoWindow.swift`
- `MemoEditorView.swift`
- `CheckableTextView.swift`
- `EditorTextOperations.swift`

作業:

1. `MemoWindow` が editor 表示用 attributed content を持つ方法を定義する。
2. `CheckableTextView` の `text: Binding<String>` を rich text 対応 binding へ置き換える。
3. `textView.isRichText = false` 前提を見直す。
4. `textStorage` の attributed string 変更を SwiftUI / autosave 経路へ戻す。
5. checkbox / date / datetime は plain text mutation として継続し、実行後に attributed content と `plainText` が同期するようにする。

Gate:

- 通常入力、日本語 IME、undo / redo が動く
- checkbox toggle と date insert が動く
- font size setting が editor に反映される
- `draft` と rich text content の plain string が常に一致する
- Smart Links の表示 / hover が regression していない

### Phase 8: Markdown Marker Decoration Removal

目的:

- Markdown marker insertion / parser / temporary decoration を rich text editor から切り離す。

対象ファイル:

- `CheckableTextView.swift`
- `EditorTextOperations.swift`
- `docs/roadmap/plan-markdown-lite-editor.md`（必要に応じて更新）
- `docs/roadmap/plan-markdown-selection-toolbar.md`（必要に応じて更新）

作業:

1. selection formatting から `wrapSelection(prefix:suffix:)` 呼び出しを撤去する。
2. `**` / `*` / `~~` / `==` / `> ` を挿入する toolbar action を無効化または削除する。
3. Markdown inline parser による `.font` / `.backgroundColor` / `.strikethroughStyle` temporary attributes を撤去する。
4. `☑` completed line decoration を残すか、rich text checkbox 方針へ移すかを明確化する。
5. docs 側で Markdown selection toolbar が後続実装の本線ではないことを追記する。

Gate:

- selection formatting で Markdown marker が本文へ入らない
- 既に本文にある `**` / `==` などは通常文字として扱われる
- completed checkbox line の表示仕様が明確
- Smart Links temporary attributes と Markdown cleanup が競合しない

### Phase 9a: Attribute Edit Autosave And Undo Probe

目的:

- toolbar / shortcut wiring の前に、選択範囲への attribute-only edit が autosave / undo できることを単独で確認する。

対象ファイル:

- `CheckableTextView.swift`
- 必要に応じて `RichTextOperations.swift`（新規候補）

作業:

1. 一時的な internal command または context menu command で、選択範囲に 1 種類の attribute を apply / remove する。
2. toolbar overlay はまだ作らない。
3. shortcut はまだ追加しない。
4. attribute-only edit は `textStorage.beginEditing()` / `endEditing()` でまとめる。
5. `shouldChangeText(in:replacementString:)` に依存しない属性変更用の change path を用意する。
6. `undoManager` に formatting undo grouping を登録し、1 action = 1 undo step にする。
7. attribute-only edit 後に `EditorContent` を再抽出し、autosave を明示的に schedule する。
8. IME marked text 中は formatting を実行しない。

Gate:

- 選択した `サンプル` が `サンプル` のまま 1 種類の装飾を持てる
- 文字列が変わらない attribute-only edit でも autosave される
- relaunch 後も probe 用装飾が復元される
- probe 用装飾を undo / redo できる
- IME marked text 中は formatting を実行しない

### Phase 9b: Native Selection Formatting UX Wiring

目的:

- 太字 / 斜体 / 取り消し線 / ハイライトを toolbar / command surface から native attributed text 操作として使えるようにする。

対象ファイル:

- `CheckableTextView.swift`
- 必要に応じて `RichTextFormattingToolbar.swift`（新規候補）
- `RichTextOperations.swift`（新規候補）
- `EditorCommand.swift`
- `ShortcutsWindowController.swift`（shortcut を追加する場合のみ）

作業:

1. selection toolbar は editor-local `NSView` overlay を基本とする。
2. button click は first responder を奪わず、現在 selection に対して属性を toggle/apply する。
3. 太字は current editor base font + bold trait として toggle する。
4. 斜体は current editor base font + italic trait として toggle する。
5. 取り消し線は `.strikethroughStyle` を toggle する。
6. ハイライトは `.backgroundColor` を toggle する。
7. 本文に `**` / `*` / `~~` / `==` を挿入しない。
8. toolbar click 後も Phase 9a の autosave / undo path を使う。
9. IME marked text 中は toolbar を非表示または disabled にする。

Gate:

- 選択した `サンプル` が `サンプル` のまま太字になる
- 選択した `サンプル` が `サンプル` のまま斜体になる
- 選択した `サンプル` が `サンプル` のまま取り消し線になる
- 選択した `サンプル` が `サンプル` のままハイライトになる
- `**` / `*` / `~~` / `==` が本文へ挿入されない
- app relaunch 後も装飾が復元される
- toolbar click で selection が不自然に消えない
- editor font size setting 変更後も太字 / 斜体が現在サイズで表示される
- first mouse / zero-click input が regression しない

### Phase 10: Quote / Callout Decision

目的:

- 5つ目の機能を残すか、削るか、callout として再設計するか判断する。

対象ファイル:

- `docs/roadmap/plan-rich-text-editor.md`
- 実装する場合のみ `CheckableTextView.swift` / rich text operation 関連ファイル

選択肢:

| 方針 | 内容 | 判断 |
|------|------|------|
| 削除 | toolbar を 4 button にする | 初期推奨 |
| 引用 | paragraph style / indent / left marker で native quote 表現 | 後続候補 |
| callout | 背景 + paragraph spacing + optional left rule | 後続候補 |

Gate:

- ユーザーが機能名を見て用途を理解できる
- 本文に `> ` を挿入しない
- 複数行 selection / 解除 / undo が自然に動く
- 太字 / 斜体 / 取り消し線 / ハイライトの安定性を落とさない

---

## 技術詳細確認

### 責務境界

`SQLiteStore.swift`:

- schema migration
- `draft TEXT` / `rich_text_data BLOB` の読み書き
- RTF decode は持たない。SQLite layer は data を運ぶだけにする。

`PersistenceCoordinator.swift`:

- plain text title 生成
- save API の集約
- save failure / decode fallback などの logging
- RTF decode 自体は持たず、`EditorContentFactory` の結果を受け取る

`MemoWindow.swift`:

- editor 表示用 content state を保持する
- title は `draft` / plain text から生成する

`CheckableTextView.swift`:

- AppKit editor の生成
- selection / focus / IME guard
- `NSTextStorage` への attributed mutation
- toolbar position / visibility
- SwiftUI binding への content update

`EditorTextOperations.swift`:

- checkbox / date / datetime など plain text operation を継続
- Markdown marker wrap は rich text selection formatting では使わない

新規候補 `RichTextOperations.swift`:

- bold / italic / strikethrough / highlight の attributed operation
- `CheckableTextView` の肥大化を避けるため、属性 toggle の純粋ロジックを分離する候補

新規候補 `RichTextContentCodec.swift`:

- RTF encode / decode だけを担当する
- 装飾なし判定を持つ場合も、DB や window state を知らない pure helper に留める
- Smart Link hover など temporary-only attributes は encode 対象にしない
- `.font` の family / size を永続仕様として信頼しない
- encode 前または decode 後に current editor base font + bold / italic traits へ正規化する

新規候補 `EditorContentFactory.swift`:

- `PersistedMemo(draft, richTextData)` から editor 表示用 `NSAttributedString` を作る
- `richTextData == nil` の場合は `draft` から plain attributed string を作る
- RTF decode 失敗時も `draft` fallback を返す
- decode failure を `Result` / diagnostic で呼び出し側へ返し、logging の重複を避ける

### メモリで持つ情報

持つ:

- editor 表示中の `NSAttributedString`
- autosave 用の plain text
- autosave 用の RTF data optional
- toolbar 表示状態 / hovered button / selection rect など transient UI state

持たない:

- toolbar state の persistence
- Markdown AST
- hidden marker map
- cloud sync state
- global formatting palette state

### AppKit / SwiftUI 境界

- SwiftUI は memo window layout、editor hosting、focus token、settings injection を担当する。
- AppKit `NSTextView` は text editing、selection、IME、undo、formatting attributes を担当する。
- SwiftUI state には editor content の結果だけを返し、selection / marked text / toolbar hover は AppKit 側の transient state に閉じる。

### イベント経路

通常入力:

```text
NSTextView input
-> NSTextStorage update
-> textDidChange
-> EditorContent(plainText, richTextData?)
-> MemoWindow state
-> AutosaveScheduler
-> PersistenceCoordinator.saveMemoContent
-> SQLiteStore.upsertContent
```

formatting toolbar:

```text
selection exists
-> editor-local toolbar click
-> RichTextOperations applies attributes to selectedRange
-> NSTextStorage edited attributes notification / explicit editorContentDidChange hook
-> undoManager grouping closes one formatting action
-> EditorContent extraction
-> autosave
```

attribute-only edit:

```text
toolbar click
-> guard hasMarkedText() == false
-> preserve selectedRange
-> textStorage.beginEditing()
-> add/remove attributes
-> textStorage.endEditing()
-> register undo for previous attributed substring
-> restore selectedRange if still valid
-> extract EditorContent
-> schedule autosave explicitly
```

方針:

- attribute-only edit は文字列変更ではないため、`textDidChange` にだけ依存しない。
- `NSTextStorageDelegate` の edited mask または editor-local explicit hook で content change を拾う。
- user action 1 回につき undo step 1 回にまとめる。
- hover / toolbar visibility / Smart Link temporary styling は autosave trigger にしない。

checkbox / date command:

```text
EditorCommand
-> EditorTextOperations plain text edit
-> NSTextStorage replaceCharacters
-> attributes reconciliation for affected range
-> didChangeText
-> autosave
```

### close / reopen / pin / drag の状態遷移

- close / reopen / pin / drag の責務は既存 `WindowManager` / `MemoWindowController` に残す。
- rich text 化で window frame / pin / open state の保存経路は変更しない。
- close 時 flush は autosave と同じ `EditorContent` save API を使う。
- reopen 時は `EditorContentFactory.makeDisplayContent(draft:richTextData:)` を必ず通して `MemoWindow` を生成する。
- decode 失敗時も `EditorContentFactory` が `draft` fallback を返すため、`WindowManager` は decode 分岐を持たない。

### 後続 Phase との衝突確認

- Home / Trash / Session は `draft` を使い続けるため、rich text data を知らなくても動く。
- Search は `draft.localizedCaseInsensitiveContains(query)` を維持する。
- Preview は `MemoTitleFormatter.previewText(from: memo.draft)` を維持する。
- Smart Links は permanent attributes ではなく temporary attributes として扱う。
- Smart Link hover / underline / foreground color は RTF encode 対象にしない。
- RTF 保存対象 attributes は Phase 6 で whitelist 化する。
- font family / size は editor setting を SSOT とし、RTF 内の font attributes は bold / italic trait 抽出に限定する。

---

## 回帰 / 副作用チェック

| 領域 | チェック |
|------|----------|
| Existing Data | 既存 DB のメモが全件開ける |
| Empty Memo | 空メモ auto delete が従来通り動く |
| Autosave | 通常入力、装飾、checkbox、date insert が保存される |
| Attribute Edit | 文字列が変わらない太字 / ハイライト変更でも autosave が走る |
| Relaunch | app relaunch 後に plain text と装飾が復元される |
| Search | Home search が `draft` に対して従来通り動く |
| Preview | Home preview が marker なしの plain text を表示する |
| Title | window title が plain text の first content line から生成される |
| IME | 日本語入力中に selection / marked text が壊れない |
| Undo | typing、formatting、checkbox、date insert が undo できる |
| First Mouse | 非アクティブ window の 1 click edit が壊れない |
| Focus | global shortcut 後のゼロクリック入力が壊れない |
| Smart Links | URL underline / hover / open behavior が壊れない |
| Smart Link Persistence | URL hover / underline / foreground color が RTF data に保存されない |
| Font Setting | rich text 復元後も editor font size setting が本文サイズの SSOT であり続ける |
| Capacity | 装飾なしメモは `rich_text_data = NULL` のまま保存される |

---

## 実機確認項目

- 既存メモを開く
- 新規メモを作る
- 日本語 IME で入力する
- 選択範囲を太字にする
- 選択範囲を斜体にする
- 選択範囲を取り消し線にする
- 選択範囲をハイライトにする
- 装飾済み範囲を再選択して解除する
- 装飾後に app を終了し、再起動して復元を確認する
- 装飾なしメモの `rich_text_data` が不要に保存されないことを確認する
- `Command-L` checkbox toggle を確認する
- checkbox click toggle を確認する
- `Command-D` / `Command-Shift-D` を確認する
- `Command-S` / `Command-Return` / `Command-W` を確認する
- `Command-P` pin を確認する
- global shortcut `Command-Option-Return` 後のゼロクリック入力を確認する
- menu bar から recently closed memo を reopen する
- Home search / preview / trash / restore を確認する

---

## 容量見積もり

方針:

- `draft TEXT` は常に保存する
- `rich_text_data BLOB` は装飾があるメモのみ保存する

概算:

| メモ内容 | 現在の plain text | rich text 化後の合計目安 |
|----------|-------------------|--------------------------|
| 100文字 | 数百 B | 1〜3 KB |
| 1,000文字 | 2〜4 KB | 5〜15 KB |
| 5,000文字 | 10〜20 KB | 20〜60 KB |
| 10,000文字 | 20〜40 KB | 40〜120 KB |

判断:

- オンデバイス memo app として許容範囲。
- 装飾なしメモを `rich_text_data = NULL` にすることで、既存メモの容量増を避ける。
- 容量最適化のために独自 ranges JSON を初期採用しない。まず macOS native と相性の良い RTF data を採用候補とする。

---

## リスク

| ID | 内容 | 対策 |
|----|------|------|
| R-70 | `NSAttributedString` と autosave state が二重化して不整合になる | `EditorContent` を唯一の save payload にする |
| R-71 | RTF decode 失敗でメモが開けない | `EditorContentFactory` に `draft` fallback を一本化する |
| R-72 | 装飾なしメモにも BLOB が保存され容量が増える | 装飾なし判定で `rich_text_data = NULL` にする |
| R-73 | Smart Links の temporary attributes と rich text attributes が競合する | ownership と refresh order を Phase 6 Gate で固定する |
| R-74 | IME marked text 中の attribute mutation が入力を壊す | `hasMarkedText()` guard を維持する |
| R-75 | `CheckableTextView` がさらに肥大化する | rich text operation / toolbar UI を必要に応じて分離する |
| R-76 | attribute-only edit が `textDidChange` を通らず保存されない | explicit content-change hook で autosave を schedule する |
| R-77 | formatting undo が入力 undo と混ざる | user action 単位で undo grouping を作る |
| R-78 | RTF の `.font` family / size が editor setting を上書きする | current editor base font + persisted traits へ正規化する |

---

## セルフチェック結果

### SSOT整合

[n/a: missing] migration README は存在しない。計画内に不在を明記した  
[n/a: missing] 01_product_decision は存在しない。repo 内 `product-vision.md` を参照した  
[n/a: missing] 02_ux_principles は存在しない。repo 内 `ux-principles.md` を参照した  
[n/a: missing] 06_roadmap は存在しない。repo 内 `roadmap.md` を参照した  
[n/a: missing] 07_project_bootstrap は存在しない。repo 内 architecture docs を参照した  
[n/a: missing] 09_seamless_ux_spec は存在しない。focus / first mouse Gate を計画に含めた  
[gate] 実装着手前に migration 文書の復旧有無を再確認する。復旧しない場合は repo-local SSOT で進める明示承認を取る  

### 変更範囲

[x] 主目的は1つ: native rich text selection formatting と保存  
[x] 高リスク疎通確認テーマは Phase 1 の migration probe に分けた  
[x] 引用 / callout は Phase 10 に分離し、ついで作業にしない  

### 技術詳細

[x] ファイルごとの責務が明確  
[x] メモリ管理と persistence の境界が明確  
[x] イベント経路と状態遷移を記述した  
[x] RTF decode / fallback は `EditorContentFactory` に一本化した  
[x] Smart Links attribute ownership を Phase 6 の明示タスクにした  
[x] attribute-only edit の autosave / undo 方針を明記した  
[x] `.font` family / size を永続 SSOT にせず、bold / italic trait と current editor base font へ正規化する方針を明記した  

### Window / Focus

[x] Window 責務は既存 `WindowManager` / `MemoWindowController` に残す  
[x] Focus 制御は AppKit editor の Gate で確認する  
[x] first mouse の扱いを regression check に含めた  

### Persistence

[x] 保存経路は `EditorContent -> AutosaveScheduler -> PersistenceCoordinator -> SQLiteStore` に一本化する  
[x] frame と open 状態の責務は変更しない  
[x] relaunch 時の rich text / fallback 読み込みを定義した  

### 実機確認

[x] global shortcut を確認する  
[x] 1 click 操作を確認する  
[x] ゼロクリック入力を確認する  
