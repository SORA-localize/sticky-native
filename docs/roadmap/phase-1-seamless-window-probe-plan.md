# Phase 1 Seamless Window Probe Plan

最終更新: 2026-04-12

## SSOT 参照宣言

- `/Users/hori/Desktop/Sticky/migration/01_product_decision.md`
- `/Users/hori/Desktop/Sticky/migration/02_ux_principles.md`
- `/Users/hori/Desktop/Sticky/migration/06_roadmap.md`
- `/Users/hori/Desktop/Sticky/migration/07_project_bootstrap.md`
- `/Users/hori/Desktop/Sticky/migration/09_seamless_ux_spec.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`

## 今回触る関連ファイル

- `StickyNative.xcodeproj`
- `StickyNativeApp/SeamlessWindow.swift`
- `StickyNativeApp/SeamlessHostingView.swift`
- `StickyNativeApp/ProbeEditorView.swift`
- `docs/roadmap/phase-1-seamless-window-probe-plan.md`

補足:
- 実装時は 1 フェーズごとにさらに分割する
- この文書は Phase 1 全体の親計画であり、一気に全部実装しない

## 問題一覧

- `W-01`: `SeamlessWindow` の責務が未実装
- `W-02`: タイトルバー透明化と drag の責務分離が未実装
- `F-01`: `acceptsFirstMouse` を使った 1 click 操作が未検証
- `F-02`: shortcut 直後のゼロクリック入力が未検証
- `U-01`: material / vibrancy を安全に使う表示土台が未検証
- `K-01`: seamless probe の結果を残す文書が未作成

## 修正フェーズ

### Phase 1-1: Bootstrap Minimal App

目的:
- menu bar なしで良いので、最小 macOS app と custom window の器だけ作る

対象:
- 新規 Xcode project
- `SeamlessWindow`
- `ProbeEditorView`

Gate:
- custom window が単体で起動する

### Phase 1-2: First Mouse Probe

目的:
- 非アクティブ状態から 1 click でボタンを押せるか確認する

対象:
- `SeamlessHostingView`
- pin / close の仮ボタン

Gate:
- 別アプリ前面時でも 1 click 操作が通る

### Phase 1-3: Focus Probe

目的:
- shortcut 直後のゼロクリック入力を確認する

対象:
- global shortcut
- `@FocusState`

Gate:
- `Cmd+Option+Enter` の直後に入力開始できる

### Phase 1-4: Material Probe

目的:
- material / vibrancy を用いた背景表現が実用になるか確認する

対象:
- background material
- hover reaction の最小確認

Gate:
- 背景の透け感と視認性が両立する

### Phase 1-5: Probe Consolidation

目的:
- probe 結果を次フェーズへ渡せる形に整理する

対象:
- 疎通確認結果文書
- 次フェーズ移行条件

Gate:
- Window Core MVP に進む採用パターンが 1 つに絞れる

## Gate 条件

- `SeamlessWindow` が key / main になれる
- `SeamlessHostingView` が first mouse を受ける
- shortcut 後に editor focus が入る
- 透け背景が視認性を壊さない
- 不成立項目があれば、理由と代替案を文書化する

## 回帰 / 副作用チェック

- 本フェーズで SQLite や reopen を入れない
- 本フェーズで管理 UI を入れない
- probe code を共通基盤と誤認しない
- 既に不成立と分かった window 構成を延命しない

## 実機確認項目

1. 別アプリ前面から pin / close を 1 click で押せるか
2. `Cmd+Option+Enter` の直後に文字入力できるか
3. 背景 material が読みにくさを生まないか
4. drag が不自然な領域依存になっていないか

## 変更履歴

- 2026-04-12: 初版作成
