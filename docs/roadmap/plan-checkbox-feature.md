# チェックボックス機能 実装計画

作成: 2026-04-16  
ステータス: 検討中（審査通過後に着手予定）

---

## SSOT参照宣言

本計画の策定・実装・レビュー時は以下を上位文書として扱う。

- `docs/product/ux-principles.md`
- `docs/product/mvp-scope.md`
- `docs/architecture/technical-decision.md`
- `docs/roadmap/roadmap.md`

---

## 概要

メモエディタで選択した行を ☐ / ☑ のチェックボックス形式にトグルできる機能。  
付箋として「今日のやること」リストを管理する用途を主要ユースケースとして想定。

**本計画の主目的は2つに分かれる（フェーズ分割推奨）：**

1. **Phase 4a**: `TextEditor` → `NSTextView` ラッパーへの基盤切り替え（高リスク）  
2. **Phase 4b**: チェックボックス機能の実装（基盤切り替え完了後）

ガイドライン §9「1フェーズの主目的は1つ」に従い、基盤切り替えと機能実装は別フェーズとする。

---

## ユーザー体験イメージ

```
今日のやること 4/16

☐ SNS DM送信　５件
☐ フェスチケット買う
☑ パスキューブ確認   ← クリックまたはショートカットでトグル
☐ 休学申請の内容作る
```

1. 行を選択して `⌘L`（仮）→ 選択行の先頭に `☐ ` が付く
2. すでに `☐` / `☑` がある行で `⌘L` → 逆トグル（付ける/外す）
3. `☐` / `☑` の文字をクリック → その行をトグル

---

## 問題一覧

| ID | 分類 | 内容 |
|---|---|---|
| A-01 | Architecture | `TextEditor`（SwiftUI）は選択範囲 API がなく、チェックボックス操作が不可能 |
| A-02 | Architecture | チェックボックスのクリック検出実装手段が未確定（`mouseDown` オーバーライド vs Accessibility API） |
| F-01 | Focus | `NSTextView` への切り替えで `acceptsFirstMouse` / ゼロクリック入力への影響が未検証 |
| F-02 | Focus | `NSTextView` ラッパーで SwiftUI の `@FocusState` との整合が未確認 |
| K-01 | Knowledge | `⌘L` が日本語 IME ショートカットと競合する可能性がある |
| P-01 | Persistence | `NSTextView` 切り替え後に reopen 時の draft 復元経路が変わらないことが未確認 |
| U-01 | UI | `NSTextView` 切り替え後のフォント・パディング・スクロール挙動の差異 |

---

## 今回触る関連ファイル

| ファイル | 変更内容 |
|---|---|
| `MemoEditorView.swift` | `TextEditor` を `CheckableTextView`（NSViewRepresentable）に置き換え |
| `CheckableTextView.swift` | **新規作成** — NSTextView ラッパー本体 |
| `MemoWindowController.swift` | `⌘L` キーショートカット登録 |
| `SQLiteStore.swift` | 変更なし |
| `PersistenceModels.swift` | 変更なし |

---

## 技術方針

### Phase 4a: NSTextView ラッパーの作成

**AppKit / SwiftUI 責務境界:**

- `CheckableTextView`（NSViewRepresentable）: NSTextView の生成・設定・text binding の双方向接続
- `Coordinator`: `NSTextViewDelegate` を実装し、テキスト変更を SwiftUI の `@Binding<String>` に反映
- `MemoEditorView`: View 側の責務。`CheckableTextView` をホストするだけ
- `MemoWindowController`: キーイベントの受け取りと `toggleCheckbox` の呼び出し

**メモリ管理と Persistence:**

- `draft` は既存の `@State` / `@Binding` 経路を維持。`CheckableTextView` はそれを橋渡しするだけ
- NSTextView 内部の `NSTextStorage` は UI 層のみで扱い、永続化は既存 SQLite 経路を使う
- reopen 時の draft 復元は `MemoEditorView` 側の `@Binding<String>` に値を渡す既存経路を変えない。`CheckableTextView` は初期化時に `text` binding の値を NSTextView に設定するだけで、復元ロジックは持たない（P-01 対処）

**イベント経路:**

```
キー入力 / クリック
  → NSTextView (AppKit)
  → Coordinator.textDidChange
  → @Binding<String> に反映
  → SQLiteStore に保存（既存経路）
```

**高リスク疎通確認事項（Phase 4a Gate）:**

- [ ] `CheckableTextView` 差し替え後、メモのゼロクリック入力（first mouse）が壊れていないか
- [ ] `@FocusState` や focus 呼び出しが期待どおり動作するか
- [ ] フォント・パディング・スクロールが既存 TextEditor と同等か
- [ ] IME（日本語）入力で文字化け・確定タイミングのズレがないか

### Phase 4b: チェックボックス変換ロジック

**保存形式:**

`draft` カラムにプレーンテキストとして格納する。  
`☐` / `☑` は Unicode 文字（U+2610 / U+2611）。スキーマ変更不要。  
既存データへの影響: **なし**

---

## 実装ステップ

### Step 1（Phase 4a）: NSTextView ラッパーの作成

```swift
// CheckableTextView.swift（NSViewRepresentable）
// - NSTextView を生成・設定
// - Coordinator で text binding を接続
// - selectedRange を外部から操作できる口を用意
```

既存 `MemoEditorView` の `TextEditor` を `CheckableTextView` に置き換える。  
この時点でユーザー体験は変わらない。

**Gate条件（Phase 4a → 4b）:**

- 既存の全操作（入力 / 保存 / reopen / first mouse）が正常に動作すること
- 実機で IME 入力に問題がないこと

---

### Step 2（Phase 4b）: チェックボックス変換ロジック

```swift
// 選択範囲の行を抽出 → toggleCheckbox(lines:) で ☐/☑ を付け外し
func toggleCheckbox(in textView: NSTextView) {
    let selectedRange = textView.selectedRange()
    // 選択範囲が空の場合は現在行を対象
    // 各行の先頭を ☐ → ☑ → (なし) → ☐ の順でサイクル
}
```

### Step 3（Phase 4b）: ショートカット登録

`⌘L` を MemoWindowController のキーハンドラに追加し、
フォーカス中のエディタに対して `toggleCheckbox` を呼ぶ。

キー競合が確認された場合は `⌘⇧L` などの代替キーを採用する。

### Step 4（Phase 4b, オプション）: クリックトグル

クリック検出方式を Phase 4b 着手前に確定する（A-02）。

- **mouseDown オーバーライド案**: `characterIndex(for:)` でクリック位置の文字を特定。シンプルだが、テキスト選択操作と干渉しないよう注意が必要
- **Accessibility API 案**: 実装コストが高く、付箋アプリのユースケースでは過剰。基本的には採用しない

→ `mouseDown` オーバーライドを採用し、`☐` / `☑` の文字位置を `characterIndex(for:)` で判定する方針を推奨。

---

## Gate条件（Phase 4b 完了）

- [ ] `⌘L` で選択行のチェックボックスが正しくトグルされる
- [ ] 複数行選択時に各行が個別に処理される
- [ ] `☐` / `☑` のクリックトグルが動作する（Step 4 実装時）
- [ ] IME 使用中に `⌘L` が誤発動しない

---

## 回帰/副作用チェック

| 確認項目 | 理由 |
|---|---|
| first mouse（1 click 入力）が壊れていないか | NSTextView ラッパー化で acceptsFirstMouse 挙動が変わるリスク |
| global shortcut (`⌘⌥Enter`) が正常動作するか | キーハンドラの追加で競合する可能性 |
| reopen 後に draft が正常に復元されるか | text binding 経路の変更の影響確認 |
| `⌘L` が IME ショートカットと競合しないか | K-01 への対処 |

---

## リスクと注意点

| リスク | 内容 | 対策 |
|---|---|---|
| TextEditor → NSTextView 切り替えによる挙動差 | フォント・パディング・スクロール挙動 | Phase 4a 完了後に既存機能を全件確認（Gate条件） |
| 日本語 IME との干渉 | `⌘L` が IME ショートカットと競合する可能性 | 別キー（`⌘⇧L` など）を検討 |
| 選択範囲が複数行にまたがる場合 | 各行を個別に処理する必要がある | 行分割ロジックを丁寧に実装 |
| first mouse / focus 破損 | NSTextView ラッパーで seamless UX が壊れる | Phase 4a の Gate で必ず実機確認 |

---

## 実機確認項目

- [ ] メモを閉じた状態から1クリックで文字入力できる（first mouse）
- [ ] グローバルショートカットでメモを開いた直後にゼロクリックで入力できる
- [ ] 日本語 IME で通常の文字入力・変換が正常に動作する
- [ ] reopen 後に draft の内容が正しく復元される
- [ ] チェックボックス付きテキストが保存・復元される
- [ ] `⌘L` のトグル操作が単一行・複数行選択の両方で正常に動作する

---

## コマンドリストの追加検討

### 現状の課題

現時点ではメモエディタ内の操作（チェックボックストグル以外）はすべてメニューバーやショートカットキー経由。  
操作の種類が増えると、ショートカットキーの衝突・発見可能性の低下が問題になる。

### NSTextView 移行後の実現可能性

NSTextView 基盤への切り替えにより、`/` のような特定文字の入力をトリガーとした  
**インラインコマンドパレット**が実装可能になる。

**想定コマンド例:**

| コマンド | 動作 |
|---|---|
| `/check` | 現在行をチェックボックス形式に変換 |
| `/date` | 現在の日付を挿入（例: `2026-04-16`） |
| `/clear` | チェック済み行の削除 |
| `/color` | メモの色を変更（将来の color picker 連携） |

### 検討事項

- コマンドリストは `NSTextView` の `textDidChange` で `/` 入力を検知し、  
  `NSPanel` や `NSMenu` スタイルのポップアップで候補を表示する構成が適合しやすい
- **seamless UX との整合が必要**: ポップアップ表示中に focus が他 window に奪われない設計にする
- スコープは Phase 4b 以降の独立フェーズとして検討する（Phase 4 に混ぜない）

---

## 文字入力基盤変更（NSTextView）による拡張可能性

`TextEditor`（SwiftUI）から `NSTextView`（AppKit）への移行は、単なる内部実装の変更にとどまらず、  
以下の機能群を実装可能にする**基盤変更**として位置づけられる。

### 即時に使えるようになる API

| 機能 | API | 用途 |
|---|---|---|
| 選択範囲の取得・操作 | `selectedRange()` / `setSelectedRange()` | チェックボックストグル、テキスト置換 |
| キャレット位置の把握 | `selectedRange.location` | 現在行の検出、コマンドパレット起動位置 |
| カスタムキーハンドリング | `keyDown(with:)` のオーバーライド | ショートカットの細粒度制御 |
| クリック位置のテキスト検出 | `characterIndex(for:)` | ☐ / ☑ クリックトグル |
| テキスト変更の細粒度通知 | `NSTextViewDelegate.textDidChange` | リアルタイム `/` コマンド検知 |

### 将来フェーズで解禁される機能

| 機能 | 概要 |
|---|---|
| **インラインコマンドパレット** | `/` 入力でコマンド候補をポップアップ表示 |
| **テキスト装飾（部分スタイル）** | `NSAttributedString` でチェック済み行のテキストをグレーアウトなど |
| **自動補完・サジェスト** | `NSTextView` の補完 API を使ったインライン補完 |
| **テキスト検索・ハイライト** | `NSTextFinder` との統合 |
| **Undo の細粒度制御** | `NSUndoManager` を直接操作し、操作単位でのアンドゥを設計 |
| **コンテキストメニューのカスタマイズ** | 右クリックメニューにメモ固有の操作を追加 |

### 注意点

- `NSAttributedString` による装飾を使う場合は、保存形式をプレーンテキストに保つ設計が重要  
  （装飾は表示層のみで保持し、`draft` カラムには Unicode テキストのみを書く）
- 拡張機能を追加するたびに `CheckableTextView` が肥大化しないよう、  
  責務ごとに extension または delegate クラスに分離する設計を維持する

---

## 対象外（スコープ外）

- Markdown の `- [ ] / - [x]` 形式のサポート（プレーンテキスト運用を維持）
- チェック済み行の自動移動・ソート
- チェックボックスの視覚的な装飾（色変え等）
- コマンドパレット（本計画の対象外、後続フェーズで検討）

---

## 着手判断

App Store 初回審査通過後、Phase 4 として着手する。  
既存データおよびスキーマへの影響がないため、アップデート配信のリスクは低い。

**推奨フェーズ分割:**

- **Phase 4a**: NSTextView ラッパー化（基盤切り替え。Gate通過後に 4b へ）
- **Phase 4b**: チェックボックス機能（ショートカット + クリックトグル）
- **Phase 4c（将来）**: コマンドパレット（`/` コマンド）

---

## 提出前セルフチェック

```md
### SSOT整合
[ ] docs/product/ux-principles.md を確認した
[ ] docs/product/mvp-scope.md を確認した
[ ] docs/architecture/technical-decision.md を確認した
[ ] docs/roadmap/roadmap.md を確認した

### 変更範囲
[ ] Phase 4a の主目的は「NSTextView 切り替え」の1つ
[ ] Phase 4b の主目的は「チェックボックス機能」の1つ
[ ] ついで作業を入れていない

### 技術詳細
[ ] ファイルごとの責務が明確（CheckableTextView / MemoEditorView / MemoWindowController）
[ ] reopen 時の draft 復元経路は変更していないことを確認（P-01）
[ ] クリックトグルの実装方式が確定している（A-02）
[ ] イベント経路（キー入力 → Coordinator → @Binding → SQLite）が説明できる

### Window / Focus
[ ] first mouse の挙動が Phase 4a Gate で確認されている
[ ] @FocusState との整合が確認されている（F-02）
[ ] global shortcut との競合がない

### Persistence
[ ] 保存経路は既存 SQLite 経路を維持している
[ ] CheckableTextView は復元ロジックを持たない
[ ] reopen 後の draft 復元が実機で確認されている

### 実機確認
[ ] global shortcut を確認する
[ ] 1 click 操作（first mouse）を確認する
[ ] ゼロクリック入力を確認する
[ ] 日本語 IME 入力・変換を確認する
[ ] ⌘L トグルを単一行・複数行で確認する
```

---

## 変更履歴

| 日付 | 内容 |
|---|---|
| 2026-04-16 | 初版作成 |
| 2026-04-16 | AI planning guide に基づきレビュー・加筆。SSOT宣言、問題一覧(ID体系)、Gate条件、回帰チェック、実機確認項目を追加。フェーズ分割推奨を明記。コマンドリスト検討・NSTextView基盤変更による拡張可能性を追記 |
| 2026-04-16 | ガイドラインとのギャップ3件を修正。P-01（reopen経路）・A-02（クリック検出方式）を問題一覧に追加、技術方針にP-01対処を補足、Step 4にA-02の方式決定を追記、§12セルフチェックを追加 |
