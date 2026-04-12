# Technical Decision

最終更新: 2026-04-12

## 採用

- UI: `SwiftUI`
- app lifecycle / menu bar / shortcut / window: `AppKit`
- persistence: `SQLite`

## 理由

- `1 memo = 1 window` の自然な制御が最優先だから
- menu bar と global shortcut は AppKit 側で責務を分けた方が素直だから
- window core を先に固め、永続化は `Phase 3` へ分離した方が責務境界が明快だから
- seamless UX のため、window/view の基盤は AppKit 拡張を前提にした方が良いから

## 実装境界

- SwiftUI:
  - memo editor view
- AppKit:
  - menu bar
  - NSWindow 制御
  - global shortcut
  - app lifecycle
  - `SeamlessWindow`
  - `SeamlessHostingView`
- SQLite:
  - `Phase 3` 以降の memo draft ローカル保存
  - `Phase 3` 以降の reopen 用メタデータ保持
