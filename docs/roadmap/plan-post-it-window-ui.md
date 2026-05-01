# Post-It Window UI Plan

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
- `docs/roadmap/phase-2-window-core-mvp-plan.md`
- `docs/roadmap/plan-memo-window-size-and-color.md`
- `docs/roadmap/plan-standard-window-resize-ux.md`
- `docs/product/current-feature-summary.md`

参考画像:

- `CleanShot 2026-05-01 at 15.28.32.png`
- `CleanShot 2026-05-01 at 15.28.50.png`
- `CleanShot 2026-05-01 at 15.29.09.png`

### migration SSOT の確認結果

2026-05-01 時点で `/Users/hori/Desktop/Sticky/migration/*` は作業環境に存在せず、planning guideline が要求する migration SSOT は直接参照できない。

したがって本計画は、現行ローカル文書、現行実装、参考スクショを根拠にした下書きに留める。  
本計画はこのままでは実装着手不可とし、以下を実装ブロッカーとして扱う。

- migration SSOT を復旧して本計画と再照合する
- もしくは planning guideline 自体を更新し、migration unavailable 時の正式代替手順を先に文書化する

### 既存計画との関係

`phase-2-window-core-mvp-plan.md` と `plan-standard-window-resize-ux.md` には「drag は専用 handle のみ」という方針がある。  
今回の参考 UI は「window 全面 drag」ではなく、「上端の細い帯のうち control 以外は drag」という方針であり、editor 面とは分離されたまま drag 領域を広げる。

よって本計画は以下だけを上書きする。

- dedicated center handle だけを drag source とする方針

以下は維持する。

- `isMovableByWindowBackground = false`
- editor 面を drag 可能にしない
- AppKit 側で drag / resize を扱い、SwiftUI 側で editor hit test を壊さない

---

## 今回触る関連ファイル

既存:

- `StickyNativeApp/MemoWindowView.swift`
  - ヘッダと editor の二面構造を一面 UI に再構成する
  - hover 時だけ controls を出す UI を持つ
  - collapsed / expanded ごとの見た目を分ける
- `StickyNativeApp/MemoEditorView.swift`
  - 独立した editor card 背景をやめ、post-it 面に統合する
- `StickyNativeApp/MemoWindowController.swift`
  - collapse / expand の window frame 制御
  - top strip drag source と resize 方針の適用
  - min size / collapsed size の制約管理
- `StickyNativeApp/MemoWindowUIState.swift`
  - `isCollapsed` など window UI 状態の追加候補
- `StickyNativeApp/SeamlessWindow.swift`
  - key/main window 基盤を維持する
- `StickyNativeApp/WindowManager.swift`
  - close / reopen / relaunch と collapsed frame 復元の影響確認
- `StickyNativeApp/CheckableTextView.swift`
  - post-it 一面 UI にした後も first mouse / editor focus を壊していないか確認する

確認のみ:

- `StickyNativeApp/MemoWindow.swift`
- `StickyNativeApp/AppSettings.swift`
- `StickyNativeApp/PersistenceCoordinator.swift`
- `StickyNativeApp/SQLiteStore.swift`
- `StickyNativeApp/SeamlessHostingView.swift`

新規候補:

- `StickyNativeApp/TopStripDragView.swift`
  - 上端帯全体で `performDrag(with:)` を受ける専用 AppKit bridge

触らない:

- Home / Trash / Session UI
- SQLite schema / migration
- 画像貼り付け機能
- editor command 群

---

## 問題一覧

| ID | 分類 | 内容 |
|---|---|---|
| U-30 | UI | 現在の memo window は header と editor card が分離しており、一枚の post-it として見えない |
| U-31 | UI | pin / trash / close などの controls が常時表示され、参考 UI の静かな見た目と異なる |
| U-32 | UI | editor の書き始め位置が上端帯の下に押し込まれ、付箋の自然な書き出し感が弱い |
| W-30 | Window | 現在の最小サイズ `320x220` では、参考 UI の細長い collapsed state に到達できない |
| W-31 | Window | drag source が中央の専用 handle に限定されており、参考 UI の「上端帯ならどこでも掴める」に合っていない |
| W-32 | Window | collapsed から expanded に戻す時の frame source of truth が未定義 |
| F-30 | Focus | hover-only controls と collapsed state 導入で first mouse / ゼロクリック入力が壊れる可能性がある |
| P-30 | Persistence | collapsed 中に close / reopen / relaunch した時、どの frame を保存し、expand 時に何を復元するか未定義 |
| K-30 | Knowledge | 既存計画の dedicated drag handle 方針と、今回の参考 UI の drag 領域方針が衝突している |
| K-31 | Knowledge | 参考 UI の `+` が「新規作成」ではなく「expand / restore affordance」である前提を、StickyNative でどう採用するか未明文化 |
| K-32 | Knowledge | migration SSOT 未参照のため、本計画は planning guideline の必須前提を満たしていない |

---

## 目的

- memo window を「header + editor card」から「一枚の post-it 面」へ再構成する
- controls を hover 時のみフェード表示にして、非 hover 時のノイズを下げる
- 細長い collapsed state を導入し、最小状態を「右上 icon だけの bar」に近づける
- editor 面の first mouse / ゼロクリック入力 / drag / resize の責務分離を壊さない

## スコープ In

- memo window の visual chrome 再設計
- top strip drag source への変更
- collapsed / expanded の状態導入
- hover 時の controls fade in / fade out
- collapsed 時の expand affordance
- close / reopen 時の collapsed frame 挙動定義

## スコープ Out

- 画像貼り付け
- 画像メモ化
- memo 本文の添付ファイル対応
- Home 一覧側の memo row UI
- 色テーマ自体の再設計
- AppSettings の memo size プリセット変更
- collapsed/expanded 状態の DB 永続化用追加カラム

---

## 現状整理

### 現在の window UI

- `MemoWindowView` は上部 `HStack` と下部 `MemoEditorView` の二段構成
- drag は `WindowDragHandleView.mouseDown -> performDrag(with:)` の専用 handle のみ
- editor 自体は独立カード背景を持ち、window surface から視覚分離されている
- controls は常時表示

### 現在の window core

- `styleMask: [.titled, .resizable, .fullSizeContentView]`
- `isMovableByWindowBackground = false`
- `contentMinSize = 320x220`
- close / reopen / relaunch の保存値は `window.frame`

### 参考 UI から読み取れる要件

- 一面の淡い付箋 surface
- 左上 controls と右上 affordance が上端帯にのみ存在する
- 上端帯の control 以外が drag 可能
- side / corner / lower edge は標準 resize edge として扱う
- collapsed state は短い pill 状
- hover 時だけ controls が見える挙動と相性が良い

---

## 技術詳細確認

### 目標仕様

expanded:

- 一枚の post-it 面だけを見せる
- 上端に薄い interaction strip を置く
- 左上: close / pin / trash
- 右上: collapse button
- controls は hover 時のみフェード表示
- top strip の control 以外は drag 可能
- editor の書き始めは surface 左上寄りに置く

collapsed:

- 本文 editor は非表示
- 付箋本体は細長い pill 状の最小 frame になる
- 右上 affordance は `+` または expand icon に統一する
- collapsed 面でも drag 可能
- expanded へ戻した時だけ editor focus を復帰させる

### 責務境界

`MemoWindowController.swift`:

- collapse / expand の window frame 変更を担当する
- collapsed 中の一時 `expandedFrameBeforeCollapse` をメモリ保持する
- `contentMinSize` と collapsed size の切り替えを管理する
- close / reopen / relaunch の frame 保存経路は既存どおり `window.frame` に維持する
- `isMovableByWindowBackground` は `false` のまま維持する

`MemoWindowUIState.swift`:

- `isPinned` と同列の window UI state として `isCollapsed` を持つ
- focus token は既存のまま維持する
- hover 表示状態は持たない

理由:

- hover state は純粋に view 層の一時視覚状態であり persistence も controller 依存も不要
- collapsed は button action と frame 遷移に関わるため、view local state に閉じない方がよい

`MemoWindowView.swift`:

- post-it 一面 UI の SwiftUI 表示責務を持つ
- root hover 検出と control fade animation を持つ
- top strip visual と control 群を描画する
- expanded / collapsed の両レイアウトを分岐する
- editor card 用の独立背景を持たない

`MemoEditorView.swift`:

- editor wrapper 自体は維持する
- 独立 card と border をやめ、親 surface に馴染む最小装飾に変える

`TopStripDragView.swift`（新規）:

- top strip 背景で `performDrag(with:)` を受ける AppKit bridge
- control button hit area を邪魔しない背面 drag plane として使う

`WindowManager.swift`:

- frame persistence の source of truth を引き続き `window.frame` とする
- collapsed/expanded の別 schema は持たない
- reopen 時は保存 frame をそのまま復元する

### AppKit と SwiftUI の境界

AppKit:

- window frame の変更
- live resize
- edge / corner resize
- top strip drag 開始
- close / reopen / relaunch 時の frame 復元

SwiftUI:

- surface 見た目
- hover 検出
- control fade animation
- collapsed / expanded の内容表示切替
- editor 余白と書き出し位置

### collapsed state の source of truth

初期実装では DB に `is_collapsed` や `expanded_frame_*` を追加しない。  
また、collapsed 判定を frame size から推論しない。

採用方針:

- window 生存中の source of truth は `MemoWindowUIState.isCollapsed` のみ
- `window.frame` は `isCollapsed` から導かれる派生結果として扱う
- expand 時の戻り先は controller 内メモリ `expandedFrameBeforeCollapse` に保持する
- close / relaunch を跨いだ collapsed 復元は初期実装では行わない

理由:

- state と frame 推論の二重管理を避ける
- planning guideline の window 制御分散禁止に従う
- relaunch 後に expanded size/location を失う劣化を避ける

明文化する制約:

- collapse は一時 UI state であり、永続状態ではない
- close 時に `isCollapsed == true` なら、保存する frame は `expandedFrameBeforeCollapse` を優先する
- reopen / relaunch 後は expanded 状態で復元する
- collapsed 維持の永続化は別計画に分離し、初期実装では扱わない

### drag と editor の分離

本計画では `window.isMovableByWindowBackground = false` を維持する。  
つまり「editor 面を含む全面 drag」は採用しない。

drag source は次のいずれかで扱う。

採用実装:

- `TopStripDragView` を新規追加し、top strip 背面の drag plane として使う
- control 群はその前面に載せ、button hit area を AppKit drag plane と分離する

採用理由:

- 既存 `WindowDragHandle` の責務を「中央だけ掴める handle」から「帯全体の drag plane」へ書き換えるより責務が明確
- collapsed / expanded の両状態で同じ drag plane を再利用しやすい
- control button hit test と分離しやすい

### hover-only controls

controls の表示状態は root hover だけで決める。

- pointer enter: controls opacity を 1 へ
- pointer leave: controls opacity を 0 へ
- fade duration は `0.12` から `0.18` 秒程度の短い `easeOut`
- expanded 状態では左上 controls と右上 collapse affordance を hover 時のみ表示する
- collapsed 状態では expand affordance だけを常時 low opacity で残し、hover 時に full opacity へ上げる
- collapsed 中の左上 controls は表示しない

注意:

- controls 非表示中でも keyboard shortcut は有効のまま
- `flashCommand` overlay と controls fade のアニメーションが競合しないこと

### editor 書き始め位置

post-it 一面 UI では editor を surface 左上寄りへ寄せる。  
ただし top strip と icon 群の hit area を避けるため、完全に `0,0` へは置かない。

暫定ルール:

- top strip height は 28 から 34pt
- editor content inset top は 8 から 12pt
- 1 行目の caret が controls 群と重ならないことを優先する

### close / reopen / pin / drag の状態遷移

close:

- `isCollapsed == false` なら current frame を保存する
- `isCollapsed == true` なら `expandedFrameBeforeCollapse` を保存する
- `expandedFrameBeforeCollapse` が無い場合のみ current frame を保存する
- `expandedFrameBeforeCollapse` 自体は persistence しない

reopen:

- persisted frame をそのまま復元する
- reopen 後の表示状態は expanded とする
- collapsed 復元は初期実装のスコープ外とする

pin:

- pin / unpin は window level の責務であり、collapsed state と独立
- collapsed 中でも pin 状態は維持する

drag:

- expanded / collapsed の両方で top strip からのみ開始する
- controls / editor は drag source にしない

後続フェーズ衝突:

- Home / Trash / Session には影響しない
- persistence schema 変更がないため既存 DB を壊さない
- 画像貼り付け計画とは独立
- collapsed 永続化が必要になった場合は別計画で扱う

---

## 修正フェーズ

### Phase 6G-0: 参考 UI 方針の SSOT 反映

主目的:

- migration blocker と dedicated drag handle 方針差分を文書上で確定する

対象 Issue:

- `K-30`
- `K-31`
- `K-32`

変更対象:

- 本計画書
- 必要なら `plan-standard-window-resize-ux.md` への参照追記のみ

Gate:

- migration SSOT 不在が「実装ブロッカー」として明記されている
- drag は「editor 面以外の top strip」で行う方針が文書化されている
- `isMovableByWindowBackground = false` 維持が明記されている

### Phase 6G-1: first mouse / focus / drag の独立プローブ

主目的:

- hover-only controls と top strip drag が first mouse / focus / drag hit test を壊さないことを本実装前に単独確認する

対象 Issue:

- `F-30`
- `W-31`

変更対象:

- `MemoWindowView.swift`
- `TopStripDragView.swift`（temporary probe または最小実装）
- `SeamlessHostingView.swift`（観測のみ）
- `CheckableTextView.swift`（観測のみ）
- `MemoWindowUIState.swift`（focus token 経路の観測のみ）
- 必要なら一時的 probe code

内容:

1. top strip drag plane を最小構成で置く
2. hover-only controls の opacity 切替だけを試す
3. `SeamlessHostingView.acceptsFirstMouse` が引き続き non-active click を通す前提を壊していないか確認する
4. `MemoWindowController.showAndFocusEditor() -> MemoWindowUIState.requestEditorFocus() -> CheckableTextView(focusToken)` の focus 経路が hover-only controls 導入後も維持されるか確認する
5. non-active 状態から editor 1 click 入力が維持されるか確認する
6. drag plane と button click が競合しないか確認する

Gate:

- `SeamlessHostingView` 経由の first mouse 許可が維持される
- `focusToken` による editor focus 復帰が維持される
- non-active 状態からの 1 click 入力が維持される
- top strip drag と button click が競合しない
- hover-only controls が focus 奪取や first mouse 破綻を起こさない

### Phase 6G-2: collapse / expand の window core 疎通確認

主目的:

- collapsed frame と expand 復帰先の扱いを window core 単位で確認する

対象 Issue:

- `W-30`
- `W-32`
- `P-30`

変更対象:

- `MemoWindowController.swift`
- 必要なら一時的 probe code

内容:

1. collapsed size を仮決めする
2. `expandedFrameBeforeCollapse` を controller 内メモリで保持する
3. collapse -> expand -> close -> reopen の frame 遷移を確認する
4. relaunch 後も expanded frame がそのまま保存・復元されることを確認する

Gate:

- collapse / expand で window frame が破綻しない
- close / reopen 後も window が画面外へ飛ばない
- relaunch 後も expanded frame 保存経路が既存と競合しない

### Phase 6G-3: single-surface post-it レイアウト化

主目的:

- 二面構造をやめ、一枚の post-it surface に統合する

対象 Issue:

- `U-30`
- `U-32`

変更対象:

- `MemoWindowView.swift`
- `MemoEditorView.swift`

内容:

1. editor 独立 card を除去する
2. top strip と editor を一枚の surface 内に再配置する
3. 1 行目 caret の位置と controls 余白を調整する

Gate:

- expanded 状態で一枚の post-it に見える
- editor の first mouse / ゼロクリック入力が維持される
- editor と controls の hit test が競合しない

### Phase 6G-4: top strip drag と hover-only controls 本実装

主目的:

- 上端帯 drag と controls fade を導入する

対象 Issue:

- `W-31`
- `F-30`
- `U-31`

変更対象:

- `MemoWindowView.swift`
- `TopStripDragView.swift`（必要時）
- `MemoWindowUIState.swift`（必要最小限）

内容:

1. top strip 全体 drag source を実装する
2. controls を hover 時のみ表示する
3. collapsed / expanded の両方で drag が成立することを確認する

Gate:

- top strip の空き領域から drag できる
- control button click と drag が競合しない
- non-active 状態からの 1 click 入力が壊れていない

### Phase 6G-5: collapsed UI の本実装統合

主目的:

- collapsed pill UI と expand affordance を仕上げる

対象 Issue:

- `W-30`
- `W-32`
- `U-31`

変更対象:

- `MemoWindowView.swift`
- `MemoWindowController.swift`
- `MemoWindowUIState.swift`

内容:

1. collapsed 専用レイアウトを入れる
2. expand affordance を確定する
3. hover-only rules を collapsed 状態に適用する

Gate:

- collapsed 見た目が pill 状で破綻しない
- expand 後に editor focus が自然に戻る
- pin / close / trash と collapsed state が競合しない

---

## Gate条件

- migration SSOT 不在を解消するか、planning guideline 側の正式代替手順を先に確立する
- `isMovableByWindowBackground = false` を維持する
- first mouse / ゼロクリック入力を壊さない
- close / reopen / relaunch の frame 保存経路を増やさない
- collapsed 導入のために SQLite schema を増やさない
- 実装後に `xcodebuild` もしくは同等の build を通す

---

## 回帰 / 副作用チェック

- global shortcut から新規 memo を出した直後に即入力できるか
- 非アクティブ状態の open memo を 1 click で編集開始できるか
- pin / unpin 後に level が正しく維持されるか
- drag 中に editor selection や click が誤発火しないか
- live resize 中に surface clipping が破綻しないか
- collapsed 状態で close した memo を reopen しても失われないか
- multiple memo を開いた状態で collapsed / expanded を混ぜても整合するか
- build が通るか

---

## 実機確認項目

1. `Cmd+Option+Enter` で新規 memo を開き、即入力できること
2. expanded 状態で、上端帯の control 以外から drag できること
3. expanded 状態で、editor 面を drag しようとしても text interaction が優先されること
4. hover で controls が fade in し、hover out で fade out すること
5. collapsed ボタンで pill 状へ畳めること
6. collapsed 状態から expand で自然に元サイズへ戻ること
7. collapsed 状態から drag / pin / close が破綻しないこと
8. close -> reopen で frame が保存されること
9. app relaunch 後に open memo が復元されること
10. pinned memo の collapsed / expanded 切替で always-on-top が壊れないこと
11. build が成功すること

---

## 技術詳細確認

### 実装前に決め切ること

- collapsed size の固定値
- collapsed 時の右上 affordance を `+` とし、tooltip / accessibility label で expand を明示する
- collapsed 中は右上 expand affordance だけを残し、左上 controls は隠す
- top strip drag は `TopStripDragView` 新規追加で扱う
- close 中 collapsed でも expanded frame を保存する方針を固定する

### 実装前に決めないこと

- collapsed state の DB 永続化
- 色テーマ再設計
- 画像貼り付けとの統合

---

## セルフチェック結果

### SSOT整合

- [ ] migration README を確認した
- [ ] 01_product_decision を確認した
- [ ] 02_ux_principles を確認した
- [ ] 06_roadmap を確認した
- [ ] 07_project_bootstrap を確認した
- [ ] 09_seamless_ux_spec を確認した
- [x] migration unavailable の現状を確認した
- [x] local docs を確認した
- [x] migration 未確認のままでは実装着手不可と明記した

### 変更範囲

- [x] 主目的は memo window post-it UI への再設計
- [x] 高リスク疎通確認テーマは first mouse / focus / drag probe と collapse / expand window core に分離した
- [x] ついで作業として画像貼り付けを入れていない

### 技術詳細

- [x] ファイルごとの責務が明確
- [x] メモリ管理と persistence の境界が明確
- [x] イベント経路と状態遷移が説明できる

### Window / Focus

- [x] Window 責務が `MemoWindowController` に集約されている
- [x] Focus 制御が UI と AppKit で競合しない方針を置いた
- [x] first mouse への回帰確認を Gate に入れた

### Persistence

- [x] 保存経路は `window.frame` の一本化を維持する
- [x] `isCollapsed` と frame 推論の二重管理を避けた
- [x] collapsed は非永続の一時状態として切り分けた
- [x] relaunch 後も expanded frame/location を失わない方針にした

### 実機確認

- [x] global shortcut を確認項目に入れた
- [x] 1 click 操作を確認項目に入れた
- [x] ゼロクリック入力を確認項目に入れた
- [x] build 確認を項目に入れた

---

## 変更履歴

- 2026-05-01: 初版作成。参考スクショを根拠に memo window の post-it UI / hover-only controls / collapsed state 計画を追加
- 2026-05-01: dedicated drag handle 方針との差分と、`isMovableByWindowBackground = false` 維持を明文化
- 2026-05-01: review findings を反映し、migration blocker 明記、`isCollapsed` を source of truth に一本化、focus probe 追加、collapsed 非永続方針、build Gate 追加
