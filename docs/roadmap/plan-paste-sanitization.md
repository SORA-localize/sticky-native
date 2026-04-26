# Paste Sanitization Plan

作成: 2026-04-26  
ステータス: 計画中

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-26 | `plan-paste-sync-language.md` の U-201 を分離。ペースト時の保持属性集合を確定し再計画 |

---

## SSOT参照宣言

本計画は以下を上位文書として扱う。

- `docs/roadmap/stickynative-ai-planning-guidelines.md`
- `docs/product/ux-principles.md`
- `docs/roadmap/plan-rich-text-editor.md`
- `docs/roadmap/plan-rich-text-formatting-remediation.md`

`/Users/hori/Desktop/Sticky/migration/*` は作業環境に存在しない。本計画では repo 内 docs と現行実装を暫定 SSOT とする。これは整合「済み」ではなく「SSOT 未確認 / 保留」であり、migration 文書が復旧した場合は再照合が必要。

### SSOT整合メモ

- `ux-principles.md`: macOS native の自然さを優先する。NotebookLM など外部ソースからのペーストで明朝体・白背景が混入することは「自然さ」に反する。
- `plan-rich-text-editor.md`: `RichTextContentCodec.sanitizedAttributedString` が唯一の属性正規化ロジック。この経路に乗せることで保存時と同じ正規化が保証される。
- `plan-rich-text-formatting-remediation.md`: `typingAttributes` cleanup は toolbar action 後のみ実行する方針。ペースト時は別途 override で処理し、競合しない。

---

## 背景

`CheckboxNSTextView` は `paste(_:)` を override していない。`NSTextView` のデフォルトペーストはクリップボードの RTF/HTML をそのまま挿入するため、外部ソース（NotebookLM 等）からコピーしたテキストの明朝体フォント・白色背景色がメモ内に混入する。

`RichTextContentCodec.normalizedAttributedString(from:baseFont:)` は保存・読み込み時に属性を正規化するロジックとして既に存在しており、ペースト時も同じ経路に乗せることで一貫性を保てる。

---

## 保持する属性集合の確定（仕様）

ペースト時に保持・除去する属性を以下のとおり固定する。

| 属性 | 扱い | 理由 |
|------|------|------|
| `.font` のフォントファミリー | 除去（base font に正規化） | 外部フォント（明朝体等）を混入させない |
| `.font` の bold trait | 保持（base font に適用） | 意図的な強調として有効 |
| `.font` の italic trait | 保持（base font に適用） | 意図的な強調として有効 |
| `.underlineStyle` | 保持 | codec 保存対象の正規属性 |
| `.strikethroughStyle` | 保持 | codec 保存対象の正規属性 |
| `.backgroundColor` | 除去 | メモカラーと干渉する。ペースト元の装飾として不適切 |
| `.foregroundColor` | 除去 | codec が元から保存しない属性 |
| その他すべての属性 | 除去 | codec が元から保存しない属性 |

この仕様は `RichTextContentCodec.sanitizedAttributedString` の既存動作と完全に一致する。新規ロジックは必要ない。

---

## 今回触る関連ファイル

| ファイル | 扱い |
|----------|------|
| `StickyNativeApp/CheckableTextView.swift` | `CheckboxNSTextView.paste(_:)` override を追加 |
| `StickyNativeApp/RichTextContentCodec.swift` | 参照のみ（`normalizedAttributedString` を再利用） |

---

## 問題一覧

| ID | 種別 | 問題 | 影響 | 対応 Phase |
|----|------|------|------|------------|
| U-201 | UI | ペースト時に外部フォント・背景色が混入する | メモの見た目が崩れる | Phase 1 |

---

## 修正フェーズ

### Phase 1: Paste Override（U-201）

**目的:** ペースト時に外部フォント・背景色を除去し、上記仕様の属性集合に正規化する。

**対象ファイル:** `CheckableTextView.swift`

**実装方針:**

`CheckboxNSTextView` に `override func paste(_ sender: Any?)` を追加する。

処理フロー:

1. `NSPasteboard.general` を参照する
2. RTF/HTML が存在する場合: `NSAttributedString(rtf:documentAttributes:)` または `NSAttributedString(html:documentAttributes:)` でデコードし、`RichTextContentCodec.normalizedAttributedString(from:baseFont:)` を通して正規化する
3. プレーンテキストが存在する場合: `NSAttributedString(string:attributes:)` で現在の typing attributes をベースに構築する（外部属性は最初から存在しないため追加処理不要）
4. `insertText(_:replacementRange:)` で挿入する（`shouldChangeText` と undo/redo が正しく動作する経路）

`baseFont` の取得: `typingAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: appSettings.editorFontSize)`

RTF/HTML とプレーンテキストの両方がある場合は RTF/HTML を優先する（ただし正規化を通す）。クリップボードに何もない場合は no-op。

**作業:**

1. `CheckboxNSTextView.paste(_:)` メソッドを追加する
2. RTF → `NSAttributedString` → `normalizedAttributedString` → `insertText` のフローを実装する
3. プレーンテキスト fallback を実装する
4. build が通ることを確認する

**Gate:**

- NotebookLM / Google Docs からコピーしたテキストを貼ると、明朝体・白背景が除去されシステムフォントで表示される
- コピー元で bold だったテキストを貼ると bold が維持される
- 通常のプレーンテキストのペーストが壊れない
- 日本語テキストのペーストが壊れない
- ペースト後に Cmd+Z で undo できる
- 日本語 IME で変換中に paste を呼ばない（`markedRange` が有効な場合は no-op）
- build が通る

---

## Gate条件まとめ

- G-01: 外部フォント（明朝体等）が除去される
- G-02: 背景色が除去される
- G-03: コピー元 bold が維持される
- G-04: 通常ペーストおよび日本語テキストのペーストが壊れない
- G-05: ペースト後の undo が正常に動く
- G-06: IME marked text 中はペーストが no-op になる（または安全に動く）
- G-07: build が通る

---

## 回帰 / 副作用チェック

### Editor

- プレーンテキストのペースト（システムメモ帳等）
- 日本語テキストのペースト
- 外部アプリ（NotebookLM, Google Docs, Safari）からのペースト
- bold / underline が付いたテキストのペースト（保持されること）
- 背景色付きテキストのペースト（除去されること）
- undo / redo
- select all → paste（選択範囲への置換）
- IME 入力中のペースト

### Rich Text 属性

- `RichTextContentCodec.normalizedAttributedString` の既存動作が変わらないこと（保存・読み込み経路への影響なし）
- `typingAttributes` が paste 後に適切に維持されること（bold 入力中にペーストしても bold が継続する）

### Window / Focus

- nonactivating first mouse 後のペーストが正常に動作すること

---

## 実機確認項目

1. NotebookLM の回答テキストをコピーして貼り付け、明朝体・白背景が除去されることを確認する
2. Safari のページテキストをコピーして貼り付け、外部フォントが除去されることを確認する
3. Google Docs で bold にしたテキストをコピーして貼り付け、bold が維持されることを確認する
4. 通常のプレーンテキストをペーストしても崩れないことを確認する
5. 日本語テキストをペーストしても崩れないことを確認する
6. ペースト後に Cmd+Z で undo できることを確認する

---

## 技術詳細確認

### 責務配置

`CheckableTextView.swift`:

- `paste(_:)` override を `CheckboxNSTextView` に追加する
- クリップボード読み取りと正規化呼び出しのみを行う
- text mutation は `insertText(_:replacementRange:)` に委譲し、AppKit の user action model に乗せる

`RichTextContentCodec.swift`:

- 変更なし。`normalizedAttributedString(from:baseFont:)` を paste override から呼び出す

### メモリで持つ情報

- paste 処理は stateless。クリップボードから読んで正規化して挿入して終わり。新規状態は持たない

### イベント経路

1. ユーザーが Cmd+V
2. `CheckboxNSTextView.paste(_:)` (override)
3. `NSPasteboard.general` から RTF または string を取得
4. RTF の場合: `NSAttributedString(rtf:...)` → `RichTextContentCodec.normalizedAttributedString`
5. `insertText(_:replacementRange:)` で挿入
6. `NSTextView.didChangeText` → `Coordinator.textDidChange` → autosave

### AppKit / SwiftUI 責務境界

- paste override は `CheckboxNSTextView`（AppKit）に閉じており、SwiftUI 側は変更しない
- `insertText` は AppKit の user action model に乗るため、undo/redo は自動で正しく動く

### close / reopen / pin / drag の状態遷移

本計画はこれらの状態遷移を変更しない。

### Persistence との衝突

- paste → insertText → autosave の経路は既存通り。保存スキーマ変更なし。

---

## MECE 検査

### Issue → Phase 対応

- U-201: Phase 1

### SSOT整合

- `ux-principles.md`: 自然さの維持 → ペースト汚染の除去は直接対応する
- `plan-rich-text-editor.md`: codec 正規化を唯一の経路とする方針 → paste でも codec を使う
- `plan-rich-text-formatting-remediation.md`: typing attributes cleanup は toolbar action 後のみ → paste は別経路で処理し競合しない

### DRY / KISS

- 新規ロジックなし。既存 `RichTextContentCodec.normalizedAttributedString` を再利用する
- プレーンテキスト fallback は typing attributes の自然な継続であり、追加処理不要

---

## セルフチェック結果

### SSOT整合

[BLOCKER: missing] migration README — 復旧時に再照合が必要  
[BLOCKER: missing] 01_product_decision — 同上  
[BLOCKER: missing] 02_ux_principles — 同上  
[BLOCKER: missing] 06_roadmap — 同上  
[BLOCKER: missing] 07_project_bootstrap — 同上  
[BLOCKER: missing] 09_seamless_ux_spec — 同上  
[x] repo-local docs を確認した  
[x] AppKit NSTextView paste / insertText を確認した  

### 変更範囲

[x] 主目的は1つ（ペースト sanitization のみ）  
[n/a: 高リスク疎通確認テーマなし]  
[x] ついで作業を入れていない  

### 技術詳細

[x] 保持する属性集合が確定している  
[x] baseFont の取得元が定義されている  
[x] イベント経路が明記されている  
[x] codec との役割分担が明確（codec は変更しない）  

### Window / Focus

[n/a: window / focus 責務を変更しない]  

### Persistence

[x] paste → insertText → autosave の既存経路を維持する  
[x] スキーマ変更なし  

### 実機確認

[x] 実機確認項目が列挙されている  
