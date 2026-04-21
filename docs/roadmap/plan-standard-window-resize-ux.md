# Standard Window Resize UX Plan

作成: 2026-04-21  
ステータス: 計画中（実装未着手）

---

## SSOT参照宣言

本計画は以下を上位文書として扱う。

### StickyNative ローカル補助文書

- `docs/product/product-vision.md`
- `docs/product/ux-principles.md`
- `docs/product/mvp-scope.md`
- `docs/architecture/technical-decision.md`
- `docs/roadmap/roadmap.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`
- `docs/roadmap/phase-1-seamless-window-probe-result.md`
- `docs/roadmap/phase-2-window-core-mvp-plan.md`
- `docs/roadmap/plan-memo-window-size-and-color.md`
- `docs/roadmap/bug-window-focus-plan.md`
- `docs/roadmap/bug-nonactivating-panel-focus-failed-attempts.md`

### Apple 参照

- Apple Human Interface Guidelines: Windows
  - macOS window は frame と body area を持ち、ユーザーは frame/edge で移動・resize する
  - custom window frame/control は、完全に system behavior を再現できないと壊れて見えるため避けるべき
- Apple Developer Documentation: `NSWindow`
  - `minSize` は title bar を含む frame size
  - `contentMinSize` は content view size
  - live resize / `preservesContentDuringLiveResize` / `inLiveResize` / resize constraints は window core の責務
- Apple Developer Documentation: `NSWindow.StyleMask.fullSizeContentView`
  - title bar を持つ window で content view を full size に広げるための style mask

### migration 上位文書の確認結果

`docs/roadmap/stickynative-ai-planning-guidelines.md` では `/Users/hori/Desktop/Sticky/migration/*` を SSOT として参照するよう定義されているが、2026-04-21 時点の作業環境では `/Users/hori/Desktop/Sticky` が存在しない。

したがって、本計画ではローカル補助文書、現行実装、Apple 公式情報を根拠とする。ただし、Phase 6F-1 の実装へ進む前に以下のどちらかを必須 Gate とする。

- `/Users/hori/Desktop/Sticky/migration/*` を復旧し、planning guide の migration SSOT と再照合する
- migration SSOT 未確認のまま進める例外理由を本計画書へ追記し、影響範囲が memo window resize/chrome に限定されることを明文化する

### migration SSOT unavailable の例外理由

2026-04-21 時点で `/Users/hori/Desktop/Sticky` が存在せず、migration SSOT を復旧できないため、本計画は以下の制約付きで Phase 6F-0 の調査・プローブまで進める。

- Phase 6F-0 の変更対象を `SeamlessWindow`, `MemoWindowController`, `MemoWindowView` の window chrome / resize / drag に限定する
- persistence schema、draft 保存形式、editor command、Home / Trash / Session には触れない
- `1 memo = 1 window`、global shortcut、first mouse、ゼロクリック入力を Gate として維持する
- Phase 6F-1 の本実装前に、migration SSOT 復旧または例外理由追記を再確認する。Phase 6F-1 では saved frame 復元のため `WindowManager.swift` も実装対象に含める

---

## 背景

現状の memo window は `SeamlessWindow: NSPanel` に対し、`styleMask: [.borderless, .resizable, .fullSizeContentView]` を指定している。

この構成は「見た目はクロームレス付箋」に近いが、Apple 純正 window の resize UX から外れている。ユーザー視点では、resize できる edge の手がかり、hit target、drag と resize の切り分け、window frame と body area の自然さが弱い。

Apple の標準 window は system frame と edge resize を OS が扱うため、resize の当たり判定、cursor feedback、live resize、size constraints が自然に動く。StickyNative でも、見た目だけをクロームレス寄りにしながら、resize 挙動は標準 window に戻す方針を検討する。

---

## 今回触る関連ファイル

既存:

- `StickyNativeApp/SeamlessWindow.swift`
  - `NSPanel` / `NSWindow` subclass の責務確認
  - key/main/focus override の維持確認
- `StickyNativeApp/MemoWindowController.swift`
  - window style mask
  - titlebar / standard controls / transparency
  - `contentMinSize`
  - `isMovableByWindowBackground`
  - focus / pin / close / autosave lifecycle
- `StickyNativeApp/MemoWindowView.swift`
  - custom header
  - drag handle
  - custom close / pin / trash
  - rounded surface / clipping / overlay
- `StickyNativeApp/WindowManager.swift`
  - persisted frame と new content size の分岐
  - `openMemo`, `restorePersistedOpenMemos`, `reopenLastClosedMemo`, `makeController`
- `StickyNativeApp/SeamlessHostingView.swift`
  - first mouse 維持確認

確認のみ:

- `StickyNativeApp/MemoEditorView.swift`
  - editor resize follow
- `StickyNativeApp/CheckableTextView.swift`
  - text layout resize follow

触らない:

- `SQLiteStore.swift`
- `PersistenceCoordinator.swift`
- `AutosaveScheduler.swift`
- `EditorCommand.swift`
- `EditorTextOperations.swift`
- SQLite schema / migration
- Home / Trash / Session UI

スキーマ変更:

- なし

---

## 問題一覧

| ID | 分類 | 内容 |
|---|---|---|
| W-01 | Window | `borderless` window に `.resizable` を付けており、標準 macOS window の resize hit target / cursor feedback / edge behavior から外れている |
| W-02 | Window | `.fullSizeContentView` は title bar 付き window 前提の API だが、現状は `borderless` と組み合わせており責務が曖昧 |
| W-03 | Window | `isMovableByWindowBackground = true` が既存計画の drag handle 限定方針と矛盾している |
| W-04 | Window | size constraint が `window.minSize` と SwiftUI `.frame(minWidth:minHeight:)` に分かれ、frame size / content size の基準が曖昧 |
| U-01 | UI | resize できる場所の視覚的・操作的手がかりが弱く、Apple 純正 window と比べて使い心地が悪い |
| U-02 | UI | custom rounded surface / clipShape / overlay が標準 resize edge の当たり判定や視覚に干渉する可能性がある |
| F-01 | Focus | `NSPanel` / styleMask / titlebar 変更により first mouse、global shortcut 後のゼロクリック入力、Mission Control 復帰に副作用が出る可能性がある |
| P-01 | Persistence | `setContentSize`, saved `window.frame`, `contentMinSize` の基準が混在すると close / reopen / relaunch 後のサイズ復元がズレる可能性がある |
| K-01 | Knowledge | Apple 標準 window に寄せるための style mask / titlebar 方針が未確定 |
| K-02 | Knowledge | migration SSOT が現環境で unavailable であり、本実装へ進む条件が未定義 |

---

## 技術詳細確認

### 目標仕様

memo window は見た目をクロームレス付箋に近く保ちつつ、resize は Apple 標準 window の挙動に寄せる。

採用候補:

```swift
styleMask: [.titled, .resizable, .fullSizeContentView]
window.titleVisibility = .hidden
window.titlebarAppearsTransparent = true
window.standardWindowButton(.closeButton)?.isHidden = true
window.standardWindowButton(.miniaturizeButton)?.isHidden = true
window.standardWindowButton(.zoomButton)?.isHidden = true
window.isMovableByWindowBackground = false
window.contentMinSize = MemoWindowController.minimumContentSize
```

検討対象:

- `SeamlessWindow` を `NSPanel` のまま維持するか、`NSWindow` へ戻すか
- `NSPanel` 維持時に standard titlebar + edge resize が期待どおり動くか
- titlebar transparent + hidden controls で見た目が現行 surface と衝突しないか

### 責務境界

`SeamlessWindow.swift`:

- key/main/focus の基盤挙動だけを持つ
- resize hit testing や custom edge detection を持たない
- `NSPanel` 継続可否は Phase 6F-0 のプローブで判断する

`MemoWindowController.swift`:

- window style mask / titlebar / standard controls / transparency を設定する
- `contentMinSize` を window core の正とする
- `setContentSize` を使う既存サイズ指定と frame persistence の整合を管理する
- `isMovableByWindowBackground = false` を設定し、drag を専用 handle に限定する
- pin / close / focus / save lifecycle は既存どおり維持する

`MemoWindowView.swift`:

- custom header / pin / trash / close / drag handle の SwiftUI UI を持つ
- resize edge の hit testing は持たない
- `clipShape` / overlay / background が標準 window resize edge を阻害する場合、window 側の frame を優先し、SwiftUI surface の丸み表現を調整する

`WindowManager.swift`:

- 既存の frame persistence を維持する
- styleMask 変更で saved frame の意味が変わる場合のみ、移行方針を計画に追記する

### AppKit と SwiftUI の境界

AppKit:

- resize hit target
- cursor feedback
- live resize
- content min size
- window frame / content size conversion
- titlebar / transparent frame

SwiftUI:

- window 内の custom chrome 表示
- drag handle UI
- editor layout
- custom close / pin / trash actions

### サイズの source of truth

本計画では `contentMinSize` を最小サイズの source of truth とする。

理由:

- memo の崩れ防止は content view の最小サイズとして扱うべき
- `window.minSize` は titlebar / frame を含むため、titlebar 構成変更時に意味がズレる
- `setContentSize(size)` と `contentMinSize` を合わせることで、新規 memo の default size と resize constraints の単位を content size に寄せられる
- persisted restore は frame size として扱い、content size へ寄せない

暫定値:

```swift
static let defaultContentSize = NSSize(width: 440, height: 300)
static let minimumContentSize = NSSize(width: 320, height: 220)
window.contentMinSize = Self.minimumContentSize
```

`window.minSize` は原則使わない。必要な場合のみ、AppKit の frame/content 変換後の値として補助的に使う。

### frame persistence の source of truth

DB の `origin_x`, `origin_y`, `width`, `height` は既存どおり window frame rect として扱う。schema は変更しない。

理由:

- 現行の保存経路は `MemoWindowController.windowWillClose` / app shutdown で `window.frame` を保存している
- `SQLiteStore` の `width` / `height` は既存データ上 frame size として蓄積されている
- titlebar 化後に同じ値を `setContentSize(size)` に渡すと、frame size を content size と誤解し、titlebar 分だけ close / reopen / relaunch のたびにサイズがズレる可能性が高い

採用方針:

- 保存時: 引き続き `window.frame` を保存する
- 復元時: DB の `origin_x`, `origin_y`, `width`, `height` から `NSRect` を作り、`window.setFrame(_:display:)` で復元する
- 新規作成時: user default の memo size は content size として扱い、`setContentSize(size)` を使う
- open/relaunch 復元時: persisted size は frame size として扱い、`setContentSize(size)` には渡さない
- clamping: `clampedFrame(_:)` は frame rect に対して適用する

責務:

- `WindowManager`
  - persisted `origin/width/height` を frame rect として `MemoWindowController` へ渡す
  - 新規 memo 作成時の default content size と、既存 memo 復元時の frame rect を区別する
  - `makeController` の引数を `contentSize` と `savedFrame` のように分ける
  - `openMemo`, `restorePersistedOpenMemos` では persisted values から `savedFrame` を組み立てる
  - `reopenLastClosedMemo` の復元優先順位は `ClosedMemoRecord.frame` > persisted frame > default content size とする
- `MemoWindowController`
  - 新規作成時は content size を受け取れる
  - 復元時は saved frame を受け取り `setFrame` で適用する
  - close 時は `window.frame` を返す
- `PersistenceCoordinator`
  - schema 変更なし
  - 保存値は frame rect のまま

### drag と resize の分離

drag:

- `WindowDragHandleView.mouseDown` で `window?.performDrag(with:)`
- header 中央の drag handle のみ
- pin / trash / close / editor は drag 不可

resize:

- AppKit standard frame / edge resize に任せる
- SwiftUI 側で custom resize handle を作らない
- `isMovableByWindowBackground = false`

---

## 修正フェーズ

### Phase 6F-0: Standard Window Probe

目的:

- `borderless` を外し、standard titlebar を透明化した window で Apple 標準 resize UX に寄せられるかを小さく確認する。

対象ファイル:

- `StickyNativeApp/MemoWindowController.swift`
- 必要なら `StickyNativeApp/SeamlessWindow.swift`

実装内容:

- `styleMask` を `.titled, .resizable, .fullSizeContentView` 系へ変更するプローブ
- `titleVisibility = .hidden`
- `titlebarAppearsTransparent = true`
- standard window buttons を非表示
- `contentMinSize` を設定
- `isMovableByWindowBackground = false`
- custom drag handle は維持

Gate:

- window edge resize が Apple 標準に近い hit target / cursor feedback で動く
- resize 中に window が消えない
- resize 中に editor / header が破綻しない
- custom close / pin / trash が動く
- drag は dedicated handle のみで動く
- editor 領域ドラッグで window が動かない
- first mouse が壊れない
- global shortcut 後にゼロクリック入力できる
- Mission Control / app switch 復帰で focus が悪化しない
- プローブ結果を本計画の変更履歴または dedicated probe result 文書へ追記する
- Phase 6F-1 へ昇格する前に、不要ログ・一時コード・比較用 variant を削除または本実装へ置換する
- Gate 不通過時はプローブ差分を残さず、fallback 計画へ移る

判定:

- Gate 通過なら Phase 6F-1 で本実装へ進む
- Gate 不通過なら `borderless` 維持 + custom resize edge 実装案を別計画として分離する

### NSPanel / NSWindow variant の分岐条件

最初に試す variant:

- `SeamlessWindow: NSPanel`
- `styleMask: [.titled, .resizable, .fullSizeContentView]`
- transparent titlebar
- standard buttons hidden

NSWindow variant を試す条件:

- `NSPanel + titled` で edge / corner resize の hit target または cursor feedback が標準 window と比べて明確に劣る
- `NSPanel + titled` で first mouse / zero click / Mission Control 復帰のいずれかが悪化する
- `NSPanel + titled` で titlebar / hidden standard controls が表示崩れまたは window 消滅を起こす

NSWindow variant の追加 Gate:

- `canBecomeKey` / `canBecomeMain` 相当の挙動が memo editor focus に十分である
- global shortcut 後に `showAndFocusEditor()` で前面化し、ゼロクリック入力できる
- pin ON 時に `.floating` level が維持される
- close / reopen / relaunch で frame と focus が破綻しない
- nonactivating/accessory app 前提の挙動が悪化しない

### Phase 6F-1: Standard Resize Implementation

目的:

- Phase 6F-0 の通過結果を本実装として固定し、window resize を Apple 標準挙動へ寄せる。

対象ファイル:

- `StickyNativeApp/MemoWindowController.swift`
- `StickyNativeApp/MemoWindowView.swift`
- `StickyNativeApp/WindowManager.swift`
- 必要なら `StickyNativeApp/SeamlessWindow.swift`

実装内容:

- `styleMask` を標準 titlebar 付き構成に固定
- titlebar / standard buttons の表示方針を固定
- `contentMinSize` を window core の正にする
- `window.minSize` 依存を除去または補助扱いへ変更
- persisted `width` / `height` は frame size として扱い、復元時は `setFrame` を使う
- 新規 memo 作成時の default size は content size として扱い、`setContentSize` を使う
- `WindowManager.makeController` の引数を `contentSize` と `savedFrame` に分ける
- `WindowManager.openMemo` / `restorePersistedOpenMemos` は persisted origin/width/height から `savedFrame` を作る
- `WindowManager.reopenLastClosedMemo` は `ClosedMemoRecord.frame` > persisted frame > default content size の優先順位で復元元を決める
- `isMovableByWindowBackground = false`
- `WindowDragHandle` のみ drag 可能にする
- SwiftUI `clipShape` / overlay が edge resize を邪魔する場合、見た目を最小限調整

Gate:

- default size `440x300` で開く
- minimum content size `320x220` まで自然に縮む
- saved frame から reopen / relaunch してサイズがズレない
- close / reopen / relaunch を繰り返しても titlebar 分のサイズ増殖が起きない
- edge / corner resize が標準 macOS window に近い
- drag handle と resize edge が競合しない
- custom close / pin / trash が既存どおり動く
- pin / unpin の window level が既存どおり動く
- editor 入力、IME、scroll、checkbox command が壊れない

### Phase 6F-2: Regression Gate

目的:

- window chrome 変更が seamless UX と persistence に副作用を出していないことを実機で確認する。

対象ファイル:

- 原則コード変更なし
- regression が出た場合のみ Phase 6F-1 対象ファイル

Gate:

- `Cmd+Option+Enter` で新規 memo が即座に出る
- 新規 memo 表示直後にゼロクリック入力できる
- 非アクティブ状態から 1 click で入力できる
- close / reopen でサイズ・位置・本文が復元される
- app relaunch 後に open memo が復元される
- 複数 memo window で key / focus / resize が混線しない
- Home / Settings など通常 `NSWindow` との挙動差が問題にならない

---

## Issue → Phase 対応

| Issue | 対応 Phase | 解決 / 確認内容 |
|---|---|---|
| W-01 | Phase 6F-0, 6F-1 | `borderless` を外した standard titlebar 構成で edge resize を AppKit 標準へ寄せる |
| W-02 | Phase 6F-0, 6F-1 | `.fullSizeContentView` を titlebar 付き window で使う構成へ正す |
| W-03 | Phase 6F-1 | `isMovableByWindowBackground = false` にし、drag handle 限定へ戻す |
| W-04 | Phase 6F-1 | `contentMinSize` を source of truth にして content size 基準へ揃える |
| U-01 | Phase 6F-0, 6F-2 | resize hit target / cursor feedback / edge behavior を実機で確認する |
| U-02 | Phase 6F-1, 6F-2 | SwiftUI surface が standard resize edge を阻害しないか確認し、必要最小限に調整する |
| F-01 | Phase 6F-0, 6F-2 | first mouse / global shortcut / Mission Control / focus regression を実機確認する |
| P-01 | Phase 6F-1, 6F-2 | DB の width/height を frame size として維持し、復元時は `setFrame` を使うことで `setContentSize` との単位ズレを防ぐ |
| K-01 | Phase 6F-0 | Apple 標準 window へ寄せる style mask / titlebar 方針をプローブで確定する |
| K-02 | Phase 6F-0 | migration SSOT 復旧または例外理由追記を Phase 6F-1 前の Gate とする |

---

## Gate条件

- Phase 6F-0 のプローブを本実装と混ぜない
- `borderless` 解除で window 消滅 / focus regression が出ないことを確認してから Phase 6F-1 へ進む
- migration SSOT を復旧して再照合する、または未確認で進める例外理由を文書化するまで Phase 6F-1 に進まない
- resize hit testing は AppKit 標準に任せ、SwiftUI に custom resize handle を作らない
- drag は dedicated handle のみ
- window size constraint は `contentMinSize` を source of truth にする
- persisted `width` / `height` は frame size として扱い、復元時は `setFrame` を使う
- 新規作成 default size は content size として扱い、`setContentSize` を使う
- persistence schema は変更しない
- `1 memo = 1 window` と seamless UX を維持する

---

## 回帰 / 副作用チェック

| 確認項目 | 懸念 | 対策 |
|---|---|---|
| focus | `borderless` 解除 / titlebar 追加で first mouse や key window 挙動が変わる | Phase 6F-0 で小さくプローブし、first mouse / zero click を Gate 化 |
| Mission Control | `NSPanel` / `NSWindow` / titlebar 構成変更で復帰時 focus が悪化する | bug-window-focus-plan の既知問題と照合し、実機 Gate に含める |
| window visibility | 過去に `.nonactivatingPanel` 削除で window 消滅があった | `.nonactivatingPanel` ではなく `borderless` / titlebar 方針を個別に検証する |
| drag conflict | `isMovableByWindowBackground = true` が editor 操作と競合する | `false` に戻し、`WindowDragHandle` のみで `performDrag` |
| resize edge | SwiftUI `clipShape` / overlay が edge resize を邪魔する | AppKit frame を優先し、surface の clipping を必要最小限に調整 |
| size persistence | frame / content size の基準差で reopen 後にサイズがズレる | DB width/height は frame size のまま維持し、復元時は `setFrame`、新規作成時だけ `setContentSize` を使う |
| standard buttons | hidden standard controls と custom controls が二重化する | standard buttons は hide、custom controls を維持 |
| visual design | titlebar 付き構成で現行付箋感が崩れる | titlebar transparent + hidden controls + fullSizeContentView で見た目を維持 |

---

## 実機確認項目

- [ ] window edge / corner で resize cursor が自然に出る
- [ ] edge / corner drag で Apple 標準 window に近い感覚で resize できる
- [ ] resize 中に window が消えない
- [ ] resize 中に header / editor / buttons が破綻しない
- [ ] default size `440x300` で新規 memo が開く
- [ ] minimum content size `320x220` まで縮められる
- [ ] editor 領域をドラッグしても window が動かない
- [ ] header drag handle では window が動く
- [ ] pin / trash / close button と drag が競合しない
- [ ] custom close button が動く
- [ ] pin / unpin が window level として動く
- [ ] `Cmd+Option+Enter` 後にゼロクリック入力できる
- [ ] 非アクティブ状態から 1 click 入力できる
- [ ] 日本語 IME 入力・変換・確定が正常
- [ ] close / reopen 後に位置・サイズ・本文が復元される
- [ ] app relaunch 後に open memo の位置・サイズ・本文が復元される
- [ ] close / reopen / relaunch を複数回繰り返しても titlebar 分のサイズ増殖が起きない
- [ ] 複数 memo window で resize / focus が混線しない

---

## 技術詳細確認

### 実装者が迷わないための決定

- resize UX の第一候補は standard titlebar 付き window + transparent titlebar
- `borderless` 維持 + custom edge resize は fallback とし、Phase 6F-0 失敗時の別計画に分離する
- `isMovableByWindowBackground = false`
- drag は `WindowDragHandleView.mouseDown -> performDrag(with:)` のみ
- `contentMinSize` を最小サイズの source of truth にする
- `window.minSize` は原則使わない
- DB の persisted width / height は frame size として維持する
- persisted frame 復元時は `setFrame` を使う
- 新規 memo 作成時の default size のみ content size として `setContentSize` を使う
- standard window buttons は hide し、既存 custom buttons を維持する
- persistence schema は変更しない
- saved `window.frame` の復元経路は維持する

### 想定コード変更

`MemoWindowController.swift`:

- `styleMask` を `.titled, .resizable, .fullSizeContentView` 系へ変更
- `titleVisibility = .hidden`
- `titlebarAppearsTransparent = true`
- standard window buttons hide
- `contentMinSize = Self.minimumContentSize`
- `isMovableByWindowBackground = false`
- `minSize` の扱いを見直す
- saved frame 復元用 initializer path と、新規 content size 用 initializer path を分離する

`WindowManager.swift`:

- `makeController` の引数を `contentSize: NSSize?` と `savedFrame: NSRect?` のように分ける
- `createNewMemoWindow` は `contentSize` に app setting の default memo size を渡す
- `openMemo` は persisted `origin_x`, `origin_y`, `width`, `height` から `savedFrame` を作って渡す
- `restorePersistedOpenMemos` は persisted frame を `savedFrame` として渡す
- `reopenLastClosedMemo` は `ClosedMemoRecord.frame` があれば最優先で `savedFrame` として渡す
- `ClosedMemoRecord.frame` が nil で persisted frame がある場合は persisted frame を `savedFrame` として渡す
- `ClosedMemoRecord.frame` も persisted frame もない場合のみ、default content size を使う
- controller 作成後の `clampedFrame` は frame rect に対して適用する

`MemoWindowView.swift`:

- `WindowDragHandle` を維持
- 必要なら edge resize を邪魔する outer `clipShape` / overlay を調整
- custom close / pin / trash は維持

`SeamlessWindow.swift`:

- `NSPanel` 維持で通るか確認
- 必要なら `NSWindow` variant のプローブを行う
- focus logging は実装時に不要なら削除候補。ただし本計画ではログ削除を主目的にしない

### 後続 Phase との衝突確認

- Editor scroll layout stability の `CheckableTextView` 修正には触れない
- color theme / material tint は維持する
- Home / Settings の通常 `NSWindow` には触れない
- persistence schema は変更しない

---

## セルフチェック結果

### SSOT整合

[x] `docs/roadmap/stickynative-ai-planning-guidelines.md` を確認した  
[x] `docs/product/product-vision.md` を確認した  
[x] `docs/product/ux-principles.md` を確認した  
[x] `docs/product/mvp-scope.md` を確認した  
[x] `docs/architecture/technical-decision.md` を確認した  
[x] `docs/roadmap/phase-2-window-core-mvp-plan.md` を確認した  
[x] `docs/roadmap/plan-memo-window-size-and-color.md` を確認した  
[x] Apple HIG / AppKit window docs を確認対象に含めた  
[x] migration SSOT の指定パスが現環境に存在しないことを明記した

### 変更範囲

[x] 主目的は memo window resize UX の標準化 1 つ  
[x] Phase 6F-0 と 6F-1 を分け、プローブと本実装を混ぜない  
[x] persistence / editor command / Home / Trash / Session をスコープ外にした

### 技術詳細

[x] ファイルごとの責務が明確  
[x] AppKit と SwiftUI の責務境界が明確  
[x] size constraint の source of truth が明確  
[x] drag と resize の操作責務が明確
[x] persisted frame と new content size の扱いが明確
[x] `WindowManager` の content size / saved frame 分岐責務が明確

### Window / Focus

[x] first mouse / zero click / Mission Control を Gate に含めた  
[x] `isMovableByWindowBackground` と drag handle の方針を明記した  
[x] `NSPanel` / `NSWindow` の継続判断を Phase 6F-0 に分離した
[x] NSPanel / NSWindow variant の分岐条件を明記した

### Persistence

[x] SQLite schema 変更なし  
[x] saved frame 復元を実機 Gate に含めた  
[x] relaunch 時の扱いを変更しない

---

## 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-04-21 | 初版作成。Apple 標準 window resize UX に寄せるため、`borderless` から standard titlebar + transparent chrome へ移行するプローブ / 実装計画を定義 |
| 2026-04-21 | レビュー指摘対応。Home subtitle 修正を別計画へ切り出す方針に戻し、DB width/height を frame size として維持して復元時は `setFrame` を使う方針、プローブ結果記録/昇格条件、NSPanel/NSWindow variant 分岐条件を明文化 |
| 2026-04-21 | 追加レビュー指摘対応。`WindowManager.swift` を Phase 6F-1 の実装対象へ移し、`makeController` で `contentSize` と `savedFrame` を分ける方針、`openMemo` / `restorePersistedOpenMemos` / `reopenLastClosedMemo` の変更箇所を明記。サイズ source of truth 節の古い restored size 表現を削除 |
| 2026-04-21 | 追加レビュー指摘対応。migration unavailable 例外の変更対象を Phase 6F-0 限定と明記し、Phase 6F-1 では `WindowManager.swift` を含めると追記。`reopenLastClosedMemo` の frame 優先順位を `ClosedMemoRecord.frame` > persisted frame > default content size に固定 |
