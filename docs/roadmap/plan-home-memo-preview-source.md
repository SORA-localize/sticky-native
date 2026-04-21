# Home Memo Preview Source Plan

作成: 2026-04-21  
ステータス: 計画中（実装未着手）

---

## SSOT参照宣言

本計画は以下を上位文書として扱う。

- `docs/product/product-vision.md`
- `docs/product/ux-principles.md`
- `docs/product/mvp-scope.md`
- `docs/architecture/technical-decision.md`
- `docs/roadmap/roadmap.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`

### migration 上位文書の確認結果

`docs/roadmap/stickynative-ai-planning-guidelines.md` では `/Users/hori/Desktop/Sticky/migration/*` を SSOT として参照するよう定義されているが、2026-04-21 時点の作業環境では `/Users/hori/Desktop/Sticky` が存在しない。

本計画は Home memo row の表示 source のみを変更する。window lifecycle、persistence schema、draft 保存形式、search 条件には触れないため、ローカル補助文書と現行実装を根拠に進める。

---

## 背景

管理画面の memo history row は、title に `memo.title` を表示し、その下の薄文字 subtitle に `memo.draft` をそのまま表示している。

`memo.title` は draft の先頭 content line から自動生成されるため、subtitle も同じ1行目を表示してしまい、title と subtitle が重複する。

memo history では title で1行目の要旨を示し、subtitle では2行目以降の続きを見せる方が情報量が高い。

---

## 今回触る関連ファイル

既存:

- `StickyNativeApp/HomeView.swift`
  - `MemoRowView` の subtitle source を変更する
- `StickyNativeApp/MemoTitleFormatter.swift`
  - 必要なら preview helper を追加する

触らない:

- `SQLiteStore.swift`
- `PersistenceCoordinator.swift`
- `PersistenceModels.swift`
- `WindowManager.swift`
- `MemoWindow.swift`
- window / resize / focus 関連

スキーマ変更:

- なし

---

## 問題一覧

| ID | 分類 | 内容 |
|---|---|---|
| U-01 | UI | Home memo history row の subtitle が `memo.draft` 全体を source にしており、title と同じ1行目を重複表示する |
| U-02 | UI | 1行だけの memo でも subtitle が title と同じ内容になり、row の情報密度が下がる |
| A-01 | Architecture | title source と preview source の判断が `HomeView` 内の ad hoc 処理になると、将来の list 表示で分岐しやすい |
| P-01 | Persistence | preview 表示のために DB column や保存済み title/draft を変更してはいけない |

---

## 技術詳細確認

### 現状

`HomeView.MemoRowView`:

```swift
Text(memo.title.isEmpty ? "Untitled" : memo.title)

if !memo.draft.isEmpty {
  Text(memo.draft)
    .font(.system(size: 11))
    .foregroundStyle(.secondary)
    .lineLimit(1)
}
```

`MemoTitleFormatter.generatedTitle(from:)`:

- draft の最初の non-empty line を title source にする
- 20文字を超える場合は `...` で省略する

### 目標

- title は現状どおり `memo.title` を表示する
- subtitle は title source の次の non-empty line を表示する
- 2行目以降に表示可能な content がない場合は subtitle を表示しない
- subtitle の style は現状維持
  - `font(.system(size: 11))`
  - `.foregroundStyle(.secondary)`
  - `.lineLimit(1)`
- subtitle に明示的な文字数制限は追加しない
  - 現状も文字数制限はなく、SwiftUI の `.lineLimit(1)` による表示上の truncation のみ

### 採用方針

`MemoTitleFormatter` に preview helper を追加する。

候補:

```swift
static func previewText(from draft: String) -> String
```

仕様:

- draft を newline で分割する
- trimming 後に空でない行だけを content line として扱う
- 先頭 content line は title source とみなす
- 2つ目以降の content line のうち最初の行を preview source として返す
- preview source がない場合は `""` を返す
- preview には title 用の `titleLimit = 20` を適用しない

`HomeView.MemoRowView` はこの helper の返り値を subtitle に使う。

### イベント経路

```text
HomeView row render
  -> PersistedMemo.draft
  -> MemoTitleFormatter.previewText(from:)
  -> subtitle Text
```

保存経路:

```text
変更なし
memo.draft -> AutosaveScheduler -> PersistenceCoordinator -> SQLite
```

検索経路:

```text
変更なし
filteredMemos uses memo.title / memo.draft
```

---

## 修正フェーズ

### Phase H-1: Preview Source Helper

目的:

- title source と preview source の判断を `MemoTitleFormatter` に集約する。

対象ファイル:

- `StickyNativeApp/MemoTitleFormatter.swift`

実装内容:

- `previewText(from:)` を追加する
- 先頭 content line を skip し、2つ目以降の non-empty content line を返す
- 該当行がなければ `""`
- title 文字数制限は preview に適用しない

Gate:

- 空 draft は `""`
- 1行 memo は `""`
- 2行 memo は2行目を返す
- 1行目が空で2行目が title source の場合、3行目以降を preview に使う
- preview helper が persistence に依存しない

### Phase H-2: Home Row Subtitle Update

目的:

- memo history row の subtitle を draft 直表示から preview helper へ差し替える。

対象ファイル:

- `StickyNativeApp/HomeView.swift`

実装内容:

- `MemoRowView` で `let preview = MemoTitleFormatter.previewText(from: memo.draft)` 相当を使う
- `preview.isEmpty` の場合は subtitle `Text` を表示しない
- subtitle style は現状維持

Gate:

- Home の 1行 memo は subtitle が出ない
- Home の 2行以上 memo は2行目以降が subtitle に出る
- Trash view の row でも同じ表示が破綻しない
- title 表示は変わらない
- Home search は既存どおり title / draft 対象のまま

---

## Issue → Phase 対応

| Issue | 対応 Phase | 解決 / 確認内容 |
|---|---|---|
| U-01 | Phase H-1, H-2 | preview helper で title source を skip し、Home row subtitle に使う |
| U-02 | Phase H-2 | preview が空なら subtitle を非表示にする |
| A-01 | Phase H-1 | line source 判定を `MemoTitleFormatter` へ集約する |
| P-01 | Phase H-1, H-2 | source-only 表示変更に留め、schema / saved title / saved draft は変更しない |

---

## Gate条件

- 変更の主目的は Home memo history subtitle source の修正 1 つ
- DB schema を変更しない
- saved draft / saved title を変更しない
- search / session / trash のデータ条件を変更しない
- subtitle の visual style を変更しない
- window resize / focus / editor command と同じ commit に混ぜない

---

## 回帰 / 副作用チェック

| 確認項目 | 懸念 | 対策 |
|---|---|---|
| one-line memo | subtitle が title と同じ内容で残る | preview が空なら subtitle を表示しない |
| whitespace lines | 空行を2行目扱いして subtitle が空白になる | trimming 後 non-empty line のみ対象にする |
| title limit | preview に title の20文字制限を誤適用する | preview は `.lineLimit(1)` の表示 truncation のみ |
| search | preview helper 導入で検索対象が変わる | `filteredMemos` は触らない |
| persistence | preview を保存し始めて schema が増える | `MemoTitleFormatter` + `HomeView` の表示処理だけに限定する |

---

## 実機確認項目

- [ ] 空 memo は subtitle が出ない
- [ ] 1行 memo は subtitle が出ない
- [ ] 2行 memo は2行目が subtitle に出る
- [ ] 1行目が空で2行目が title の場合、3行目以降が subtitle に出る
- [ ] subtitle は薄文字、1行制限のまま
- [ ] title は現状と同じ
- [ ] Home search は1行目 / 2行目以降どちらでも既存どおりヒットする
- [ ] Trash view の row 表示も破綻しない

---

## セルフチェック結果

### SSOT整合

[x] `docs/roadmap/stickynative-ai-planning-guidelines.md` を確認した  
[x] `docs/product/product-vision.md` を確認した  
[x] `docs/product/ux-principles.md` を確認した  
[x] `docs/product/mvp-scope.md` を確認した  
[x] `docs/architecture/technical-decision.md` を確認した  
[x] migration SSOT の指定パスが現環境に存在しないことを明記した

### 変更範囲

[x] 主目的は Home memo history subtitle source 修正の 1 つ  
[x] window / resize / focus をスコープ外にした  
[x] persistence schema をスコープ外にした

### 技術詳細

[x] source helper の責務が明確  
[x] Home row の表示責務が明確  
[x] preview の文字数制限方針が明確

### Persistence

[x] 保存経路は変更しない  
[x] SQLite schema 変更なし  
[x] saved title / draft を変更しない

---

## 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-04-21 | 初版作成。Home memo history subtitle が title と同じ draft 1行目を重複表示しないよう、2行目以降の non-empty line を source にする source-only 計画を定義 |
