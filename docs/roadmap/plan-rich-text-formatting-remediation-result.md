# Rich Text Formatting Remediation Result

作成: 2026-04-23  
対象計画: `docs/roadmap/plan-rich-text-formatting-remediation.md`

---

## Phase 0: Formatting Probe And Reproduction Notes

### Baseline

ユーザー実機確認で以下の問題が報告されている。

1. 一度文字に装飾を入れた後、同じ選択に同じ装飾を押しても解除されない。
2. italic が見た目として反映されない。
3. strikethrough を押すと、それ以降に入力する文字にも取り消し線が入る。

### Code Investigation

現行実装では `CheckableTextView.swift` 内で toolbar action から `textStorage.addAttribute` / `removeAttribute` を直接呼んでいる。

確認したリスク:

- `typingAttributes` の更新が不十分で、selection decoration が後続入力へ漏れる可能性がある。
- `textStorage.enumerateAttribute` 中に同じ `textStorage` を mutate しており、range mutation が不安定になり得る。
- `selectedRange()` 直読みで AppKit の user attribute change range に寄せ切れていない。
- bold / italic の font trait conversion が `baseFont` 起点の自前変換で、italic fallback が曖昧。

### Phase 0 Gate

- [x] ユーザー報告の 3 問題を baseline として記録した
- [x] 修正後比較に使う操作対象を記録した
- [x] 本実装と probe を混ぜていない

---

## Phase 1-3 Implementation Notes

### Phase 1 / 2

- `RichTextOperations.swift` を追加し、font trait / strikethrough / highlight の mutation を `CheckableTextView.swift` から分離した。
- toolbar action は `rangeForUserCharacterAttributeChange` を使う経路へ寄せた。
- `rangesForUserCharacterAttributeChange` が複数 range を返す場合は no-op にした。
- mutation 前に attribute runs を snapshot し、enumerate 中に同じ `textStorage` を mutate しない形にした。
- formatting action 後に `typingAttributes` を更新し、`.strikethroughStyle` / `.backgroundColor` / Smart Link temporary attrs が後続入力へ漏れないようにした。

### Phase 3

- quote は toolbar から外した。
- 5つ目の action は `clearFormatting`（装飾解除）に置き換えた。
- 装飾解除は選択範囲の font を editor base font へ戻し、strikethrough / background / foreground / underline attributes を削除する。

### Build

- `xcodebuild -project StickyNative.xcodeproj -scheme StickyNative`: passed

### Manual Verification

- 実アプリ起動での手動確認は未実施。
- 現在の app build を通常起動すると、実 DB に `rich_text_data BLOB` migration が走る可能性があるため、手動確認は DB migration を許容するタイミングで行う。
