# Phase 1 Seamless Window Probe Result

最終更新: 2026-04-12

## SSOT 参照宣言

- `/Users/hori/Desktop/Sticky/migration/09_seamless_ux_spec.md`
- `docs/roadmap/development-roadmap-revalidated.md`
- `docs/roadmap/phase-1-seamless-window-probe-plan.md`

## 結論

Phase 1 の probe は通過とする。

採用する土台:
- `SeamlessWindow` を custom `NSWindow` として維持する
- `SeamlessHostingView` を custom `NSHostingView` として維持する
- `acceptsFirstMouse` を window core の前提に含める
- shortcut 直後の focus は AppKit 側の window 前面化と SwiftUI 側の `@FocusState` の組み合わせで行う
- 背景は `material / vibrancy` を採用候補として維持する

まだ採用しないもの:
- probe 用の pin UI 状態
- probe 専用の単一 window 構成
- probe 用の見た目や文言

## 検証結果

### W-01: `SeamlessWindow`

結果:
- pass

確認内容:
- custom `NSWindow` で `canBecomeKey` / `canBecomeMain` を返しても起動・前面化が破綻しない
- 透明タイトルバー系の構成でも probe は成立した

判断:
- Phase 2 でも `SeamlessWindow` を継続採用する

### F-01: first mouse

結果:
- pass

確認内容:
- 別アプリ前面時でも pin / close の 1 click 操作が通った

判断:
- `SeamlessHostingView.acceptsFirstMouse` は Phase 2 の土台に残す

### F-02: zero-click input

結果:
- pass

確認内容:
- `Cmd+Option+Enter` 直後にマウスなしで入力できた

判断:
- global shortcut 後の front/focus 制御は現行方式を基準にする

### U-01: material / vibrancy

結果:
- pass

確認内容:
- すりガラス背景でも editor の文字視認性が保てた

判断:
- Phase 2 でも material 系背景を継続検証する
- ただし最終見た目は probe のまま固定しない

## 未解決事項

- pin は UI の反応確認のみで、window level や `floating` は未実装
- close 後 reopen は未実装
- menu bar app 化は未実装
- persistence は未実装
- drag の成立は現状 `isMovableByWindowBackground` に依存しており、操作領域設計は未確定

## Phase 2 へ渡す採用パターン

- Window: `SeamlessWindow`
- Hosting: `SeamlessHostingView`
- Focus: AppKit の `makeKeyAndOrderFront` + `NSApp.activate` + SwiftUI の `@FocusState`
- Visual baseline: `material` 背景 + 読める editor 面

## Phase 2 で捨てるべきもの

- probe 専用ラベル
- probe 専用ボタン文言
- 単一 window を前提とした controller 責務

## Gate 判定

- `SeamlessWindow` が key / main になれる: pass
- `SeamlessHostingView` が first mouse を受ける: pass
- shortcut 後に editor focus が入る: pass
- 透け背景が視認性を壊さない: pass

Phase 2: Window Core MVP へ進行可能と判断する。
