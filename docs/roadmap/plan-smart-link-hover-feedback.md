# Smart Link Hover Feedback Plan

作成: 2026-04-22  
ステータス: 計画中（実装未着手）  

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-22 | 初版作成。吹き出しなしの link hover feedback を Smart Links の独立 polish として計画化 |

---

## SSOT参照宣言

本計画は以下を上位文書として扱う。

### StickyNative ローカル補助文書

- `docs/roadmap/stickynative-ai-planning-guidelines.md`
- `docs/product/product-vision.md`
- `docs/product/ux-principles.md`
- `docs/product/mvp-scope.md`
- `docs/architecture/technical-decision.md`
- `docs/architecture/persistence-boundary.md`
- `docs/roadmap/roadmap.md`
- `docs/roadmap/plan-smart-links.md`
- `docs/product/current-feature-summary.md`

### migration 上位文書の確認結果

`docs/roadmap/stickynative-ai-planning-guidelines.md` では `/Users/hori/Desktop/Sticky/migration/*` を SSOT として参照するよう定義されているが、2026-04-22 時点の作業環境では `/Users/hori/Desktop/Sticky/migration` が存在しない。

したがって、本計画では repo 内の `docs/product/*`、`docs/architecture/*`、`docs/roadmap/*` と現行実装を暫定 SSOT とする。migration 文書が復旧した場合は、実装前または次回計画更新時に再照合する。

### SSOT整合メモ

- `ux-principles.md`: 「速い」「自然」「軽い」を優先する。hover feedback は URL が操作可能であることを軽く示すだけに留め、吹き出しや preview は採用しない。
- `technical-decision.md`: editor surface は SwiftUI、実際の text editing は AppKit `NSTextView`。hover 判定と temporary attributes は AppKit 側に置く。
- `persistence-boundary.md`: draft は plain text として保存する。hover state、色、下線、カーソル状態は永続化しない。
- `plan-smart-links.md`: URL 検出、temporary link styling、`Command-click` / context menu を前提にする。本計画は Smart Links の opening policy を変更しない。

---

## 背景

Smart Links v1 では URL を自動検出し、リンクらしい見た目と明示的な開く操作を提供する。次の polish として、リンク上にマウスが乗った時だけ視覚的な反応を出す。

ただし、メモ editor では入力と選択が主操作であり、hover UI が本文編集を邪魔してはいけない。よって本計画では以下を採用する。

- 吹き出しヒントは出さない
- preview card は出さない
- 通常クリックで URL を開く挙動は追加しない
- hover 中だけ pointer cursor と軽い visual feedback を出す

---

## 今回触る関連ファイル

| ファイル | 扱い |
|----------|------|
| `StickyNativeApp/CheckableTextView.swift` | 主対象。tracking area、hovered link range、cursor、temporary attributes の更新を実装 |
| `StickyNativeApp/EditorCommand.swift` | 変更しない。hover feedback は editor command ではない |
| `StickyNativeApp/EditorTextOperations.swift` | 変更しない。文字列変換ではない |
| `StickyNativeApp/MemoEditorView.swift` | 確認のみ。focus visual に副作用がないことを確認 |
| `StickyNativeApp/PersistenceCoordinator.swift` | 変更しない。保存経路確認のみ |
| `StickyNativeApp/SQLiteStore.swift` | 変更しない。schema 変更なし |
| `docs/roadmap/plan-smart-link-hover-feedback.md` | 本計画書 |

---

## 対象外

- 吹き出しによる `⌘クリックで開く` ヒント
- URL preview card
- URL title fetch / favicon fetch
- 通常クリックで URL を開く挙動
- Markdown link 変換
- rich text 保存
- DB schema 変更
- autosave 戦略変更
- window lifecycle / global shortcut / folder / trash の仕様変更

---

## 問題一覧

| ID | 分類 | 内容 |
|----|------|------|
| U-40 | UI | URL がリンクとして表示されても、hover 時の反応がなく操作可能性が弱い |
| U-41 | UI | 吹き出しや preview を出すと、軽いメモ editor では本文編集の邪魔になる |
| A-40 | Architecture | hover state は保存せず、`NSTextView` 内の transient state と temporary attributes に閉じる必要がある |
| A-41 | Architecture | mouse tracking と text layout 更新が競合すると、hover range が古い文字位置を指すリスクがある |
| A-42 | Architecture | cursor を戻す時に本文上の通常状態である I-beam と text container 外の AppKit 標準状態を区別する必要がある |
| F-40 | Focus | hover 実装が first mouse / cursor placement / selection / IME 入力を邪魔してはいけない |
| P-40 | Persistence | hover styling を `draft` や rich text attributes として保存してはいけない |
| K-40 | Knowledge | Smart Links の開く操作と hover feedback の境界を文書化する必要がある |

---

## Issue -> Phase 対応

| Issue | Phase | 対応内容 |
|-------|-------|----------|
| K-40 | Phase 0 | 吹き出しなし、通常クリック open なし、temporary UI の範囲を計画に固定 |
| A-40 | Phase 1 | `CheckboxNSTextView` に transient hover state を追加する |
| A-41 | Phase 1 / Phase 2 | tracking area と URL range lookup を existing layout 経路に寄せ、text change / scroll / resize / text container width 変更後に hover state を clear または再評価する |
| A-42 | Phase 2 | URL 上、URL 外の本文上、text container 外の cursor policy を固定する |
| U-40 | Phase 2 | hover 中の cursor と temporary attributes を追加する |
| U-41 | Phase 2 | hover feedback を本文上の軽い装飾に限定する |
| F-40 | Phase 3 | first mouse、selection、IME、Command-click を実機確認する |
| P-40 | Phase 3 | 保存内容が plain text のままか確認する |

---

## 技術方針

### 現行実装の事実

- `CheckableTextView` は `NSViewRepresentable` で、内部に `NSScrollView` と `CheckboxNSTextView` を持つ。
- `CheckboxNSTextView` は `NSTextView` subclass。
- `SmartLinkDetector` は `NSDataDetector` で URL range を検出している。
- `CheckboxNSTextView` は `detectedLinks: [SmartLinkRange]` を持つ。
- URL styling は `layoutManager` temporary attributes で underline / link color を付けている。
- `mouseDown` は checkbox toggle、Smart Link open、通常 text editing の順に処理している。
- context menu は URL 上で `リンクを開く` / `リンクをコピー` を出す。

### 責務境界

`CheckableTextView.swift`:

- tracking area の作成・更新
- mouse moved / exited から character index を解決
- hovered URL range の transient state 更新
- cursor を URL 上の `NSCursor.pointingHand`、URL 外の本文上の `NSCursor.iBeam`、text container 外の AppKit 標準状態へ切り替え
- hovered link 用 temporary attributes の追加・削除
- text change / layout update 後の hover state 再評価

`EditorCommand.swift`:

- 変更しない。
- hover feedback は command ではなく pointer interaction なので command metadata に入れない。

`EditorTextOperations.swift`:

- 変更しない。
- hover feedback は文字列変換ではない。

Persistence:

- 変更しない。
- hover state、hover styling、cursor state は保存しない。

### メモリで持つ情報

`CheckboxNSTextView` に transient state として以下を持たせる。

- `hoveredLinkRange: NSRange?`
- `hoveredLinkURL: URL?`
- `linkTrackingArea: NSTrackingArea?`
- `lastMouseLocationInWindow: NSPoint?`

これらは reopen / relaunch 後に復元しない。reopen 後は Smart Links の URL scan 後、次の mouse movement で hover state を再構築する。

### Tracking area 方針

`CheckboxNSTextView.updateTrackingAreas()` を override し、text view bounds 全体へ tracking area を張る。

想定 options:

- `.mouseMoved`
- `.mouseEnteredAndExited`
- `.activeInKeyWindow`
- `.inVisibleRect`

理由:

- memo window が key window の時だけ hover feedback を出せば十分。
- `.inVisibleRect` により scroll / resize 後も visible range に追従しやすい。
- global monitor は使わない。

### Hover lookup

mouse location から character index を求める処理は、既存 `characterIndex(for:)` と同じ layout manager / text container / textContainerOrigin 経路を使う。

既存 helper が `NSEvent` 依存なら、Phase 1 で以下のように分離する。

- `characterIndex(for event: NSEvent) -> Int?`
- `characterIndex(at pointInWindow: NSPoint) -> Int?`

mouse moved、mouse down、context menu が同じ lookup 経路を使うようにする。

### Layout change policy

scroll、resize、text container width 変更、text change により、最後の mouse 位置が指す character index は変わり得る。`.inVisibleRect` は tracking area の追従には有効だが、hover range と cursor の再評価を自動では保証しない。

実装方針:

1. `mouseMoved(with:)` で `lastMouseLocationInWindow` を更新する
2. `textDidChange` / Smart Links refresh 後に `lastMouseLocationInWindow` があれば hover state を再評価する
3. `NSView.boundsDidChangeNotification` による scroll / visible rect 変更後は hover state を再評価する
4. `applyTextContainerWidth` で container width が変わった後は hover state を再評価する
5. 再評価に必要な layout 情報が不安定な場合は、hover state と cursor を clear する

推奨 helper:

- `refreshHoverState(at pointInWindow: NSPoint?)`
- `clearHoverState()`

`refreshHoverState(at:)` は URL 上なら hovered range / URL / cursor / temporary attributes を更新し、URL 外の本文上なら hover range を clear して I-beam に戻す。text container 外、window がない、layout manager がない場合は hover range を clear し、cursor は AppKit 標準に委ねる。

### Hover styling

base link styling:

- `.underlineStyle: NSUnderlineStyle.single.rawValue`
- `.foregroundColor: NSColor.linkColor`

hover styling 候補:

- `.underlineStyle: NSUnderlineStyle.thick.rawValue`
- `.foregroundColor: NSColor.controlAccentColor`
- `.backgroundColor: NSColor.controlAccentColor.withAlphaComponent(0.10)`

初期実装では「文字色 + 下線」だけを推奨する。背景色は選択範囲や IME marked text と競合しやすいため、Phase 2 の実機確認で必要と判断した場合だけ追加する。

temporary attributes の source of truth:

- `detectedLinks`
- `hoveredLinkRange`

temporary attribute key ownership:

- 初期実装で Smart Links が所有して cleanup する key は `.underlineStyle` と `.foregroundColor` のみ。
- hover background を採用する場合は `.backgroundColor` も Smart Links ownership に追加し、full text range cleanup の対象に必ず含める。
- Markdown-lite など他 feature が同じ key を使う場合は、計画側で refresh order と ownership を再定義してから実装する。

更新方針:

1. full text range から Smart Links ownership の temporary attributes を削除
2. `detectedLinks` へ base link styling を再適用
3. `hoveredLinkRange` が有効なら、その range へ hover styling を上書き

### Cursor policy

- URL 上に hover している間だけ `NSCursor.pointingHand.set()` を使う。
- URL 外でも本文 text container 上なら `NSCursor.iBeam.set()` を使う。
- text container 外へ出たら hover state を clear し、cursor は AppKit 標準の更新に委ねる。安易に arrow/default 固定にしない。
- cursor rect を大量に登録するより、mouse moved に合わせて軽く切り替える実装を優先する。
- text selection drag 中は cursor 変更を抑制する。

### Event priority

hover feedback は既存 event priority を変えない。

`mouseDown`:

1. checkbox toggle
2. `Command-click` URL open
3. 通常 text editing

`otherMouseDown`:

1. middle click URL open
2. 通常 other mouse handling

`mouseMoved`:

1. URL 上なら hover state 更新
2. URL 外なら hover state clear
3. text content は変更しない

### IME / marked text

- `hasMarkedText()` が true の間は hover styling 再適用を避ける。
- marked text 中も cursor 変更だけなら許容できるが、初期実装では hover state update を conservative に止めてもよい。
- `keyDown` / editor command の marked text guard は変更しない。

### AppKit / SwiftUI 境界

SwiftUI 側には hover state を渡さない。

理由:

- hover は editor 内部の ephemeral UI。
- SwiftUI state に載せると mouse move ごとに view update が走り、入力の軽さを損ねる。
- `NSTextView` と layout manager の temporary attributes だけで完結できる。

---

## 修正フェーズ

### Phase 0: Scope Fix

目的:

- hover feedback の範囲を固定し、Smart Links の開く操作と混ぜない。

対象ファイル:

- `docs/roadmap/plan-smart-link-hover-feedback.md`

実装内容:

- 吹き出しなし
- preview なし
- 通常クリック open なし
- temporary UI のみ

Gate:

- 本計画に対象外が明記されている
- `plan-smart-links.md` の opening policy と矛盾していない

### Phase 1: Tracking And Hover State

目的:

- URL 上の hover を検出できるようにする。

対象ファイル:

- `StickyNativeApp/CheckableTextView.swift`

実装内容:

- `updateTrackingAreas()` を override
- `mouseMoved(with:)` / `mouseExited(with:)` を実装
- `hoveredLinkRange` / `hoveredLinkURL` を追加
- `characterIndex(at:)` helper を追加し、event / point lookup を共通化
- `lastMouseLocationInWindow` を保持する
- text change 後に最後の mouse location から hover state を再評価する。再評価できない場合は clear する
- scroll / resize / text container width 変更後に hover state を再評価する。再評価できない場合は clear する
- hover range が範囲外なら clear する

Gate:

- URL 上へ mouse を動かすと hover state が入る
- URL 外へ移動すると hover state が消える
- text change 後に stale range が残らない
- URL 上に mouse を置いたまま scroll / resize しても hover 表示と cursor がずれない
- text container width 変更後に hover 表示と cursor がずれない
- build が通る

### Phase 2: Visual Feedback

目的:

- URL hover 中だけ軽い visual feedback を出す。

対象ファイル:

- `StickyNativeApp/CheckableTextView.swift`

実装内容:

- base link attributes と hover link attributes を分ける
- initial ownership key は `.underlineStyle` と `.foregroundColor` のみに固定する
- hover background を採用する場合は `.backgroundColor` を cleanup 対象へ追加する
- Smart Links refresh 時に base styling -> hover styling の順で temporary attributes を再適用
- URL 上で `NSCursor.pointingHand` を表示
- URL 外の本文上で `NSCursor.iBeam` を表示
- text container 外では cursor を arrow/default 固定せず AppKit 標準に委ねる

Gate:

- hover 中の URL だけ見た目が変わる
- hover 外の URL は base link styling のまま
- Smart Links が所有する temporary attribute key が cleanup 対象に含まれている
- URL 外の本文上では I-beam cursor になる
- text container 外で cursor が不自然に arrow/default 固定されない
- text selection の見た目が壊れない
- IME marked text 中に変換中文字が消えない

### Phase 3: Regression Gate

目的:

- editor の主操作を壊していないことを確認する。

対象ファイル:

- コード変更なし
- 必要なら本計画書へ実機確認結果を追記

Gate:

- 通常クリックで URL 上に caret を置ける
- `Command-click` で URL が開く
- middle click 実装がある場合、middle click で URL が開く
- right click URL menu が出る
- URL 上に mouse を置いたまま scroll / resize しても hover 表示と cursor がずれない
- URL 外の text selection / drag selection が壊れていない
- checkbox click toggle が壊れていない
- global shortcut 後のゼロクリック入力が壊れていない
- 非アクティブ window への 1 click 入力が壊れていない
- 日本語 IME の入力・変換・確定が正常
- 保存される draft は URL 文字列のみで、hover 属性を含まない

---

## Gate条件

- `xcodebuild -project StickyNative.xcodeproj -scheme StickyNative -configuration Debug build` が成功する
- `git diff --check` が成功する
- URL hover 中のみ cursor が hand になる
- URL 外の本文上では cursor が I-beam になる
- text container 外の cursor は AppKit 標準に委ねられている
- URL hover 中のみ visual feedback が変わる
- scroll / resize / text container width 変更後に hover 表示と cursor が stale にならない
- 吹き出し・preview・tooltip が出ない
- 通常クリックで URL が開かない
- `Command-click` / context menu の既存 Smart Links 操作が維持される
- DB schema と persistence code に変更がない
- IME marked text 中に temporary attributes 更新で入力が消えない

---

## 回帰/副作用チェック

| 確認項目 | 理由 |
|----------|------|
| first mouse | tracking area / cursor 更新が非アクティブ window からの 1 click 入力を邪魔しないことを確認 |
| global shortcut 後の入力 | focus token / first responder に副作用がないことを確認 |
| 日本語 IME | marked text 中の temporary attributes 更新が変換を壊さないことを確認 |
| selection / drag selection | hover cursor と text selection 操作が競合しないことを確認 |
| scroll / resize | mouse 位置が指す文字の変化に hover range と cursor が追従することを確認 |
| checkbox toggle | `mouseDown` priority が変わっていないことを確認 |
| context menu | URL 上の menu と editor command menu が維持されることを確認 |
| autosave | hover state が `memo.draft` に混ざらないことを確認 |

---

## 実機確認項目

- [ ] URL 上に hover すると pointer cursor になる
- [ ] URL 外の本文上に出ると I-beam cursor になる
- [ ] text container 外では cursor が不自然に arrow/default 固定されない
- [ ] URL 上に hover すると下線または色が軽く変わる
- [ ] URL 外に出ると base link styling に戻る
- [ ] URL 上に mouse を置いたまま scroll しても hover 表示と cursor がずれない
- [ ] URL 上に mouse を置いたまま window resize しても hover 表示と cursor がずれない
- [ ] font size / text container width 変更後に hover 表示と cursor がずれない
- [ ] 吹き出し、preview、tooltip が出ない
- [ ] 通常クリックでは URL を開かず、caret placement / selection ができる
- [ ] `Command-click` で URL を開ける
- [ ] middle click 実装がある場合、middle click で URL を開ける
- [ ] URL 上の right click menu から `リンクを開く` / `リンクをコピー` が使える
- [ ] checkbox の click toggle が正常
- [ ] 日本語 IME の入力・変換・確定が正常
- [ ] close / reopen 後も URL が再検出される
- [ ] relaunch 後も URL が再検出される

---

## 技術詳細確認

- hover state は `CheckboxNSTextView` 内だけで持つ。
- SwiftUI state / persistence / SQLite には hover state を渡さない。
- link detection は既存 `SmartLinkDetector` を使い、独自 regex は追加しない。
- temporary attributes は full text range から削除して再適用する。
- initial Smart Links temporary attribute ownership は `.underlineStyle` と `.foregroundColor` のみ。
- hover background を採用する場合は `.backgroundColor` も cleanup 対象に追加する。
- hover range は text change / scroll / resize / text container width 変更後に最後の mouse location から再評価し、再評価できない場合または範囲外なら clear する。
- cursor policy は URL 上が pointing hand、URL 外の本文上が I-beam、text container 外は AppKit 標準に委ねる。
- marked text 中は hover styling refresh を避ける。
- opening policy は `Command-click` / context menu / middle click 実装がある場合の middle click に限定し、通常クリック open は入れない。

---

## セルフチェック結果

### SSOT整合

[x] migration README は現環境に存在しないため unavailable として扱った
[x] repo 内 product / architecture / roadmap 文書を確認した
[x] `plan-smart-links.md` と矛盾しない scope にした

### 変更範囲

[x] 主目的は link hover feedback のみ
[x] 高リスク疎通確認テーマは editor hover / temporary attributes のみ
[x] 吹き出し、preview、通常クリック open を入れていない

### 技術詳細

[x] ファイルごとの責務が明確
[x] メモリ管理と persistence の境界が明確
[x] イベント経路と状態遷移が説明できる

### Window / Focus

[x] Window 責務を変更しない
[x] Focus 制御を変更しない
[x] first mouse の確認項目を明記した

### Persistence

[x] 保存経路は変更しない
[x] hover state を保存しない
[x] relaunch 時は URL 再検出とした

### 実機確認

[x] global shortcut を確認する
[x] 1 click 操作を確認する
[x] ゼロクリック入力を確認する
