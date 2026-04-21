# Editor Scroll Layout Stability Plan

作成: 2026-04-21  
ステータス: 計画中（実装未着手）

---

## SSOT参照宣言

本計画は以下を上位文書として扱う。

### StickyNative ローカル補助文書

- `docs/product/ux-principles.md`
- `docs/product/product-vision.md`
- `docs/product/mvp-scope.md`
- `docs/architecture/technical-decision.md`
- `docs/roadmap/roadmap.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`
- `docs/roadmap/plan-checkbox-feature.md`
- `docs/roadmap/plan-editor-command-expansion.md`

### migration 上位文書の確認結果

`docs/roadmap/stickynative-ai-planning-guidelines.md` では `/Users/hori/Desktop/Sticky/migration/*` を SSOT として参照するよう定義されているが、2026-04-21 時点の作業環境では `/Users/hori/Desktop/Sticky` が存在しない。

したがって、本計画ではローカル補助文書と現行実装を根拠とする。ただし、Phase 6E-1 の実装へ進む前に、以下のどちらかを必須 Gate とする。

- `/Users/hori/Desktop/Sticky/migration/*` を復旧し、planning guide の migration SSOT と再照合する
- migration SSOT 未確認のまま進める例外理由を本計画書へ追記し、影響範囲が `CheckableTextView.swift` の editor layout に限定されることを明文化する

### migration SSOT unavailable の例外理由

2026-04-21 時点で `/Users/hori/Desktop/Sticky` が存在せず、migration SSOT を復旧できないため、本修正は以下の制約付きで Phase 6E-1 へ進める。

- 変更対象を `StickyNativeApp/CheckableTextView.swift` の editor 内部 layout に限定する
- `WindowManager` / `MemoWindowController` / persistence / shortcut / command expansion には触れない
- 保存形式、SQLite schema、reopen 仕様、`1 memo = 1 window` の表示モデルを変更しない
- 実装後に first mouse、ゼロクリック入力、IME、close / reopen を Gate として確認する

この例外は migration SSOT の恒久的な代替ではない。migration 文書が復旧された場合は、本計画の次回更新時に再照合する。

---

## 背景

`CheckableTextView` 導入後、memo editor は AppKit の `NSScrollView` + `NSTextView` で構成されている。

メモ分量が増えた時に以下の UX 問題が発生している。

- 右側に縦スクロールインジケータが出て、狭い memo window では本文の邪魔になる
- 本文右端の文字が見切れる
- 見切れや折り返しが発生するタイミングで文字レイアウトが小刻みに揺れる

StickyNative の優先事項は「すぐ書ける」「思考を止めない」ことであり、スクロール表示やレイアウト揺れは editor core の polish ではなく、入力体験の基盤問題として扱う。

---

## 今回触る関連ファイル

既存:

- `StickyNativeApp/CheckableTextView.swift`
  - `NSScrollView` / `NSTextView` の生成・設定
  - text container の幅・余白・scroll behavior の調整
  - SwiftUI update 時の再設定範囲の整理

確認のみ:

- `StickyNativeApp/MemoEditorView.swift`
  - editor surface の SwiftUI 側 padding / background
- `StickyNativeApp/MemoWindowView.swift`
  - window 内の editor 配置
- `StickyNativeApp/MemoWindowController.swift`
  - focus / window lifecycle の回帰確認

触らない:

- `SQLiteStore.swift`
- `PersistenceCoordinator.swift`
- `AutosaveScheduler.swift`
- `MemoWindow.swift`
- `EditorCommand.swift`
- `EditorTextOperations.swift`

スキーマ変更:

- なし

---

## 問題一覧

| ID | 分類 | 内容 |
|---|---|---|
| U-01 | UI | メモ分量が増えると右側に縦スクロールインジケータが表示され、本文操作の邪魔になる |
| U-02 | UI | 右端の文字が editor surface の内側で見切れる |
| U-03 | UI | 見切れ・折り返し発生時に文字レイアウトがガクガク動く |
| A-01 | Architecture | `configure(_:)` が `updateNSView` ごとに実行され、初期設定と動的更新の責務が混在している |
| A-02 | Architecture | `textContainer.containerSize.width` が `textView.bounds.width` そのままで、`textContainerInset` と有効本文幅の整合が取れていない |
| F-01 | Focus | `NSScrollView` / `NSTextView` 設定変更により first mouse / ゼロクリック入力へ副作用が出る可能性がある |
| P-01 | Persistence | editor 内部設定の修正後も `memo.draft -> AutosaveScheduler -> SQLite` の保存経路を維持する必要がある |
| K-01 | Knowledge | macOS 標準のスクローラー表示を抑制する理由を計画内に残す必要がある |
| K-02 | Knowledge | migration SSOT が現環境で unavailable であり、未確認のまま実装へ進む条件が未定義 |

---

## 技術詳細確認

### 責務境界

`CheckableTextView.swift`:

- `NSScrollView` の縦スクロール可否、scroller 表示、background、border を設定する
- `CheckboxNSTextView` の text container inset、line fragment padding、container size、resizable 設定を管理する
- `NSTextViewDelegate` 経由で `@Binding<String>` に本文変更を戻す
- focus / first mouse / keyDown / context menu の既存責務を維持する
- SQLite、autosave、window frame は扱わない

`MemoEditorView.swift`:

- SwiftUI 側の editor hosting と visual surface のみを扱う
- `CheckableTextView` の内部 layout 幅や scroller 表示方針は持たない

`MemoWindowController.swift`:

- window lifecycle / focus request を維持する
- editor scroll layout の詳細設定は持たない

### AppKit と SwiftUI の境界

AppKit:

- 実際の text layout、scroll、selection、IME、first responder を担当する
- `NSTextView` の有効本文幅を inset-aware に計算する
- scroller 表示を抑制しても wheel / trackpad scrolling は維持する

SwiftUI:

- editor view を window layout に配置する
- focus visual state と theme background を描画する
- text layout の再計算には直接関与しない

### メモリで持つ情報

新規 persistence は追加しない。

必要であれば `Coordinator` に UI 内部状態として以下を持つ。

- 最後に適用した font size
- 最後に適用した text container width
- bounds change を購読中の `observedContentView`
- bounds change observer token

これらは layout 再適用を最小化するための transient state であり、reopen / relaunch 後に復元しない。

### text layout width の source of truth

本文レイアウト幅の source of truth は `NSScrollView.contentView.bounds.width` とする。

理由:

- editor の実表示可能幅は `NSScrollView` の clip view が決める
- `textView.bounds.width` は初回 layout 前や live resize 中に古い値を返す可能性がある
- scroller の visual 表示を抑制するため、scroller 幅を本文幅計算へ混ぜない

採用する計算式:

```swift
let horizontalInset = textView.textContainerInset.width * 2
let availableTextWidth = max(0, scrollView.contentView.bounds.width - horizontalInset)
textView.textContainer?.lineFragmentPadding = 0
textView.textContainer?.widthTracksTextView = false
textView.textContainer?.containerSize = NSSize(
  width: availableTextWidth,
  height: CGFloat.greatestFiniteMagnitude
)
```

本文の最終的な描画領域は以下で固定する。

```text
visible editor width
  = scrollView.contentView.bounds.width

text drawing width
  = visible editor width
    - textContainerInset.width * 2
    - lineFragmentPadding * 2

lineFragmentPadding
  = 0
```

これにより、左右余白は `textContainerInset` のみに集約する。`lineFragmentPadding` と `textContainerInset` の二重余白は作らない。

manual `containerSize` を採用するため、`textContainer.widthTracksTextView` は `false` に固定する。既存実装の `widthTracksTextView = true` を残すと、AppKit が text view 幅に追従して `containerSize` を更新し、`contentView.bounds.width - inset * 2` の source of truth と競合する可能性があるため採用しない。

### resize 時の再計算トリガー

`updateNSView` が live resize や `NSScrollView.contentView.bounds` 変更ごとに必ず呼ばれる前提は置かない。

Phase 6E-1 では、`NSScrollView.contentView` の bounds change を AppKit 側で拾って text container width を更新する。実装候補は以下とする。

- `scrollView.contentView.postsBoundsChangedNotifications = true`
- `Coordinator` が `NSView.boundsDidChangeNotification` を購読する
- 通知元は `scrollView.contentView` に限定する
- 通知時に `applyTextContainerWidth(scrollView:textView:)` を呼び、前回 width と変わった場合のみ `containerSize` を更新する
- `Coordinator` は `observedContentView` と `boundsObserver` を保持する
- 同一 `contentView` が既に登録済みの場合は再登録しない
- 別 `contentView` へ差し替わる場合のみ、旧 observer を解除してから登録し直す
- `deinit` または view teardown で notification observer を解除する

manual `containerSize` を採用する理由:

- 既存実装は `widthTracksTextView = true` を使っているが、`textContainerInset` と有効本文幅の整合が取れていない
- `widthTracksTextView` だけに寄せると、inset-aware な本文幅計算と resize notification の責務が曖昧になる
- 今回は「scroller 非表示」「本文右端見切れ」「resize 中の揺れ」を同じ source of truth で抑えるため、`contentView.bounds.width` 基準の manual width 更新に固定する

### イベント経路

通常入力:

```text
keyboard / IME input
  -> CheckboxNSTextView
  -> NSTextStorage update
  -> Coordinator.textDidChange
  -> memo.draft
  -> AutosaveScheduler
  -> PersistenceCoordinator.saveDraft
```

スクロール:

```text
trackpad / mouse wheel
  -> NSScrollView
  -> documentView scroll
  -> text content offset changes only
```

layout 更新:

```text
SwiftUI updateNSView
  -> CheckableTextView applies only changed layout values
  -> no draft change

NSScrollView.contentView bounds change
  -> Coordinator receives NSView.boundsDidChangeNotification
  -> CheckableTextView applies inset-aware text container width
  -> NSTextContainer width remains inset-aware
  -> no draft change
```

### スクローラー非表示の理由

macOS 標準ではスクロール可能領域に縦スクローラーが表示される場合がある。StickyNative の memo window は小さく、右端の可読幅が重要なため、editor 内では visual scroller を抑制する。

ただし、スクロール操作そのものは維持する。これは「標準 macOS 挙動を完全に無効化する」のではなく、「小型 memo surface で本文を邪魔する visual indicator を出さない」ための UI 方針とする。

---

## 修正フェーズ

### Phase 6E-0: Baseline Confirmation

目的:

- 現象と原因を `CheckableTextView` の AppKit layout 設定に絞り、実装前の確認観点を固定する。

対象ファイル:

- コード変更なし
- 本計画書のみ

確認内容:

- `scrollView.hasVerticalScroller = true` により visual scroller が出る
- `textContainerInset.width` と `textContainer.containerSize.width` が整合していない
- `updateNSView` ごとの `configure(_:)` 再適用が layout 揺れの原因候補になっている

Gate:

- migration SSOT を復旧して再照合する、または未確認で進める例外理由を本計画書へ追記する
- 問題一覧 U-01 / U-02 / U-03 / A-01 / A-02 / F-01 / P-01 / K-01 / K-02 が Phase / Gate に対応している
- persistence / window lifecycle / command expansion をスコープ外にできている

### Phase 6E-1: Editor Scroll And Text Width Stabilization

目的:

- editor の visual scroller、右端見切れ、折り返し時のレイアウト揺れを `CheckableTextView` 内で解消する。

対象ファイル:

- `StickyNativeApp/CheckableTextView.swift`

実装方針:

- `NSScrollView` はスクロール可能なまま、visual vertical scroller を表示しない設定にする
- `NSTextView` の `textContainerInset` と `textContainer.containerSize.width` を `NSScrollView.contentView.bounds.width` 基準で整合させる
- `lineFragmentPadding = 0` を明示し、左右余白を `textContainerInset` 側に集約する
- manual `containerSize` と競合させないため、`textContainer.widthTracksTextView = false` にする
- `availableTextWidth = max(0, scrollView.contentView.bounds.width - textView.textContainerInset.width * 2)` を本文幅の計算式として固定する
- `NSScrollView.contentView` の bounds change notification を購読し、live resize / window resize 中も text container width を更新する
- bounds observer は `Coordinator.observedContentView` / `Coordinator.boundsObserver` で管理し、同一 contentView への重複登録を禁止する
- 初期設定と更新時設定を分ける
- `updateNSView` では毎回全設定を再適用せず、font size / layout width / binding text など変化した値だけ反映する
- 外部から `text` が変わった時のみ `textView.string` を差し替え、通常入力時の textStorage を不用意に置き換えない

非目標:

- editor command の追加
- Home / Trash / Session の変更
- font size 設定 UI の変更
- memo window のサイズ制約変更
- SQLite schema / persistence 経路の変更

Gate:

- `NSScrollView.contentView.bounds.width` が text layout width の source of truth になっている
- `textContainer.widthTracksTextView = false` になっており、manual `containerSize` 更新と競合していない
- live resize / window resize 時に `NSView.boundsDidChangeNotification` 経由で text container width が更新される
- 同一 `contentView` への bounds observer 重複登録が起きない
- `lineFragmentPadding = 0` かつ `availableTextWidth = contentView.bounds.width - horizontalInset` の式で二重 inset が発生しない
- 右側の縦スクロールインジケータが memo editor 内に表示されない
- 長文でも右端の文字が editor background 内で見切れない
- 行末折り返し時に本文が横方向へガクガク動かない
- trackpad / mouse wheel で縦スクロールできる
- 日本語 IME 入力・変換・確定が正常
- `Cmd+S`, `Cmd+W`, `Cmd+Enter`, `Cmd+L` が既存どおり動く
- close / reopen 後に draft が復元される

### Phase 6E-2: Regression Gate

目的:

- editor layout 修正が StickyNative の seamless UX を壊していないことを実機で確認する。

対象ファイル:

- 原則コード変更なし
- Phase 6E-1 で見つかった regression の修正が必要な場合のみ `CheckableTextView.swift`

Gate:

- global shortcut 後にゼロクリック入力できる
- 非アクティブ状態から 1 click で入力できる
- window resize 後も右端見切れが再発しない
- 小さい memo window と default size の両方で折り返しが安定する
- 長文 memo でスクロール位置が入力中に不自然に跳ねない

---

## Issue → Phase 対応

| Issue | 対応 Phase | 解決 / 確認内容 |
|---|---|---|
| U-01 | Phase 6E-1, 6E-2 | visual vertical scroller を非表示にし、実機で長文スクロール時に邪魔な indicator が出ないことを確認 |
| U-02 | Phase 6E-1, 6E-2 | `contentView.bounds.width` 基準の inset-aware 幅計算で右端見切れを解消し、resize 後も確認 |
| U-03 | Phase 6E-1, 6E-2 | 初期設定と動的更新を分離し、width 変更時だけ text container を更新して layout jitter を抑える |
| A-01 | Phase 6E-1 | `configure(_:)` の責務を initial setup / dynamic update に分け、`updateNSView` の全設定再適用をやめる |
| A-02 | Phase 6E-1 | `widthTracksTextView = false` にしたうえで `availableTextWidth = max(0, contentView.bounds.width - textContainerInset.width * 2)` に固定する |
| F-01 | Phase 6E-2 | first mouse / ゼロクリック入力 / focusToken 経路の regression を実機確認する |
| P-01 | Phase 6E-1, 6E-2 | layout 更新では `didChangeText` を呼ばず、保存経路が既存 autosave のままであることを確認 |
| K-01 | Phase 6E-0 | visual scroller 抑制の理由を計画内に文書化する |
| K-02 | Phase 6E-0 | migration SSOT 復旧または例外理由追記を Phase 6E-1 前の Gate とする |

---

## Gate条件

- 変更の主目的は editor scroll / layout stability の 1 つに収まっている
- 変更ファイルは原則 `CheckableTextView.swift` のみ
- migration SSOT を復旧して再照合する、または未確認で進める例外理由を文書化するまで Phase 6E-1 に進まない
- `MemoEditorView` / `MemoWindowView` に layout workaround を分散させない
- `WindowManager` / `MemoWindowController` に editor 内部 layout の責務を持ち込まない
- text layout width の source of truth は `NSScrollView.contentView.bounds.width` に固定する
- manual `containerSize` を採用するため `textContainer.widthTracksTextView = false` に固定する
- resize 時の text container width 更新は `NSView.boundsDidChangeNotification` で拾う
- bounds observer は同一 `contentView` へ重複登録しない
- 保存経路は `memo.draft -> AutosaveScheduler -> PersistenceCoordinator -> SQLite` のまま
- AppKit scroller 表示を抑制する理由が文書化されている
- first mouse / focus regression がない

---

## 回帰 / 副作用チェック

| 確認項目 | 懸念 | 対策 |
|---|---|---|
| first mouse | `NSScrollView` / documentView 設定変更で 1 click 入力が壊れる | `CheckboxNSTextView.acceptsFirstMouse` を維持し実機確認 |
| focus | `updateNSView` の整理で focusToken 処理が抜ける | focusToken 経路は既存のまま残す |
| IME | textStorage 差し替えや layout 再計算が変換中入力に干渉する | 通常入力中は `textView.string` を置き換えない |
| scrolling | scroller 非表示と同時にスクロール操作まで失われる | visual scroller 非表示と scroll capability を分離して確認 |
| wrapping | inset と container width の二重計算で逆に余白が広がりすぎる | `lineFragmentPadding = 0` と `availableTextWidth = contentView.bounds.width - inset * 2` を固定し、default size / minimum size / resize 後で確認 |
| container width ownership | `widthTracksTextView = true` が残り manual `containerSize` と競合する | `widthTracksTextView = false` に固定する |
| resize | live resize 中に `updateNSView` が呼ばれず text container width が古くなる | `NSScrollView.contentView` の bounds change notification で再計算する |
| observer duplication | 同一 `contentView` に observer が複数登録され、resize ごとの layout 更新が重複する | `Coordinator` に `observedContentView` / `boundsObserver` を持たせ、同一 view は再登録しない |
| autosave | layout 更新で不要な text change が発火する | layout update では `didChangeText` を呼ばない |
| command | `Cmd+L` など editor command が動かなくなる | `keyDown` と command dispatch は変更しない |

---

## 実機確認項目

- [ ] 新規 memo を開き、ゼロクリックで入力できる
- [ ] 非アクティブ状態の memo window を 1 click してそのまま入力できる
- [ ] 長文を入力しても右側に縦スクロールインジケータが出ない
- [ ] 長文を入力しても右端の文字が見切れない
- [ ] 行末で折り返される時に文字がガクガクしない
- [ ] trackpad / mouse wheel で縦スクロールできる
- [ ] window を最小幅付近まで縮めても本文が editor surface 内に収まる
- [ ] window resize 後も右端見切れが再発しない
- [ ] 日本語 IME の入力・変換・確定が正常
- [ ] `Cmd+S` で保存できる
- [ ] `Cmd+Enter` で保存して close できる
- [ ] `Cmd+W` で close できる
- [ ] `Cmd+L` / 右クリック menu の checkbox toggle が動く
- [ ] close / reopen 後に draft が復元される

---

## 技術詳細確認

### 実装者が迷わないための決定

- scroller の visual 表示制御は `CheckableTextView.makeNSView` の `NSScrollView` 初期設定に置く
- text layout 幅の制御は `CheckableTextView` 内の helper に寄せる
- text layout width の source of truth は `NSScrollView.contentView.bounds.width`
- 本文幅は `max(0, scrollView.contentView.bounds.width - textView.textContainerInset.width * 2)` で計算する
- `textContainer.lineFragmentPadding = 0` を採用し、左右余白は `textContainerInset` のみで表現する
- `textContainer.widthTracksTextView = false` に固定し、AppKit の自動追従と manual `containerSize` 更新を競合させない
- live resize / window resize は `NSScrollView.contentView` の bounds change notification で拾う
- bounds observer は `Coordinator.observedContentView` / `Coordinator.boundsObserver` で一元管理し、同一 `contentView` への重複登録を禁止する
- `MemoEditorView` の SwiftUI padding は今回変更しない
- `MemoWindowView` の window padding / min size は今回変更しない
- `Coordinator.textDidChange` の保存連携は変更しない
- `CheckboxNSTextView.keyDown` / context menu / checkbox click detection は変更しない

### 想定する helper 分割

`CheckableTextView.swift` 内で以下のように責務を分ける。

- initial setup:
  - rich text 無効化
  - automatic substitution 無効化
  - background / color / undo / resizable 設定
  - scrollView の visual scroller 方針
  - `textContainer.widthTracksTextView = false`
- dynamic update:
  - font size が変わった時のみ font 更新
  - `NSScrollView.contentView.bounds.width` が変わった時のみ textContainer width 更新
  - bounds observer は contentView が差し替わった時のみ再登録
  - binding text が外部変更された時のみ string 更新

### 後続 Phase との衝突確認

- `EditorCommand` / `EditorTextOperations` の command expansion には触れない
- command dispatch の入口である `CheckboxNSTextView.keyDown` は維持する
- text operation 後の `didChangeText` 経路は維持する
- Home / Trash / Session は `draft` を読むだけなので影響なし

---

## セルフチェック結果

### SSOT整合

[x] `docs/roadmap/stickynative-ai-planning-guidelines.md` を確認した  
[x] `docs/product/product-vision.md` を確認した  
[x] `docs/product/ux-principles.md` を確認した  
[x] `docs/product/mvp-scope.md` を確認した  
[x] `docs/architecture/technical-decision.md` を確認した  
[x] `docs/roadmap/roadmap.md` を確認した  
[x] migration SSOT の指定パスが現環境に存在しないことを明記した
[x] migration SSOT 未確認時の Phase 6E-1 Gate を定義した

### 変更範囲

[x] 主目的は editor scroll / layout stability の 1 つ  
[x] 変更ファイルは原則 `CheckableTextView.swift` のみ  
[x] ついで作業を入れていない

### 技術詳細

[x] ファイルごとの責務が明確  
[x] メモリ管理と persistence の境界が明確  
[x] イベント経路と状態遷移が説明できる
[x] resize 時の再計算トリガーと text layout width の source of truth が明確
[x] manual `containerSize` と `widthTracksTextView` の ownership が明確
[x] bounds observer の重複登録防止条件が明確

### Window / Focus

[x] Window lifecycle は変更しない  
[x] Focus 制御の既存経路を維持する  
[x] first mouse の実機確認を Gate に含めた

### Persistence

[x] 保存経路は一本化されたまま  
[x] SQLite schema 変更なし  
[x] relaunch / reopen の保存仕様を変更しない

---

## 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-04-21 | 初版作成。`CheckableTextView` の visual scroller、右端見切れ、折り返し時の layout jitter を Phase 6E として計画化 |
| 2026-04-21 | レビュー指摘対応。`product-vision.md` を SSOT に追加、migration SSOT unavailable の Gate と K-02 を追加、`NSScrollView.contentView.bounds.width` を source of truth に固定、bounds change notification による resize 再計算、本文幅の計算式、Issue → Phase 対応表を明文化 |
| 2026-04-21 | 追加レビュー指摘対応。manual `containerSize` 採用のため `textContainer.widthTracksTextView = false` を明記し、`Coordinator.observedContentView` / `boundsObserver` による bounds observer 重複登録防止を実装条件へ追加 |
