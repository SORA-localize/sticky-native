# Phase 2 Window Core MVP Plan

最終更新: 2026-04-12

## SSOT 参照宣言

- `/Users/hori/Desktop/Sticky/migration/01_product_decision.md`
- `/Users/hori/Desktop/Sticky/migration/02_ux_principles.md`
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
- `StickyNativeApp/MemoWindow.swift`
- `StickyNativeApp/MemoWindowController.swift`
- `StickyNativeApp/MemoWindowView.swift`
- `StickyNativeApp/MemoEditorView.swift`
- `StickyNativeApp/WindowManager.swift`
- `StickyNativeApp/MenuBarController.swift`

削除または置換対象:
- `StickyNativeApp/ProbeWindowController.swift`
- `StickyNativeApp/ProbeEditorView.swift`

補足:
- `MemoWindowView.swift` は window chrome と drag 領域の責務を持つ
- `MemoEditorView.swift` は editor 本体の入力責務を持つ
- Phase 2 では新規ファイルを 6 つ想定する
- planning guideline の原則 2 以内は超えるが、probe から本実装へ責務分離するために必要な分割として許容する
- これ以上増やす場合は先に計画文書を更新する

## 問題一覧

- `A-01`: app がまだ probe 用の通常 app で、menu bar app の土台になっていない
- `W-01`: `1 memo = 1 window` を扱う window lifecycle が未分離
- `W-02`: pin / close / reopen の責務が probe UI に留まっている
- `W-03`: drag の操作領域設計が未確定で、ボタン操作と競合する危険がある
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
- probe 用 controller/view を本実装の起点として延命しない

### Phase 2-2: Memo Window Lifecycle

目的:
- memo ごとの window create / focus / close を管理する責務を分離する

Gate:
- `WindowManager` が複数 window を保持できる
- 指定した memo に対して意図した window が生成 / 再前面化される

### Phase 2-3: Window Controls

目的:
- pin / close / drag / resize を本実装へ置き換える

Gate:
- probe 用の仮状態ではなく window として操作が成立する
- ボタン領域での click と drag が競合しない

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
- drag がボタン操作と競合しない
- close 後に app 内メモリ上の reopen ができる
- seamless UX の pass 条件を壊していない

## 回帰 / 副作用チェック

- persistence を先に入れない
- probe 用の単一 controller を延命しない
- probe 用 view / 文言 / ラベルを引き継がない
- pin を SwiftUI の見た目状態だけで済ませない
- reopen を persistence と混同しない
- `isMovableByWindowBackground` の全面適用で雑に drag を成立させない

## 実機確認項目

1. app 起動後、Dock を使わず menu bar item から app 操作に入れるか
2. Safari など別アプリ前面の状態から `Cmd+Option+Enter` を押し、新規 memo window が即座に出るか
3. memo window を 2 枚以上出した状態で、片方をクリックしても focus と入力先が破綻しないか
4. pin を有効化した window が実際に window level として維持され、無効化で通常状態へ戻るか
5. pin / close ボタン周辺をクリックしたとき、意図せず drag が始まらないか
6. window を close した後、menu bar から同一 session 内 reopen が 1 click でできるか

## 変更履歴

- 2026-04-12: Phase 1 probe 結果を受けて初版作成
- 2026-04-12: probe 削除方針、drag 操作領域、実機確認手順を明確化
