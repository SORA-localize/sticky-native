# Phase 2 Window Core MVP Plan

最終更新: 2026-04-12

## SSOT 参照宣言

- `/Users/hori/Desktop/Sticky/migration/01_product_decision.md`
- `/Users/hori/Desktop/Sticky/migration/06_roadmap.md`
- `/Users/hori/Desktop/Sticky/migration/09_seamless_ux_spec.md`
- `docs/product/mvp-scope.md`
- `docs/roadmap/development-roadmap-revalidated.md`
- `docs/roadmap/phase-1-seamless-window-probe-result.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`

## 今回触る関連ファイル

- `StickyNative.xcodeproj`
- `StickyNativeApp/AppDelegate.swift`
- `StickyNativeApp/HotkeyManager.swift`
- `StickyNativeApp/SeamlessWindow.swift`
- `StickyNativeApp/SeamlessHostingView.swift`
- `StickyNativeApp/ProbeWindowController.swift`
- `StickyNativeApp/ProbeEditorView.swift`
- `StickyNativeApp/*` の window lifecycle / menu bar 関連ファイル

## 問題一覧

- `A-01`: app がまだ probe 用の通常 app で、menu bar app の土台になっていない
- `W-01`: `1 memo = 1 window` を扱う window lifecycle が未分離
- `W-02`: pin / close / reopen の責務が probe UI に留まっている
- `U-01`: drag と操作ボタンの責務分離が未整理
- `K-01`: probe 専用コードが本実装へ混入する危険がある

## 目的

- Phase 1 で成立した seamless UX の土台を壊さずに、`1 memo = 1 window` の最小操作を成立させる

## スコープ In

- menu bar app の土台
- global shortcut
- 新規 memo window 生成
- 入力 UI
- drag
- resize
- pin / unpin
- close
- menu bar からの reopen

## スコープ Out

- SQLite
- close 後の local reopen 永続化
- app 再起動後の reopen
- app 再起動をまたぐ draft 保持
- Home / Trash / Settings

## 修正フェーズ

### Phase 2-1: App Shell Reset

目的:
- probe app から menu bar app の土台へ移行する

Gate:
- dock 常駐前提ではなく menu bar 起点で app が扱える

### Phase 2-2: Memo Window Lifecycle

目的:
- memo ごとの window create / focus / close を管理する責務を分離する

Gate:
- 新規 window を複数生成しても責務が崩れない

### Phase 2-3: Window Controls

目的:
- pin / close / drag / resize を本実装へ置き換える

Gate:
- probe 用の仮状態ではなく window として操作が成立する

### Phase 2-4: Reopen Surface

目的:
- menu bar から直近 window を reopen できる最小導線を付ける

Gate:
- close 後も app 内で 1 click reopen が成立する

## Gate 条件

- menu bar app として起動できる
- `Cmd+Option+Enter` で新規 memo window を出せる
- memo window が複数枚でも破綻しない
- pin / unpin が window level として機能する
- close 後に app 内メモリ上の reopen ができる
- seamless UX の pass 条件を壊していない

## 回帰 / 副作用チェック

- persistence を先に入れない
- probe 用の単一 controller を延命しない
- pin を SwiftUI の見た目状態だけで済ませない
- reopen を persistence と混同しない

## 実機確認項目

1. menu bar から app を操作できるか
2. `Cmd+Option+Enter` で新規 memo window が出るか
3. 複数 window で focus が破綻しないか
4. pin / unpin が実際の window 挙動として効くか
5. close 後に menu bar から reopen できるか

## 変更履歴

- 2026-04-12: Phase 1 probe 結果を受けて初版作成
