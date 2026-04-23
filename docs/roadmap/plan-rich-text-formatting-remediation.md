# Rich Text Formatting Remediation Plan

作成: 2026-04-23  
ステータス: 計画中（実装済み rich text toolbar の挙動不具合を AppKit 標準編集モデルへ寄せて修正）

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-23 | 初版作成。selection formatting の toggle / italic / strikethrough leak 問題を remediation 計画化 |

---

## SSOT参照宣言

本計画は以下を上位文書として扱う。

- `docs/roadmap/stickynative-ai-planning-guidelines.md`
- `docs/product/product-vision.md`
- `docs/product/ux-principles.md`
- `docs/product/current-feature-summary.md`
- `docs/architecture/technical-decision.md`
- `docs/architecture/persistence-boundary.md`
- `docs/roadmap/plan-rich-text-editor.md`
- `docs/roadmap/plan-smart-links.md`
- `docs/roadmap/plan-smart-link-hover-feedback.md`
- Apple Developer Documentation: `NSTextView`, `NSText`, `typingAttributes`, `NSFontManager`

`docs/roadmap/stickynative-ai-planning-guidelines.md` では `/Users/hori/Desktop/Sticky/migration/*` を SSOT として参照するよう定義されているが、2026-04-23 時点の作業環境では `/Users/hori/Desktop/Sticky/migration` が存在しない。  
したがって、本計画では repo 内 docs と現行実装を暫定 SSOT とする。migration 文書が復旧した場合は、実装前または次回計画更新時に再照合する。

### SSOT整合メモ

- `product-vision.md`: 入力速度と復帰速度を優先する。装飾機能は editor の基本入力を不安定にしてはならない。
- `ux-principles.md`: macOS native の自然さを優先する。独自 text mutation で標準挙動から外れる場合は理由が必要。
- `technical-decision.md`: text editing / focus は AppKit を活用する。rich text 操作は `NSTextView` / text system の user action model に乗せる。
- `plan-rich-text-editor.md`: 保存形式と sanitizer は維持する。本計画は editor 操作層の remediation に限定する。
- Smart Links 計画: link hover / underline は `layoutManager` temporary attributes として扱い、永続 attributes と混ぜない。

---

## 背景

現行 rich text toolbar は Markdown marker 挿入をやめ、`NSAttributedString` attributes を直接変更する方向に移行した。しかし、実装は `CheckableTextView` 内で `textStorage.addAttribute` / `removeAttribute` を直接呼ぶ自前 toggle になっており、AppKit の rich text editing model から外れている。

ユーザー確認で以下の不具合が出ている。

- 一度文字に装飾を入れると、選択中に同じ装飾を押しても解除されない
- 斜体が見た目として反映されない
- 取り消し線を押すと、それ以降に入力する文字にも取り消し線が入る
- 同様の未検出不具合が他にもあり得る

調査上の主因は、attribute mutation 後の `typingAttributes` 整理、user attribute change range、undo grouping、selection restore、font trait conversion を AppKit 標準経路に寄せていないこと。

---

## 今回触る関連ファイル

| ファイル | 扱い |
|----------|------|
| `StickyNativeApp/CheckableTextView.swift` | toolbar action entry point / `NSTextView` integration を修正 |
| `StickyNativeApp/RichTextOperations.swift` | 新規候補。attribute toggle の純粋操作と range mutation を分離 |
| `StickyNativeApp/EditorCommand.swift` | keyboard shortcut と formatting command の責務整理が必要な場合のみ |
| `StickyNativeApp/EditorTextOperations.swift` | checkbox / date / datetime の plain text operation は維持 |
| `StickyNativeApp/RichTextContentCodec.swift` | 保存 sanitizer は原則変更しない。必要なら Gate 確認のみ |
| `StickyNative.xcodeproj/project.pbxproj` | 新規 Swift file を追加する場合のみ |

---

## 問題一覧

| ID | 種別 | 問題 | 影響 | 対応 Phase |
|----|------|------|------|------------|
| A-90 | Architecture | `CheckableTextView` が toolbar UI、range 判定、attribute mutation、typing attributes、temporary decoration を一箇所で抱えている | 挙動修正が局所化できず、追加バグを生みやすい | Phase 1 |
| U-91 | UI | 同じ装飾を再度押しても解除されない | 一般的 editor の toggle 期待に反する | Phase 2a, Phase 2b |
| U-92 | UI | italic が反映されない | 装飾機能として成立しない | Phase 2b |
| U-93 | UI | strikethrough が後続入力へ漏れる | editor の通常入力を壊す | Phase 2a |
| A-94 | AppKit | attribute change が `NSTextView` の user character attribute change model に乗っていない | undo / IME / selection / typing attributes が不安定 | Phase 1, Phase 2a, Phase 2b |
| U-95 | UI | quote が inline attributes と同じ toolbar group にあり、機能意味が曖昧 | 実装とユーザー期待がズレる | Phase 3 |
| P-96 | Persistence | temporary attributes や unsupported font traits が保存に混ざる可能性 | reopen 後に表示が崩れる | Phase 4 |

---

## 修正方針

### 基本方針

`NSTextView` を rich text editor の front-end として扱い、toolbar action は以下の順に処理する。

1. `NSTextView` から user attribute change target range を取得する。
   - Phase 2 では multi selection を正式対応しない。
   - `rangesForUserCharacterAttributeChange` が複数 range を返す場合は no-op に固定し、挙動を result doc に記録する。
   - 複数 range を正式対応する場合は別 Phase とし、`shouldChangeText(inRanges:replacementStrings:)`、multi-range mutation plan、selection restore を同時に設計する。
2. 選択中の attributes を読み、toggle の apply/remove を決める。
3. `shouldChangeText(in:replacementString:)` を通す。
4. undo grouping と `textStorage.beginEditing()` / `endEditing()` の中で attribute mutation を行う。
5. `typingAttributes` を明示更新する。
   - non-empty selection の toolbar action 後は selection を維持しつつ、次の通常入力に strikethrough / highlight / quote background を漏らさない typing attributes に戻す。
   - bold / italic は typing style として継続してよい。
   - strikethrough / highlight / quote background は selection decoration として扱い、typing style として継続させない。
   - font は current editor base font + selection 先頭の bold / italic traits を許容する。
   - selection が collapsed している場合のみ、caret 位置の intended typing style を採用する。
6. selection を復元する。
7. `didChangeText()` により autosave / SwiftUI binding へ通知する。

### 一般的な AppKit 実装との差分を埋める箇所

- `selectedRange()` 直読みだけでなく、character attributes は `rangeForUserCharacterAttributeChange` を優先する。
- Phase 2 では multi-range を非対応にし、`rangesForUserCharacterAttributeChange` は複数 range 検出と将来拡張の確認に留める。
- paragraph/block attributes は character attributes と混ぜない。
- font trait は `NSFontManager.convert(_:toHaveTrait:)` / `convert(_:toNotHaveTrait:)` を使い、変換不能時の fallback を明示する。
- `typingAttributes` は attribute action 後に必ず更新する。
- `textStorage` を enumerate しながら同じ storage を mutate しない。先に effective ranges と attributes を収集し、後で mutate する。

---

## 修正フェーズ

### Phase 0: Formatting Probe And Reproduction Notes

目的:

- 現状不具合を実機で再現し、修正前 baseline を文書化する。

対象ファイル:

- `docs/roadmap/plan-rich-text-formatting-remediation-result.md`（新規）

作業:

1. 実アプリで以下を確認する。
   - bold toggle on/off
   - italic toggle on/off
   - strikethrough toggle on/off
   - strikethrough 後の通常入力
   - highlight toggle on/off
   - mixed selection の toggle
   - undo / redo
   - 日本語 IME 入力中の toolbar 非表示 / no-op
2. 確認結果を `plan-rich-text-formatting-remediation-result.md` に記録する。
3. probe 用コードは追加しない。必要なら一時ログだけに留め、コミットしない。

Gate:

- 少なくともユーザー報告の 3 問題を再現済みまたは再現不能として記録している
- 修正後比較に使える操作手順が残っている
- 本実装と probe が混ざっていない

### Phase 1: RichTextOperations Boundary

目的:

- attribute mutation の責務を `CheckableTextView` から分離し、AppKit user action model に合わせる土台を作る。

対象ファイル:

- `RichTextOperations.swift`（新規候補）
- `CheckableTextView.swift`
- `StickyNative.xcodeproj/project.pbxproj`（新規 file 追加時のみ）

作業:

1. `RichTextFormattingAction` を定義する。
   - bold
   - italic
   - strikethrough
   - highlight
2. quote は Phase 1 の対象外にする。
3. `RichTextOperations` に以下の責務を持たせる。
   - target ranges の解決補助
   - selection attributes の state 判定
   - mutation plan の生成
   - font trait add/remove
   - typing attributes 更新用 attributes の生成
4. `CheckableTextView` は action dispatch と `NSTextView` integration だけを担当する。
5. 既存の `toggleFontTrait` / `toggleAttribute` 直書き helper を移動または削除する。

Gate:

- `CheckableTextView` 内に font trait / strikethrough / highlight の詳細 mutation が残っていない
- `RichTextOperations` は Smart Links temporary attributes を扱わない
- quote はまだ修正対象に含めない
- build が通る

### Phase 2a: Typing Attributes Leak And Undo Path

目的:

- strikethrough / highlight が後続入力へ漏れる問題を先に潰し、undo / notification 経路を固定する。

対象ファイル:

- `RichTextOperations.swift`
- `CheckableTextView.swift`

作業:

1. toolbar action 時に `rangeForUserCharacterAttributeChange` を使う。
2. `rangesForUserCharacterAttributeChange` が複数 range を返す場合は、Phase 2a では no-op とし、result doc に記録する。
3. target range が空または `NSNotFound` の場合は toolbar action を no-op にする。
4. strikethrough / highlight:
   - 全 range が対象 attribute を持つ場合は remove
   - それ以外は apply
5. mutation 後の `typingAttributes` ルールを固定する。
   - non-empty selection action 後は selection を維持する。
   - `typingAttributes` から `.strikethroughStyle` と `.backgroundColor` を必ず除去する。
   - `.font` は editor base font + selection 先頭の bold / italic traits に正規化する。
   - bold / italic は「次に入力する文字へ続いてよい typing style」として扱う。
   - strikethrough / highlight / quote background は「選択範囲だけに付く decoration」として扱い、次の通常入力へ継続させない。
   - `.foregroundColor`, `.underlineStyle`, Smart Link temporary attrs は入れない。
6. undo grouping を明示する。
7. selection を復元する。
8. `didChangeText()` による autosave / SwiftUI binding notification が 1 回にまとまることを確認する。

Gate:

- strikethrough を押した直後に selection 外へ caret を移して入力しても後続文字へ漏れない
- highlight を押した直後に selection 外へ caret を移して入力しても後続文字へ漏れない
- strikethrough / highlight は同じ選択でもう一度押すと解除される
- undo / redo が 1 action 単位で動く
- IME marked text 中は formatting action が no-op
- multi-range selection は no-op として result doc に記録されている
- build が通る

### Phase 2b: Font Trait Toggle And Mixed Selection

目的:

- bold / italic の font trait conversion と mixed selection toggle を安定させる。

対象ファイル:

- `RichTextOperations.swift`
- `CheckableTextView.swift`

作業:

1. 既存 attributes を先に snapshot し、mutation 中に enumerate 対象を変更しない。
2. bold / italic:
   - 全 range が trait を持つ場合は remove
   - それ以外は apply
   - remove は `convert(_:toNotHaveTrait:)` を優先する
   - italic 変換不能時は fallback を定義し、少なくとも state 判定と保存が破綻しないようにする
3. mixed selection toggle のルールを固定する。
   - 対象 range 全体が trait を持つ場合は remove
   - 一部でも trait がない場合は range 全体へ apply
4. mutation 後の `typingAttributes` は Phase 2a のルールを継続する。
5. bold / italic 後に通常入力しても、selection action 由来の unexpected style が漏れないことを確認する。

Gate:

- 同じ装飾を再度押すと解除される
- italic が見た目として反映される、または変換不能 fallback の理由が記録されている
- mixed selection が定義通り apply/remove される
- bold / italic の undo / redo が 1 action 単位で動く
- IME marked text 中は formatting action が no-op
- build が通る

### Phase 3: Quote Decision

目的:

- 5つ目の toolbar action を残すか、削除 / 置換するか決める。

対象ファイル:

- `CheckableTextView.swift`
- 必要なら `docs/roadmap/plan-rich-text-editor.md`

選択肢:

1. quote を削除する。
   - 最小で安全
   - 「5つあるはず」という前提は崩れる
2. quote を装飾解除に置き換える。
   - 一般的 editor として分かりやすい
   - toolbar 5 action を維持できる
3. quote を paragraph style として再実装する。
   - block quote として意味は通る
   - paragraph style / multi-line / persistence / UI 表示が絡むため重い

推奨:

- Phase 3 では quote を一旦 toolbar から外す、または clear formatting に置換する。
- paragraph quote は別計画に分離する。

Gate:

- 5つ目の action の意味が明文化されている
- inline character attribute と paragraph style が混ざっていない
- toolbar tooltip と実挙動が一致している

### Phase 4: Persistence And Smart Links Regression

目的:

- 修正後の editor attributes が保存 / reopen / Smart Links と衝突しないことを確認する。

対象ファイル:

- `RichTextContentCodec.swift`（原則確認のみ）
- `CheckableTextView.swift`
- `docs/roadmap/plan-rich-text-formatting-remediation-result.md`

作業:

1. 装飾あり memo を保存して reopen する。
2. 装飾なし memo で `rich_text_data = NULL` が維持されることを確認する。
3. Smart Links hover / underline / open / copy が regression していないことを確認する。
4. Smart Links hover だけで autosave が走らないことを確認する。
5. `RichTextContentCodec` sanitizer が unsupported font family / size を永続意味として残さないことを確認する。

Gate:

- 保存済み bold / italic / strikethrough / highlight が reopen 後も復元される
- temporary Smart Link attrs が RTF に保存されない
- unsupported font family / size が UI 表示の SSOT にならない
- build が通る
- 実機確認結果が result doc に残っている

---

## Gate条件まとめ

- G-01: ユーザー報告の 3 問題が再現手順付きで記録されている
- G-02: attribute mutation は `CheckableTextView` 直書きから `RichTextOperations` へ分離されている
- G-03: character attribute action は AppKit の single user attribute change range を使う
- G-04: multi-range selection は Phase 2 では no-op として明示記録されている
- G-05: formatting action 後に `typingAttributes` が明示更新される
- G-06: non-empty selection action 後の `typingAttributes` に `.strikethroughStyle` / `.backgroundColor` / Smart Link temporary attrs が残らない
- G-07: textStorage を enumerate しながら同じ storage を mutate しない
- G-08: bold / italic / strikethrough / highlight は on/off toggle できる
- G-09: strikethrough / highlight が後続入力に漏れない
- G-10: undo / redo が action 単位で動く
- G-11: IME marked text 中は formatting action が no-op
- G-12: Smart Links temporary attributes と persistence が衝突しない

---

## 回帰 / 副作用チェック

### Editor

- 通常入力
- 日本語 IME
- selection drag
- toolbar click 後の selection 維持
- undo / redo
- copy / paste
- select all
- checkbox toggle
- date insert
- datetime insert

### Rich Text

- bold on/off
- italic on/off
- strikethrough on/off
- highlight on/off
- mixed selection toggle
- decoration after reopen
- plain memo capacity path (`rich_text_data = NULL`)

### Smart Links

- URL detection
- hover underline / color
- open link
- copy link
- hover only no autosave

### Window / Focus

- nonactivating first mouse
- toolbar click does not clear selection before action
- close flush
- reopen last closed memo
- app relaunch open memo restore

---

## 実機確認項目

1. 新規 memo に `サンプル` と入力し、文字を選択して bold を押す。
2. 同じ選択のまま bold をもう一度押し、解除されることを確認する。
3. italic で同じ確認を行う。
4. strikethrough を押し、解除できることを確認する。
5. strikethrough 後に selection を解除して通常文字を入力し、後続文字に取り消し線が漏れないことを確認する。
6. highlight で同じ漏れ確認を行う。
7. strikethrough / highlight 後、同じ選択を維持したまま selection 外へ caret を移して入力しても漏れないことを確認する。
8. mixed selection で toggle し、期待する apply/remove になることを確認する。
9. multi-range selection が発生する環境では no-op の記録と一致することを確認する。
10. undo / redo を各 action で確認する。
11. 日本語 IME composition 中に toolbar が action しないことを確認する。
12. URL を含む memo で Smart Links が従来通り動くことを確認する。
13. 装飾あり memo を保存し、アプリ再起動後も復元されることを確認する。

---

## 技術詳細確認

### 責務配置

`CheckableTextView.swift`:

- `NSTextView` subclass と SwiftUI bridge
- toolbar 表示 / click dispatch
- AppKit event lifecycle (`shouldChangeText`, `didChangeText`, selection restore)
- Smart Links temporary attributes
- checkbox click routing

`RichTextOperations.swift`:

- rich text formatting action enum
- target range snapshot / effective range collection
- toggle state 判定
- font trait add/remove
- strikethrough / highlight add/remove
- typing attributes 更新用 dictionary の生成

`RichTextContentCodec.swift`:

- persistence sanitizer / display normalization
- editor 操作中の live mutation は担当しない

### メモリで持つ情報

持つ:

- editor 表示中の `NSAttributedString`
- current selection range
- toolbar hover state
- Smart Link detected ranges
- temporary hover attributes

持たない:

- toolbar action 用の別 shadow attributed string
- Smart Link hover attributes as persistent content
- paragraph quote state（Phase 3 決定前）

### AppKit / SwiftUI 境界

- AppKit: text selection, text mutation, typing attributes, undo, IME, temporary attributes
- SwiftUI: memo model binding, view composition, settings propagation
- SwiftUI update が `setAttributedString` を乱発しないよう、AppKit 側 mutation 中の再入を避ける必要がある

### イベント経路

Toolbar click:

1. `CheckboxNSTextView.mouseDown`
2. `MarkdownSelectionToolbar.handleClick`
3. `CheckboxNSTextView.performFormattingAction`
4. AppKit single target range を解決する
   - Phase 2 では multi-range は no-op
   - multi-range 正式対応時は `shouldChangeText(inRanges:replacementStrings:)` 経路を別 Phase で設計する
5. `RichTextOperations` で mutation plan 作成
6. `NSTextView.shouldChangeText(in:replacementString:)`
7. `NSTextStorage` mutation
8. `typingAttributes` 更新
   - bold / italic は typing style として残してよい
   - non-empty selection action 後は `.strikethroughStyle` / `.backgroundColor` / Smart Link temporary attrs を落とす
9. selection restore
10. `NSTextView.didChangeText`
11. `Coordinator.textDidChange`
12. `MemoWindow.attributedContent`
13. autosave

Keyboard command / checkbox / date:

- 既存 `EditorCommand` / `EditorTextOperations` 経路を維持する。
- rich text formatting keyboard shortcut を追加する場合は、toolbar action と同じ `performFormattingAction` に合流させる。

### Persistence との衝突

- `RichTextContentCodec` sanitizer は保存境界で維持する。
- editor 操作中に temporary attributes を persistent attributed string へ入れない。
- quote を paragraph style として実装する場合は、RTF sanitizer の保存対象拡張が必要なので別 Phase / 別計画にする。

---

## MECE 検査

### Issue → Phase 対応

- A-90: Phase 1
- U-91: Phase 2a, Phase 2b
- U-92: Phase 2b
- U-93: Phase 2a
- A-94: Phase 1, Phase 2a, Phase 2b
- U-95: Phase 3
- P-96: Phase 4

### Phase → Issue 対応

- Phase 0: U-91, U-92, U-93 baseline
- Phase 1: A-90, A-94
- Phase 2a: U-91, U-93, A-94
- Phase 2b: U-91, U-92, A-94
- Phase 3: U-95
- Phase 4: P-96

---

## セルフチェック結果

### SSOT整合

[n/a: missing] migration README を確認した  
[n/a: missing] 01_product_decision を確認した  
[n/a: missing] 02_ux_principles を確認した  
[n/a: missing] 06_roadmap を確認した  
[n/a: missing] 07_project_bootstrap を確認した  
[n/a: missing] 09_seamless_ux_spec を確認した  
[x] repo-local docs を確認した  
[x] AppKit docs の relevant APIs を確認した  

### 変更範囲

[x] 主目的は rich text formatting remediation に限定している  
[x] persistence schema は変更しない  
[x] window lifecycle は変更しない  
[x] quote は別判断に分離した  

### 技術詳細

[x] ファイルごとの責務が明確  
[x] AppKit / SwiftUI 境界が明確  
[x] イベント経路を説明している  
[x] persistence / Smart Links との衝突確認を Gate 化している  

### Window / Focus

[x] first mouse / selection 維持を regression check に入れた  
[x] IME marked text を Gate に入れた  
