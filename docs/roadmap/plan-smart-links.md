# Smart Links Plan

作成: 2026-04-22  
ステータス: 計画中（実装未着手）

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-22 | 初版作成。URL 自動検出とリンクを開く操作を Smart Links v1 として計画化 |

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
- `docs/roadmap/plan-editor-scroll-layout-stability.md`
- `docs/product/current-feature-summary.md`

### migration 上位文書の確認結果

`docs/roadmap/stickynative-ai-planning-guidelines.md` では `/Users/hori/Desktop/Sticky/migration/*` を SSOT として参照するよう定義されているが、2026-04-22 時点の作業環境では `/Users/hori/Desktop/Sticky/migration` が存在しない。

したがって、本計画では repo 内の `docs/product/*`、`docs/architecture/*`、`docs/roadmap/*` と現行実装を暫定 SSOT とする。migration 文書が復旧した場合は、実装前または次回計画更新時に再照合する。

### SSOT整合メモ

- `product-vision.md`: `Cmd+Option+Enter -> すぐ書く -> 元作業に戻る -> 1 click で再編集` を主体験とする。Smart Links は URL を貼った後に戻る速度を上げるため、この主体験と整合する。
- `ux-principles.md`: 「速い」「自然」「軽い」を優先する。通常クリックで勝手にブラウザを開くと編集カーソル移動と衝突するため、v1 は `Command-click` と context menu を採用する。
- `technical-decision.md`: editor surface は SwiftUI、実際の text editing は AppKit `NSTextView`。Smart Links の検出・表示・クリック処理は AppKit 側の `CheckableTextView.swift` に置く。
- `persistence-boundary.md`: draft は plain text として保存する。Smart Links v1 では DB schema、保存形式、autosave 経路を変更しない。
- `plan-editor-scroll-layout-stability.md`: `CheckableTextView` は AppKit layout / first mouse / IME / context menu の責務を持つ。Smart Links は同じ editor 内部挙動だが、scroll layout には触れない。

---

## 背景

StickyNative は「Post-it のデジタル版」を目指している。ユーザーが memo に URL を貼る用途は自然であり、URL から作業へ戻る導線は `すぐ書く / すぐ戻れる` 体験に直結する。

一方で、Notion 的な tag / archive / rich database は現時点では過剰であり、整理の負荷を増やす可能性がある。Smart Links v1 は以下に絞る。

- URL を自動検出してリンクとして視認できる
- URL を `Command-click` または context menu からブラウザで開ける
- memo draft の保存形式は plain text のまま維持する

---

## 今回触る関連ファイル

| ファイル | 扱い |
|----------|------|
| `StickyNativeApp/CheckableTextView.swift` | 主対象。URL 検出、temporary link styling、Command-click / context menu のリンク操作を実装 |
| `StickyNativeApp/EditorCommand.swift` | 原則変更しない。必要時のみ context menu の既存 command と衝突しないことを確認 |
| `StickyNativeApp/EditorTextOperations.swift` | 変更しない。Smart Links は text transformation ではなく表示・操作の一時属性として扱う |
| `StickyNativeApp/MemoEditorView.swift` | 確認のみ。editor hosting / focus visual に副作用がないことを確認 |
| `StickyNativeApp/MemoWindowController.swift` | 確認のみ。focus / zero-click input に副作用がないことを確認 |
| `StickyNativeApp/PersistenceCoordinator.swift` | 変更しない。保存経路確認のみ |
| `StickyNativeApp/SQLiteStore.swift` | 変更しない。schema 変更なし |
| `docs/roadmap/plan-smart-links.md` | 本計画書 |

---

## 対象外

- tag / smart folder / archive
- rich text 保存
- Markdown link 変換
- selected text に URL を貼る `Command-K`
- 他 memo への `>>` link
- Web Clipper
- 添付ファイル
- URL preview card
- DB schema 変更
- autosave 戦略変更
- window lifecycle / global shortcut / folder / trash の仕様変更

---

## 問題一覧

| ID | 分類 | 内容 |
|----|------|------|
| U-30 | UI | URL が plain text と同じ見た目で、後からリンクとして認識しづらい |
| U-31 | UI | memo 内の URL からブラウザへ戻る導線がない |
| U-32 | UI | 通常クリックで URL を開くと、編集カーソル移動・選択操作と衝突する |
| A-30 | Architecture | `CheckableTextView` は plain text binding を維持しつつ、表示上だけ temporary link styling を重ねる必要がある |
| A-31 | Architecture | checkbox click、context menu、keyDown、IME、first mouse と link 操作の優先順位が未定義 |
| P-30 | Persistence | link styling を保存形式に混ぜると、既存 `draft TEXT` / autosave / search と衝突する |
| K-30 | Knowledge | Smart Links v1 の範囲と、tag/archive 等を入れない理由を文書化する必要がある |

---

## Issue -> Phase 対応

| Issue | Phase | 対応内容 |
|-------|-------|----------|
| K-30 | Phase 0 | v1 の範囲、tag/archive 対象外、通常クリックを避ける理由を計画に固定 |
| A-30 | Phase 1a / Phase 1b | Phase 1a で URL range cache、Phase 1b で `layoutManager` temporary attributes を実装し plain text 保存を維持する |
| A-31 | Phase 2 / Phase 3 | checkbox / selection / Command-click / context menu の event priority を実装する |
| U-30 | Phase 1a / Phase 1b | Phase 1a で URL 自動検出、Phase 1b で temporary link styling を実装する |
| U-31 | Phase 2 / Phase 3 | Command-click と context menu から URL を開けるようにする |
| U-32 | Phase 2 | 通常クリックは編集操作として維持し、誤爆しない開き方にする |
| P-30 | Phase 1b / Phase 4 | styling は transient とし、build / 実機確認で保存内容が plain text のままか確認 |

---

## 技術詳細確認

### 現行実装の事実

- `MemoEditorView` は `CheckableTextView(text: $memo.draft, ...)` を表示している。
- `CheckableTextView` は `NSViewRepresentable` で、内部に `NSScrollView` と `CheckboxNSTextView` を持つ。
- `CheckboxNSTextView` は `NSTextView` subclass。
- `configureInitialTextView` で `textView.isRichText = false` としている。
- `Coordinator.textDidChange` は `parent.text = textView.string` で plain text を binding に戻している。
- `SQLiteStore` の `memos.draft` は `TEXT NOT NULL`。
- `CheckboxNSTextView.mouseDown` は checkbox 文字 `☐` / `☑` の click toggle を先に処理している。
- context menu は `CheckboxNSTextView.menu(for:)` で独自に構築している。

### 責務境界

`CheckableTextView.swift`:

- `NSDataDetector` による URL range 検出
- `layoutManager` temporary attributes による transient link styling 適用
- `Command-click` 時の URL lookup と `NSWorkspace.shared.open(_:)`
- context menu の `リンクを開く` / `リンクをコピー` 追加
- checkbox click / text editing / IME / focus / layout の既存責務維持

`CheckableTextView.swift` 内部 helper:

- `SmartLinkDetector`: `NSDataDetector` を所有し、plain text から `[SmartLinkRange]` を返す private helper
- `SmartLinkRange`: `NSRange` と `URL` を持つ private value type
- `CheckboxNSTextView`: `detectedLinks: [SmartLinkRange]` を所有し、mouse / menu event から character index を解決して URL 操作を行う
- `Coordinator`: `textDidChange` / `updateNSView` 後に `textView.refreshSmartLinks(using:)` を呼び、scan と temporary styling 再適用を orchestration する

`CheckboxNSTextView` に直接増やす責務は event handling と lookup helper までに限定し、URL detection の詳細は `SmartLinkDetector` へ分離する。

`EditorTextOperations.swift`:

- 文字列変換専用。Smart Links v1 では変更しない。
- URL を Markdown などに変換しない。

`PersistenceCoordinator.swift` / `SQLiteStore.swift`:

- plain text draft の保存のみ。変更しない。

### メモリで持つ情報

新規 persistence は追加しない。

`CheckboxNSTextView` に transient state として以下を持たせる。

- `detectedLinks: [SmartLinkRange]`
- 最後に link scan した文字列または revision 相当の軽量状態
- context menu 表示時に event location から解決した URL

`Coordinator` は `SmartLinkDetector` を所有し、`CheckboxNSTextView` の `detectedLinks` 更新と temporary styling 再適用を呼び出す。`detectedLinks` の owner は `CheckboxNSTextView` に固定する。

これらは reopen / relaunch 後に復元しない。reopen 後は `textView.string` から再検出する。

### 保存形式

保存される正は常に `textView.string` / `memo.draft` の plain text。

以下は保存しない。

- temporary link attributes
- underline / foreground color
- clicked URL state
- detected URL cache

### Link detection

採用候補:

```swift
let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
```

検出対象:

- `http://...`
- `https://...`
- `www.example.com` 形式は v1 の必須 Gate にしない。`NSDataDetector` が URL として返す場合のみ対応し、実機確認で観測結果を記録する。

v1 では独自 regex は使わない。理由:

- URL 仕様を手書き regex で追うと誤検出が増える
- Apple platform 標準の data detector と macOS の自然な挙動に寄せる

### Link styling

`layoutManager` の temporary attributes を使い、本文全体の基本属性や undo stack を壊さずに URL range へ一時装飾を付ける。`NSTextStorage.addAttributes` を Smart Links v1 の主経路として使わない。

想定属性:

- `.underlineStyle: NSUnderlineStyle.single.rawValue`
- `.foregroundColor: NSColor.linkColor`

注意:

- `textView.isRichText = false` は維持する。
- text replacement 時に link styling が失われることは許容し、`textDidChange` / `updateNSView` 後に再適用する。
- selected range は scan / temporary attribute apply 前後で維持する。
- marked text がある IME 変換中は、temporary attribute apply で変換操作を邪魔しない。
- temporary attribute の source of truth は `detectedLinks: [SmartLinkRange]` とする。
- text が変わったら対象範囲の old temporary attributes を削除し、再 scan 後に new temporary attributes を適用する。
- old temporary attributes の削除範囲は常に full text range とする。
- `layoutManager.removeTemporaryAttribute(.underlineStyle, forCharacterRange: fullTextRange)` と `layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: fullTextRange)` を実行してから、現行 `detectedLinks` の範囲に new temporary attributes を追加する。

### Click / selection policy

v1 の開く操作:

- `Command-click` on URL: `NSWorkspace.shared.open(url)`
- context menu on URL: `リンクを開く`
- context menu on URL: `リンクをコピー`

v1 で採用しない操作:

- 通常クリックで即 open
- selection しただけで即 open
- hover preview

理由:

- memo editor では通常クリックは cursor placement / selection の基本操作。
- URL 上の通常クリックで browser を開くと、編集体験を壊す。
- `Command-click` は「編集ではなく開く」という意図が明確。

### Event priority

`CheckboxNSTextView.mouseDown(with:)` の処理順は以下に固定する。

1. checkbox toggle: `☐` / `☑` 上の click は既存通り checkbox 操作を優先する。
2. Command-click URL: event modifier に `.command` があり、クリック位置に URL があれば browser で開いて return。
3. 通常 text editing: 上記以外は `super.mouseDown(with:)` に渡す。

context menu:

1. event location に URL があれば、先頭に `リンクを開く` / `リンクをコピー` を出す。
2. 既存 editor commands を維持する。
3. cut / copy / paste / select all を維持する。

### URL lookup

クリック位置から character index を求める処理は、既存 `toggleCheckboxIfNeeded(for:)` と同じ layout manager / text container / textContainerOrigin 経路を使う。

候補 helper:

```swift
private func characterIndex(for event: NSEvent) -> Int?
private func url(at characterIndex: Int) -> URL?
private func openURLIfNeeded(for event: NSEvent) -> Bool
```

`url(at:)` は `detectedLinks: [SmartLinkRange]` を source of truth として参照する。`NSTextStorage` の `.link` attribute は参照しない。

### AppKit / SwiftUI 境界

AppKit:

- URL detection
- link styling
- mouse / context menu event handling
- browser open

SwiftUI:

- editor の配置と focus visual
- Smart Links の内部状態を持たない

### Persistence / search への影響

- `memo.draft` は URL 文字列を含む plain text のまま。
- Home search は既存通り `draft.localizedCaseInsensitiveContains(query)` で URL 文字列にもヒットする。
- DB migration は不要。
- relaunch 後も draft から再検出するため、link 表示は復元できる。

---

## 修正フェーズ

### Phase 0: 計画固定

主目的: Smart Links v1 の範囲を固定し、tag/archive 等を混ぜない。

作業:

1. 本計画を作成する。
2. `Command-click` / context menu を採用し、通常クリック open を対象外にする理由を明記する。
3. 保存形式を plain text のまま維持する方針を明記する。

Gate:

- [ ] Smart Links v1 が URL 自動検出と link open に絞られている
- [ ] tag / archive / smart folder / rich text が対象外として明記されている
- [ ] 通常クリック open を採用しない理由が明記されている
- [ ] DB schema 変更なしが明記されている

### Phase 1a: URL detection / range cache 最小実装

主目的: `NSTextView` の plain text 保存を維持したまま URL range cache を production slice として実装する。

作業:

1. `CheckableTextView.swift` に private `SmartLinkDetector` と `SmartLinkRange` を追加する。
2. `CheckboxNSTextView` に `detectedLinks: [SmartLinkRange]` を持たせる。
3. `Coordinator` が `textDidChange` と `updateNSView` の text sync 後に URL scan を呼ぶ。
4. `https://` / `http://` の detection 結果を `detectedLinks` に反映する。
5. `www.` 形式は必須 Gate にせず、検出可否だけ記録する。

Gate:

- [ ] build が通る
- [ ] URL lookup の source of truth が `detectedLinks: [SmartLinkRange]` である
- [ ] `https://example.com` が `detectedLinks` に入る
- [ ] `http://example.com` が `detectedLinks` に入る
- [ ] `www.example.com` は必須 Gate にせず、検出可否を観測記録として残す
- [ ] `detectedLinks` の owner が `CheckboxNSTextView` に固定されている
- [ ] URL detection の詳細が `SmartLinkDetector` に分離されている

### Phase 1b: temporary link styling 最小実装

主目的: `detectedLinks` に基づき、undo / selection / IME / plain text 保存を壊さず URL を視覚表示する。

作業:

1. `layoutManager` temporary attributes で underline / link color を付ける。
2. old temporary attributes は full text range から `.underlineStyle` / `.foregroundColor` を削除してから再適用する。
3. selected range を維持する。
4. IME marked text 中は styling 再適用を避ける。
5. `textView.string` が属性なし plain text として維持されることを確認する。

Gate:

- [ ] build が通る
- [ ] `https://example.com` が link color / underline で表示される
- [ ] `http://example.com` が link color / underline で表示される
- [ ] URL 以外の本文 style が壊れない
- [ ] `NSTextStorage.addAttributes` を Smart Links の主経路にしていない
- [ ] old temporary attributes の削除範囲が full text range である
- [ ] 入力中の selected range が不要に動かない
- [ ] 日本語 IME 変換中に入力が崩れない
- [ ] autosave される draft は URL 文字列を含む plain text のまま

### Phase 2: Command-click open

主目的: 編集操作を壊さず、明示操作で URL をブラウザで開けるようにする。

作業:

1. `CheckboxNSTextView.mouseDown(with:)` に Command-click URL 判定を追加する。
2. checkbox click を最優先に維持する。
3. URL 上の通常 click は `super.mouseDown(with:)` に渡し、cursor placement / selection を維持する。
4. `NSWorkspace.shared.open(url)` で default browser を開く。

Gate:

- [ ] build が通る
- [ ] URL 上の `Command-click` で default browser が開く
- [ ] URL 上の通常 click は editor cursor 操作として動く
- [ ] URL text selection ができる
- [ ] checkbox click toggle が既存通り動く
- [ ] first mouse / zero-click input が壊れない

### Phase 3: Link context menu

主目的: URL 上の右クリックから `リンクを開く` / `リンクをコピー` を使えるようにする。

作業:

1. `menu(for:)` で event location に URL があるか判定する。
2. URL がある場合、context menu 先頭に `リンクを開く` と `リンクをコピー` を追加する。
3. 既存 menu の editor commands / cut / copy / paste / select all を維持する。
4. `NSPasteboard.general` に URL absolute string をコピーする。

Gate:

- [ ] build が通る
- [ ] URL 上の右クリック menu に `リンクを開く` が出る
- [ ] URL 上の右クリック menu に `リンクをコピー` が出る
- [ ] URL 以外の右クリック menu は既存項目を維持する
- [ ] `リンクをコピー` で pasteboard に URL が入る
- [ ] checkbox / date / datetime / cut / copy / paste / select all が既存通り動く

### Phase 4: 回帰確認と文書更新

主目的: Smart Links が Post-it の軽さ、editor core、保存経路を壊していないことを確認する。

作業:

1. `xcodebuild -project StickyNative.xcodeproj -scheme StickyNative -configuration Debug build` を実行する。
2. 実機で URL 入力、Command-click、context menu、IME、checkbox、autosave、reopen を確認する。
3. 実装結果が計画から逸脱した場合、本計画へ理由を追記する。
4. 必要なら `docs/product/current-feature-summary.md` に Smart Links を追加する。追加は実装後の判断とする。

Gate:

- [ ] build が通る
- [ ] URL 入力直後に link 表示される
- [ ] close / reopen 後も URL が link 表示される
- [ ] relaunch 後も URL が link 表示される
- [ ] draft 保存内容は plain text のまま
- [ ] global shortcut から新規 memo を開き、ゼロクリック入力できる
- [ ] first mouse で editor 操作できる
- [ ] 既存 shortcuts が壊れていない

---

## 回帰 / 副作用チェック

| 領域 | チェック |
|------|----------|
| editor input | 通常入力、日本語 IME、改行、選択、undo / redo が動く |
| autosave | URL を含む draft が plain text として保存される |
| reopen | close / reopen 後に URL が再検出される |
| relaunch | app relaunch 後に URL が再検出される |
| checkbox | `☐` / `☑` click toggle と `Command-L` が動く |
| date command | `Command-D` / `Command-Shift-D` が動く |
| context menu | 既存 editor menu が URL 有無に関わらず壊れない |
| first mouse | 非アクティブ window への 1 click 操作が維持される |
| focus | global shortcut 後のゼロクリック入力が維持される |
| Home search | URL 文字列が既存検索でヒットする |
| persistence | SQLite schema に変更がない |

---

## 実機確認項目

1. 新規 memo に `https://example.com` を入力し、link 表示される。
2. 新規 memo に `http://example.com` を入力し、link 表示される。
3. 新規 memo に `www.apple.com` を入力し、NSDataDetector が URL として扱うか観測結果を記録する。
4. URL 上の通常 click で cursor placement / selection ができる。
5. URL 上の `Command-click` で default browser が開く。
6. URL 上の右クリックで `リンクを開く` / `リンクをコピー` が出る。
7. URL 以外の右クリック menu が既存通り出る。
8. `☐ task https://example.com` の checkbox click が checkbox toggle として優先される。
9. URL を含む memo を close / reopen して link 表示が復元される。
10. URL を含む memo を relaunch 後に開いて link 表示が復元される。
11. 日本語 IME 変換中に link styling が入力を邪魔しない。
12. `Command-L` / `Command-D` / `Command-Shift-D` が既存通り動く。
13. Home search で URL 文字列がヒットする。

---

## 非採用判断

| 機能 | 今回入れない理由 |
|------|------------------|
| 通常クリックで open | 編集 cursor 移動と衝突し、Post-it の軽い編集体験を壊す |
| selection だけで open | 誤爆しやすく、macOS の自然な text editing と合わない |
| rich text 保存 | plain text draft / search / autosave と衝突する |
| Markdown link 変換 | 入力された URL を勝手に変形し、Post-it 的な即時メモと合わない |
| tag | Folder / search が既にあり、整理軸を増やす段階ではない |
| archive | Trash / Folder と意味が重なり、現時点では分類負荷が増える |
| smart folder | tag / archive がない段階では過剰 |
| URL preview card | 表示が重くなり、付箋の密度と速度を下げる |

---

## セルフチェック結果

### SSOT整合

[x] migration README は参照不能であることを確認した  
[x] 01_product_decision は参照不能であることを確認した  
[x] 02_ux_principles は参照不能であることを確認した  
[x] 06_roadmap は参照不能であることを確認した  
[x] 07_project_bootstrap は参照不能であることを確認した  
[x] 09_seamless_ux_spec は参照不能であることを確認した  
[x] repo 内の product / architecture / roadmap 文書を暫定 SSOT として確認した  

### 変更範囲

[x] 主目的は URL Smart Links v1 のみ  
[x] 高リスク疎通確認テーマは `NSTextView` temporary styling + click handling のみ  
[x] tag / archive / smart folder 等のついで作業を入れていない  

### 技術詳細

[x] ファイルごとの責務が明確  
[x] メモリ管理と persistence の境界が明確  
[x] イベント経路と状態遷移が説明できる  

### Window / Focus

[x] Window 責務に触れない  
[x] Focus 制御を変更しない  
[x] first mouse の既存挙動を回帰確認項目に入れている  

### Persistence

[x] 保存経路は既存 `memo.draft -> AutosaveScheduler -> SQLite` のまま  
[x] frame と open 状態には触れない  
[x] relaunch 時は plain text draft から URL を再検出する  

### 実機確認

[x] global shortcut 後のゼロクリック入力を確認対象に含めた  
[x] 1 click 操作を確認対象に含めた  
[x] URL 操作、checkbox、IME、context menu を確認対象に含めた  
