# Rich Text Formatting Toolbar Simplification Plan

作成: 2026-04-23  
ステータス: 計画中（toolbar を 4 機能へ整理し、underline 追加と highlight feedback を改善）

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-23 | 初版作成。selection formatting の toggle / italic / strikethrough leak 問題を remediation 計画化 |
| 2026-04-23 | 方針変更。italic / clear formatting を削除し、bold / underline / strikethrough / highlight の 4 action に整理する計画へ更新 |

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

`docs/product/mvp-scope.md` は SSOT 補助文書として存在するが、今回の toolbar remediation は既存 MVP 機能の修正であり新規スコープを追加しない。スコープ判断に影響しないため本計画では参照対象から除外する。

### SSOT整合メモ

- `product-vision.md`: 入力速度と復帰速度を優先する。装飾 toolbar は小さく、迷わず使える機能だけにする。
- `ux-principles.md`: macOS native の自然さを優先する。選択中の装飾 feedback が曖昧な場合は UI state で補助する。
- `technical-decision.md`: text editing / focus は AppKit を活用する。rich text 操作は `NSTextView` / text system の user action model に乗せる。
- `plan-rich-text-editor.md`: `draft TEXT + rich_text_data BLOB`、`RichTextContentCodec` sanitizer、Smart Links temporary attrs の所有境界は維持する。
- Smart Links 計画: link hover / underline は `layoutManager` temporary attributes として扱い、永続 underline と混ぜない。

---

## 背景

現行 toolbar は `bold / italic / strikethrough / highlight / clearFormatting` の 5 action になっている。

ユーザー確認で以下が判明した。

- `clearFormatting` は機能が分かりにくく、実際にも効いているか判断しづらい
- italic は見た目として反映されているか分かりづらく、このメモ用途では価値が薄い
- highlight は `.backgroundColor` で実装しているため、selection background に上書きされ、押した直後に本当に marker が入ったか分かりにくい
- toolbar に置くなら、機能は `bold / underline / strikethrough / highlight` の 4 つが自然

本計画では italic と clear formatting を削除し、underline を新規追加する。highlight は selection 中でも状態が分かるよう toolbar active state を入れる。

---

## 今回触る関連ファイル

| ファイル | 扱い |
|----------|------|
| `StickyNativeApp/CheckableTextView.swift` | toolbar action 定義、button 数、active state、selection state 更新 |
| `StickyNativeApp/RichTextOperations.swift` | underline action 追加、italic / clear formatting 削除 |
| `StickyNativeApp/RichTextContentCodec.swift` | persistent underline を sanitizer 保存対象に追加 |
| `docs/roadmap/plan-rich-text-formatting-remediation-result.md` | 実装結果と実機確認を追記 |

---

## 問題一覧

| ID | 種別 | 問題 | 影響 | 対応 Phase |
|----|------|------|------|------------|
| U-101 | UI | italic が視認しづらく、機能価値が低い | toolbar の理解コストが増える | Phase 1a |
| U-102 | UI | clear formatting が効いているか分かりづらく、mini toolbar に置く必然性が弱い | 不要な 5 つ目の action が残る | Phase 1a |
| U-103 | UI | underline がない | 一般的な軽量装飾として不足している | Phase 1b, Phase 2 |
| A-104 | Architecture | underline は Smart Links temporary underline と所有境界が衝突し得る | URL hover / link 表示と永続 underline が混ざる | Phase 2, Phase 4 |
| U-105 | UI | highlight が selection background に隠れて、適用直後の feedback が弱い | 押した結果が分かりづらい | Phase 3 |
| P-106 | Persistence | underline を保存対象に追加しないと reopen 後に消える | rich text 保存の不整合 | Phase 2, Phase 4 |

---

## 新しい Toolbar 仕様

toolbar action は以下の 4 つに固定する。

| 表示 | action | persistent attribute | 備考 |
|------|--------|----------------------|------|
| 太字 | `bold` | `.font` bold trait | 既存維持 |
| 下線 | `underline` | `.underlineStyle` | 新規追加。Smart Links temporary underline とは別扱い |
| 取り消し線 | `strikethrough` | `.strikethroughStyle` | 既存維持 |
| マーカー | `highlight` | `.backgroundColor` | 既存維持。active state を追加 |

削除する action:

- `italic`
- `clearFormatting`

理由:

- italic は日本語・小さいメモ UI で視認性が弱く、ユーザー価値が低い
- clear formatting は mini toolbar では意味が曖昧で、必要なら将来 context menu に分離する
- 4 action にすることで toolbar の横幅、理解コスト、検証範囲を下げる

既存 italic data の扱い:

- 既存 `rich_text_data` に italic trait が含まれる場合、表示互換のため decode / display では維持する。
- toolbar からは新規 italic を作れない。
- 再保存時も sanitizer は italic trait をただちに落とさない。既存メモを開いただけで見た目が変わることを避ける。
- 将来 italic を完全削除する場合は、別 migration / cleanup 計画で扱う。

---

## 修正方針

### AppKit Editing 方針

- `rangeForUserCharacterAttributeChange` を使う
- multi-range は no-op に固定する
- `shouldChangeText(in:replacementString:)` を通す
- `textStorage` を enumerate しながら同じ storage を mutate しない
- toolbar action 後は selection を維持する
- `typingAttributes` から `.strikethroughStyle`, `.backgroundColor`, `.underlineStyle`, Smart Link temporary attrs を落とす
- bold は typing style として継続してよい
- underline / strikethrough / highlight は selection decoration として扱い、次の通常入力へ継続させない

### Smart Links / Underline 所有境界

- 永続 underline は `textStorage` の `.underlineStyle`
- Smart Links の underline は `layoutManager` temporary attributes
- Smart Links refresh は persistent attributes を消さない
- RTF encode は persistent underline を保存する
- RTF encode は Smart Links temporary underline / foreground color を保存しない

### Highlight Feedback 方針

selection 中は `.backgroundColor` が selection background に隠れるため、highlight action の結果は toolbar button active state で示す。

採用方針:

- selection は維持する
- toolbar button に active state を出す
- active 判定は selection range 全体が対象 attribute を持つかどうか
- mixed selection の場合は inactive とする

採用しない方針:

- action 後に selection を勝手に解除する
- marker の色を selection 上に無理に重ねる
- highlight 専用 overlay を text layout 上に追加する

### seamless UX への影響

toolbar formatting 自体は低リスクだが、`typingAttributes` 操作・selection restore のタイミング誤りがゼロクリック入力や first mouse 挙動に干渉する可能性がある。

- `typingAttributes` cleanup は toolbar action 後のみ実行し、通常入力中は変更しない
- selection restore は AppKit user action model に乗せ、UI 側で再設定しない
- first mouse / nonactivating window 挙動は Phase 4 regression チェックで確認する

### 後続フェーズへの影響

toolbar は `CheckableTextView.swift` 内の SwiftUI / AppKit 境界に限定した変更であり、Home / Trash / Session の UI コンポーネントには直接影響しない。Phase 4 で toolbar rendering の変更が他 View に伝播していないことを確認する。

---

## 修正フェーズ

### Phase 0: Current State Check

目的:

- 現在の toolbar 挙動と削除対象を記録する。

対象ファイル:

- `docs/roadmap/plan-rich-text-formatting-remediation-result.md`

作業:

1. `italic` が UI 価値として低いことを記録する。
2. `clearFormatting` を toolbar から外す判断を記録する。
3. highlight selection feedback の問題を記録する。

Gate:

- 削除対象と理由が result doc に残っている
- DB / persistence schema は変更しない方針が明記されている

### Phase 1a: italic / clearFormatting 削除

目的:

- toolbar から `italic` と `clearFormatting` を削除し、削除テーマを単独で確定する。

対象ファイル:

- `CheckableTextView.swift`
- `RichTextOperations.swift`

作業:

1. `MarkdownSelectionAction` から `italic` と `clearFormatting` を削除する。
2. `RichTextFormattingAction` から `italic` と `clearFormatting` を削除する。
3. `RichTextOperations` の mutation switch から `italic` / `clearFormatting` を除去する。

Gate:

- italic icon が出ない
- clear formatting icon が出ない
- build が通る

### Phase 1b: underline Slot / Enum 追加

目的:

- toolbar に `underline` の slot を追加し、4 action 構成を確定する。実動作・永続化は Phase 2 で行う。

対象ファイル:

- `CheckableTextView.swift`
- `RichTextOperations.swift`

作業:

1. `MarkdownSelectionAction` に `underline` を追加する。
2. toolbar preferred width を 4 buttons 前提に調整する。
3. `RichTextFormattingAction.underline` を追加する。
4. `RichTextOperations` の mutation switch に `underline` の stub を追加する（no-op。実動作は Phase 2）。

Gate:

- toolbar は 4 buttons のみ
- underline の slot / action enum が存在する
- ただし永続化確認は Phase 2 で行う
- build が通る

### Phase 2: Persistent Underline

目的:

- underline を editor 操作、autosave、RTF reopen まで一貫して扱う。

対象ファイル:

- `RichTextOperations.swift`
- `RichTextContentCodec.swift`
- `CheckableTextView.swift`

作業:

1. 保存前の editor 操作として `RichTextOperations` に `.underlineStyle` toggle を追加する。
2. 保存前に underline on/off と typing leak が単体で動くことを確認する。
3. `typingAttributes` から `.underlineStyle` を action 後に落とす。
4. `RichTextContentCodec.hasPersistableAttributes` に `.underlineStyle` を追加する。
5. `RichTextContentCodec.sanitizedAttributedString` が `.underlineStyle` を保存対象としてコピーする。
6. 保存 / reopen で underline が残ることを確認する。
7. Smart Links の temporary underline が persistent underline と別であることを確認する。

Gate:

- underline を押すと選択範囲に下線が付く
- 同じ選択でもう一度押すと下線が外れる
- underline 後に通常入力しても下線が漏れない
- 上記 3 点は codec 保存確認前に単体で通る
- underline は保存 / reopen 後も残る
- 既存 italic rich text は表示互換として維持され、新規 toolbar からは作れない
- Smart Links hover underline / color が保存対象に混ざらない
- multi-range selection では formatting action が no-op になる（G-08）
- IME marked text 中は formatting action が no-op になる（G-09）
- build が通る

### Phase 3: Toolbar Active State

目的:

- selection 中でも highlight / bold / underline / strikethrough の適用状態が分かるようにする。

対象ファイル:

- `CheckableTextView.swift`

作業:

1. toolbar に active actions を渡せる state を追加する。
2. `CheckboxNSTextView.refreshSelectionToolbar()` 時に selection attributes を読む。
3. action ごとの active 判定を定義する。
   - bold: selection 全体が bold trait
   - underline: selection 全体が `.underlineStyle`
   - strikethrough: selection 全体が `.strikethroughStyle`
   - highlight: selection 全体が `.backgroundColor`
4. active button は hover とは別の背景 / tint にする。
5. mixed selection は inactive とする。

Gate:

- highlight を押した直後、selection が残っていても marker button が active になる
- active state と hover state が競合しない
- selection を変えると active state が更新される
- toolbar click で selection が失われない
- build が通る

### Phase 4: Regression And Persistence Check

目的:

- 4 action 化と underline 追加が既存挙動を壊していないことを確認する。

対象ファイル:

- `docs/roadmap/plan-rich-text-formatting-remediation-result.md`

作業:

1. bold / underline / strikethrough / highlight の on/off を確認する。
2. highlight active state を確認する。
3. underline と Smart Links が共存することを確認する。
4. 装飾あり memo を保存して reopen する。
5. 装飾なし memo は `rich_text_data = NULL` のままになることを確認する。
6. 日本語 IME、checkbox、date insert、copy/paste を確認する。
7. formatting action の undo / redo が正常に動くことを確認する。

Gate:

- 4 action が実機で操作できる
- underline / highlight が後続入力へ漏れない
- Smart Links の hover / open / copy が regression していない
- formatting action（bold / underline / strikethrough / highlight）の undo / redo が正常に動く
- build が通る
- result doc に実機確認結果が残っている

---

## Gate条件まとめ

- G-01: toolbar は 4 action のみ
- G-02: italic / clearFormatting が toolbar から消えている
- G-03: underline が追加されている
- G-04: underline は persistent rich text として保存 / reopen できる
- G-05: Smart Links temporary underline と persistent underline が衝突しない
- G-06: highlight action 後に toolbar active state で適用が分かる
- G-07: underline / strikethrough / highlight が後続入力へ漏れない
- G-08: multi-range selection は no-op
- G-09: IME marked text 中は formatting action が no-op
- G-10: build が通る
- G-11: formatting action（bold / underline / strikethrough / highlight）の undo / redo が正常に動く

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
- underline on/off
- strikethrough on/off
- highlight on/off
- toolbar active state
- decoration after reopen
- plain memo capacity path (`rich_text_data = NULL`)

### Smart Links

- URL detection
- hover underline / color
- open link
- copy link
- hover only no autosave
- URL text に persistent underline を付けた場合の共存

### Window / Focus

- nonactivating first mouse
- toolbar click does not clear selection before action
- close flush
- reopen last closed memo
- app relaunch open memo restore

---

## 実機確認項目

1. toolbar に 4 icons だけが出ることを確認する。
2. italic / clear formatting が出ないことを確認する。
3. `サンプル` を選択して bold on/off を確認する。
4. underline on/off を確認する。
5. strikethrough on/off を確認する。
6. highlight on/off を確認する。
7. highlight を押した直後、selection が残っていても marker button が active になることを確認する。
8. underline / strikethrough / highlight 後に selection 外へ caret を移して入力しても装飾が漏れないことを確認する。
9. URL を含む memo で Smart Links hover / open / copy を確認する。
10. persistent underline と Smart Links temporary underline が共存することを確認する。
11. 装飾あり memo を保存し、アプリ再起動後も復元されることを確認する。
12. formatting action（bold / underline / strikethrough / highlight）を実行後、undo / redo が正常に動くことを確認する。
13. 複数範囲を選択した状態で formatting action が no-op になることを確認する（multi-range no-op）。
14. 日本語 IME で変換候補が表示されている状態（marked text 中）に formatting action が no-op になることを確認する。

---

## 技術詳細確認

### 責務配置

`CheckableTextView.swift`:

- toolbar action enum
- toolbar button rendering
- active state calculation
- AppKit event lifecycle
- Smart Links temporary attributes

`RichTextOperations.swift`:

- bold / underline / strikethrough / highlight mutation
- target range validation
- toggle state 判定
- typing attributes cleanup

`RichTextContentCodec.swift`:

- persistent underline を含む sanitizer
- Smart Links temporary attrs を保存しない境界

### メモリで持つ情報

持つ:

- editor 表示中の `NSAttributedString`
- current selection range
- toolbar hover state
- toolbar active actions
- Smart Link detected ranges
- temporary hover attributes

持たない:

- italic state
- clear formatting action state
- Smart Link hover attributes as persistent content

### イベント経路

Toolbar click:

1. `CheckboxNSTextView.mouseDown`
2. `MarkdownSelectionToolbar.handleClick`
3. `CheckboxNSTextView.performFormattingAction`
4. AppKit single target range を解決する
   - multi-range は no-op
5. `RichTextOperations` で mutation plan 作成
6. `NSTextView.shouldChangeText(in:replacementString:)`
7. `NSTextStorage` mutation
8. `typingAttributes` cleanup
9. selection restore
10. toolbar active state refresh
11. `NSTextView.didChangeText`
12. `Coordinator.textDidChange`
13. autosave

### AppKit / SwiftUI 責務境界

- toolbar の render（button 配置・active state 表示）は SwiftUI View が担う
- text mutation（`NSTextStorage` 操作・`typingAttributes` cleanup・selection restore）は AppKit `NSTextView` / `NSTextStorage` に限定する
- SwiftUI 側から `textStorage` を直接触らない。SwiftUI → AppKit の橋渡しは `performFormattingAction` 経由に一本化する
- `CheckableTextView` の `NSViewRepresentable` Coordinator は text change 通知の受け取りと autosave trigger に限定し、formatting ロジックを持たない

### close / reopen / pin / drag の状態遷移

本計画はこれらの状態遷移を変更しない。管理場所は既存 `WindowController` / AppKit delegate のまま維持する。

### Persistence との衝突

- underline は `rich_text_data` に保存する
- `draft TEXT` には underline marker を入れない
- Smart Links temporary attrs は `layoutManager` だけに載せる
- RTF sanitizer は persistent `.underlineStyle` を保存し、temporary `.foregroundColor` は保存しない

---

## MECE 検査

### Issue → Phase 対応

- U-101: Phase 1a
- U-102: Phase 1a
- U-103: Phase 1b, Phase 2
- A-104: Phase 2, Phase 4
- U-105: Phase 3
- P-106: Phase 2, Phase 4

> **注**: Phase 0 は現状記録フェーズ（実装なし）のため、このテーブルでは省略する。Phase 0 が記録対象とする U-101, U-102, U-105 は Phase 1a 以降の実装フェーズで対応する。

### Phase → Issue 対応

- Phase 0: U-101, U-102, U-105 (記録のみ、実装なし)
- Phase 1a: U-101, U-102
- Phase 1b: U-103 (slot/enum のみ)
- Phase 2: U-103 (実装), A-104, P-106
- Phase 3: U-105
- Phase 4: A-104, P-106

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

[x] 主目的は toolbar simplification と underline / feedback 改善に限定している  
[n/a: 本計画に高リスク疎通確認フェーズはない。Phase 1a/1b/2 は段階的確認で代替する] 高リスク疎通確認テーマは1つ  
[x] ついで作業を入れていない（italic 既存 data の互換維持は削除作業の付随処理であり別目的ではない）  
[x] persistence schema は変更しない  
[x] window lifecycle は変更しない  
[x] italic / clearFormatting は削除対象として固定した  

### 技術詳細

[x] ファイルごとの責務が明確  
[x] Smart Links underline と persistent underline の境界が明確  
[x] イベント経路を説明している  
[x] persistence / Smart Links との衝突確認を Gate 化している  

### Window / Focus

[x] first mouse / selection 維持を regression check に入れた  
[x] IME marked text を Gate に入れた  
[n/a: 本計画は toolbar action に限定し window / focus 責務を変更しない] Window 責務が一箇所に集約されている  
[n/a: 本計画は toolbar action に限定し window / focus 責務を変更しない] Focus 制御が UI と AppKit で競合していない  

### Persistence

[x] underline は `rich_text_data`（`NSAttributedString` → RTF）に保存する  
[x] `draft TEXT` には underline marker を入れない  
[x] Smart Links temporary attrs は `layoutManager` にのみ載せ、保存しない  
[x] sanitizer は persistent `.underlineStyle` を保存し、temporary attrs は保存しない  

### 実機確認

[x] 実機確認項目が計画書に列挙されている  
[x] Phase 4 Gate で全項目の実施と result doc への記録が必須化されている  
[n/a: 本計画は global shortcut を変更しない] global shortcut を確認する  
[x] 1 click 操作を確認する（toolbar click の selection 維持を回帰/副作用チェックおよび Phase 4 Gate に含めている）  
[x] ゼロクリック入力を確認する（seamless UX への影響として修正方針に明記し、Phase 4 regression チェックに含めている）  
