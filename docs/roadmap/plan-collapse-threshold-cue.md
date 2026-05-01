# Collapse Threshold Cue Plan

作成: 2026-05-01  
ステータス: 計画中（実装未着手）

---

## SSOT参照宣言

migration 上位文書（planning guideline §2 必須参照セット）:

- `/Users/hori/Desktop/Sticky/migration/README.md`
- `/Users/hori/Desktop/Sticky/migration/01_product_decision.md`
- `/Users/hori/Desktop/Sticky/migration/02_ux_principles.md`
- `/Users/hori/Desktop/Sticky/migration/04_technical_decision.md`
- `/Users/hori/Desktop/Sticky/migration/06_roadmap.md`
- `/Users/hori/Desktop/Sticky/migration/07_project_bootstrap.md`
- `/Users/hori/Desktop/Sticky/migration/08_human_checklist.md`
- `/Users/hori/Desktop/Sticky/migration/09_seamless_ux_spec.md`

StickyNative ローカル補助文書:

- `docs/product/product-vision.md`
- `docs/product/ux-principles.md`
- `docs/product/mvp-scope.md`
- `docs/architecture/technical-decision.md`
- `docs/roadmap/roadmap.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`
- `docs/roadmap/plan-post-it-window-ui.md`
- `docs/product/current-feature-summary.md`

参考画像:

- `CleanShot 2026-05-01 at 15.28.32.png`
- `CleanShot 2026-05-01 at 15.28.50.png`
- `CleanShot 2026-05-01 at 15.29.09.png`

### migration SSOT の確認結果

2026-05-01 時点で `/Users/hori/Desktop/Sticky/migration/*` は作業環境に存在しない。  
したがって本計画は `stickynative-ai-planning-guidelines.md` の `migration SSOT unavailable 時の正式代替手順` を適用する。

本計画で扱う変更範囲は `memo window visual cue` と、それを成立させるための最小限の `live resize / collapse timing` 調整に限定する。  
Home / Trash / Session / persistence schema / shortcut registry には広げない。

### migration unavailable 下での残余リスク

- 上位 UX spec 未確認のため、`threshold cue > command flash` の優先順位が後で再調整になる可能性がある
- 上位 seamless UX 文書により、`threshold に入った瞬間だけ cue を出す` より強い affordance 要件が後で出る可能性がある
- 上位 window spec により、live resize 中と mouse up 後の責務分離が別方式へ修正される可能性がある

今回は `memo window cue` と `live resize / collapse timing` の最小変更に限定し、上位 SSOT 復旧後に再照合できる形を優先する。

---

## 今回触る関連ファイル

既存:

- `StickyNativeApp/MemoWindowUIState.swift`
  - command flash と threshold cue を同一の UI state で扱うか判断する
  - cue の source of truth を持つ候補
- `StickyNativeApp/MemoWindowController.swift`
  - live resize 中の threshold entry / exit を検知する
  - auto-collapse 実行タイミングと cue 表示タイミングを分離する
- `StickyNativeApp/MemoWindowView.swift`
  - threshold cue overlay を表示する
  - command flash と threshold cue の見た目衝突を防ぐ
- `StickyNativeApp/SeamlessWindow.swift`
  - resize 中の window 基盤確認のみ

確認のみ:

- `StickyNativeApp/MemoEditorView.swift`
- `StickyNativeApp/SeamlessHostingView.swift`
- `StickyNativeApp/CheckableTextView.swift`

触らない:

- memo title formatter
- Home / Trash / Session UI
- persistence schema
- 画像貼り付け
- pin / trash / close / collapse icon 配置

---

## 問題一覧

| ID | 分類 | 内容 |
|---|---|---|
| A-40 | Architecture | 現在の window cue は `command flash` だけが `MemoWindowUIState` にあり、threshold cue が別経路で継ぎ足される前提になっていて system 化されていない |
| W-40 | Window | auto-collapse 判定が `windowDidEndLiveResize` のみで、ユーザーが期待する「縮めている最中に threshold へ入った瞬間」の cue を出せない |
| W-41 | Window | threshold cue と collapse 遷移が同一タイミングだと、cue が collapse animation に飲まれて視認できない |
| U-40 | UI | collapse threshold に達したことを示す視覚 cue が無く、resize 中の状態変化が予告されない |
| U-41 | UI | command flash と threshold cue の overlay / duration / priority が未定義で、見た目と責務が衝突しやすい |
| F-40 | Focus | live resize 中の cue 追加で first mouse / editor focus 経路を壊さない保証がまだ無い |
| K-40 | Knowledge | migration SSOT unavailable のため、本計画は planning guideline の正式代替手順に依存する |

---

## 目的

- マウス resize 中に auto-collapse threshold へ入った瞬間だけ、白い window cue を確実に見せる
- cue 表示と collapse 実行を分離し、視認性を担保する
- command flash と threshold cue を場当たりではなく、window visual cue として整理する

## スコープ In

- live resize 中の threshold entry / exit 検知
- threshold cue の source of truth 整理
- threshold cue overlay の表示ルール追加
- auto-collapse 実行タイミングの調整
- cue 競合ルールの最小定義

## スコープ Out

- post-it window 全体レイアウトの再設計
- command flash 自体の色設計変更
- shortcut command 群の挙動変更
- persistence の新規保存項目追加
- threshold 到達音や haptic

---

## 現状整理

### 現在の実装

- `MemoWindowUIState` は `flashCommand` だけを持ち、command shortcut 起点の枠フラッシュを管理している
- `MemoWindowController` は `windowDidEndLiveResize` でのみ auto-collapse / auto-expand を判定している
- `MemoWindowView` は `flashCommand` をそのまま overlay に描画している
- threshold cue 用の state, duration, priority は未定義

### 現在の問題

- resize 中の threshold entry を検知していない
- cue を出しても直後に collapse すると視認しづらい
- command flash と threshold cue の責務境界が無い

### system 化の現状評価

現状は `半分だけ system 化されている` 状態であり、十分ではない。

- 良い点:
  - command flash の state 自体は `MemoWindowUIState` に集まっている
  - overlay の描画先は `MemoWindowView` で一箇所
- 足りない点:
  - cue 種別が `command` に固定されている
  - threshold cue の発火元と表示ルールが共通モデル化されていない
  - resize event と collapse state transition の責務が controller 内で未分離

結論として、今のまま threshold cue を足すと `局所対応の積み増し` になりやすい。  
今回の変更では、少なくとも `cue state` と `trigger path` の整理までを同時に行う。

---

## 技術詳細確認

### 目標仕様

- cue は `mouse resize` による threshold entry のときだけ出す
- `minus` / `plus` button 由来の collapse / expand では出さない
- cue 色は白
- cue は `threshold に入った瞬間` に 1 回だけ出す
- threshold 内に留まり続けても連打発火しない
- 一度 threshold を抜けたら、次回 entry で再発火できる
- cue が見えたあとに auto-collapse する
- auto-expand 側では cue を出さない

### cue 競合ルール

- `threshold cue` と `command flash` は同時表示しない
- 優先順位は `threshold cue > command flash`
- threshold cue 表示中に command shortcut が来た場合、command flash は threshold cue を上書きしない
- threshold cue の表示が終わったあと、command flash の保留再生は行わない
- command flash 表示中に threshold entry が来た場合は、threshold cue が即時に command flash を上書きする

理由:

- threshold cue は live resize 中の瞬間的 affordance で、見逃すと意味が薄い
- command flash は shortcut を再実行すれば再確認できるので、threshold cue より優先度を下げてよい
- cue queue を持ち込むと今回の変更範囲を超えるため、今回は `threshold 優先・保留なし` で閉じる

### 責務境界

`MemoWindowUIState.swift`:

- `command flash` と `threshold cue` をまとめた `window visual cue state` を持つ
- cue の現在値と消灯タイミングを管理する
- View は cue state を読むだけにする

`MemoWindowController.swift`:

- resize event から threshold entry / exit を検知する
- `isWithinCollapseThresholdDuringLiveResize` のようなメモリ状態を持つ
- threshold entry 時に cue trigger を呼ぶ
- live resize 終了後、threshold 内にいる場合だけ collapse を実行する
- visual cue を成立させるために必要な範囲だけ `windowDidResize` / `windowDidEndLiveResize` の責務を調整する

`MemoWindowView.swift`:

- cue state に応じて overlay を描画する
- command flash と threshold cue の優先順位を view ローカル条件分岐で増やさず、state 入力に従う

### source of truth

- cue の source of truth は `MemoWindowUIState` に置く
- resize 中に現在 threshold 内にいるかどうかの一時判定は `MemoWindowController` に置く
- collapse 状態そのものは既存どおり `uiState.isCollapsed` に置く
- cue 種別の source of truth も `MemoWindowUIState` に一本化し、View は `command` と `threshold` を別管理しない

### AppKit / SwiftUI 境界

- threshold 判定は AppKit (`NSWindowDelegate`) 側
- cue 描画は SwiftUI 側
- cue のライフサイクルは `ObservableObject` で橋渡しする

### イベント経路

1. ユーザーが window border / corner を mouse resize する
2. `windowDidResize` で現在 frame を読む
3. controller が `threshold 外 -> 内` の entry を検知する
4. controller が `uiState.triggerThresholdCue()` を呼ぶ
5. `MemoWindowView` が白 overlay を描画する
6. `windowDidEndLiveResize` で threshold 内なら `setCollapsed(true)` を実行する

### probe 結果の記録先

- `Phase 6H-1` の疎通確認結果は、この計画書の `変更履歴` に追記する
- 追記内容は最低限 `確認日`, `観測した event 経路`, `first mouse / focus への影響有無` を含める
- probe の結果、前提が変わった場合は `技術詳細確認` と `Gate条件` を先に更新してから実装へ進む

### まだ持たないもの

- cue queue
- cue の複数同時表示
- haptic / sound
- threshold cue の persistence

---

## 修正フェーズ

### Phase 6H-1: live resize probe と cue 経路分離

対象 Issue: `W-40`, `W-41`, `F-40`

やること:

- `windowDidResize` と `windowDidEndLiveResize` の責務を分ける
- threshold entry / exit の観測用 state を controller に追加する
- first mouse / editor focus が resize probe 追加で壊れないか確認する
- 観測結果を本計画の `変更履歴` に記録する

完了条件:

- live resize 中の threshold entry を controller で一意に検知できる
- `windowDidEndLiveResize` だけに依存しない構造になっている
- 1 click 入力と drag の既存経路に変更が入っていない

### Phase 6H-2: cue state の system 化

対象 Issue: `A-40`, `U-41`

やること:

- `MemoWindowUIState` に threshold cue を追加する
- command flash と threshold cue の state モデルを整理する
- cue の duration と cancel ルールを一箇所に寄せる
- `threshold cue > command flash` の競合ルールを state 設計へ反映する

完了条件:

- View が cue 種別を直接推測しない
- command flash と threshold cue の duration 管理が一箇所にある
- threshold cue が局所フラグではなく UI state 経由で描画される
- cue 競合ルールが実装者判断なしで適用できる

### Phase 6H-3: 白 threshold cue 実装

対象 Issue: `U-40`, `W-41`

やること:

- threshold cue overlay を白で実装する
- cue の見える時間を確保してから auto-collapse する
- threshold 内に留まっている間の多重発火を防ぐ

完了条件:

- resize 中に threshold へ入った瞬間だけ白 cue が見える
- cue 後に collapse しても視認できる
- threshold を出入りした時だけ再発火する

### Phase 6H-4: 回帰確認

対象 Issue: `F-40`, `K-40`

やること:

- command flash が従来どおり見えるか確認する
- auto-collapse / auto-expand / close / reopen の既存挙動を確認する
- migration fallback 条件から逸脱していないか再確認する

完了条件:

- 既存 command flash と threshold cue が共存する
- resize 以外の collapse 経路では誤発火しない
- 変更範囲が memo window cue に留まっている

---

## Gate条件

- `K-40`: migration unavailable の事実、残余リスク、変更範囲の限定を計画書に維持している
- `K-40`: 実装着手前に「migration SSOT を復旧して再照合する」または「代替手順で進む制約を再確認する」のどちらで進むかを再確認する
- `W-40`: live resize 中の threshold entry 検知が実装前に説明できる
- `A-40`: cue state の source of truth が `MemoWindowUIState` に一本化されている
- `W-41`: cue 表示と collapse 実行が同一タイミングで潰れない設計になっている
- `F-40`: first mouse / focus 経路を変えていないことを確認する
- `build`: `xcodebuild -project StickyNative.xcodeproj -scheme StickyNative -configuration Debug build` が通る

---

## 回帰/副作用チェック

- `Cmd+S`, `Cmd+W`, `Cmd+Delete`, `Cmd+P`, `Cmd+Return` の command flash が壊れていないか
- `minus` / `plus` button 操作で threshold cue が誤発火しないか
- resize 中に threshold 内へ入っても editor focus が壊れないか
- auto-collapse 後に auto-expand が従来どおり動くか
- collapsed 状態で close / reopen しても expanded frame 復元が壊れないか
- pinned 状態でも cue 表示が見えるか

---

## 変更履歴

- 2026-05-01: 初版作成
- 2026-05-01: cue 競合ルール、変更範囲の補足、probe 記録先を追記

---

## 実機確認項目

- window をマウスで縮めて threshold に入った瞬間、白 cue が見える
- threshold 内に留め続けても cue が連打発火しない
- threshold を一度抜けて再度入ると cue が再発火する
- mouse up 後に collapsed へ移行する
- `minus` button で collapse したときは cue が出ない
- `plus` button で expand したときは cue が出ない
- command shortcut の flash が従来どおり見える
- 非アクティブから 1 click で editor に書ける

---

## セルフチェック結果

### SSOT整合
[ ] migration README を確認した
[ ] 01_product_decision を確認した
[ ] 02_ux_principles を確認した
[ ] 06_roadmap を確認した
[ ] 07_project_bootstrap を確認した
[ ] 09_seamless_ux_spec を確認した
[x] migration unavailable の場合、正式代替手順を計画書へ反映した

### 変更範囲
[x] 主目的は1つ
[x] 高リスク疎通確認テーマは1つ
[x] ついで作業を入れていない

### 技術詳細
[x] ファイルごとの責務が明確
[x] メモリ管理と persistence の境界が明確
[x] イベント経路と状態遷移が説明できる

### Window / Focus
[x] Window 責務が一箇所に集約されている
[x] Focus 制御が UI と AppKit で競合していない
[x] first mouse の扱いが明文化されている

### Persistence
[x] 保存経路は一本化されている
[x] frame と open 状態の責務が明確
[x] relaunch 時の扱いが定義されている

### 実機確認
[ ] global shortcut を確認する
[ ] 1 click 操作を確認する
[ ] ゼロクリック入力を確認する
