# Technical Decision

最終更新: 2026-04-11

## 採用

- UI: `SwiftUI`
- app lifecycle / menu bar / shortcut / window: `AppKit`
- persistence: `SQLite`

## 理由

- `1 memo = 1 window` の自然な制御が最優先だから
- menu bar と global shortcut は AppKit 側で責務を分けた方が素直だから
- 再起動をまたぐ draft 保持が Phase 1 条件に入ったため、最小 SQLite を先行投入した方が境界が明快だから
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
  - memo draft のローカル保存
  - reopen 用メタデータ保持
