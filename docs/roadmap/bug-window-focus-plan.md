# Bug計画書: Mission Control 選択後にメモウィンドウが背面に戻る

作成: 2026-04-14

---

## SSOT 参照宣言

上位 SSOT（判断根拠）:

- `/Users/hori/Desktop/Sticky/migration/02_ux_principles.md`（seamless UX の要件定義）
- `/Users/hori/Desktop/Sticky/migration/09_seamless_ux_spec.md`（acceptsFirstMouse / focus / activation の仕様）

ローカル補助 SSOT:

- `docs/product/ux-principles.md`
- `docs/architecture/technical-decision.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`

過去の失敗記録:

- `docs/roadmap/bug-nonactivating-panel-focus-failed-attempts.md`

実装参照ファイル:

- `StickyNativeApp/AppDelegate.swift`（activation policy）
- `StickyNativeApp/SeamlessWindow.swift`（NSPanel サブクラス・becomeKey の hook 対象）
- `StickyNativeApp/SeamlessHostingView.swift`（acceptsFirstMouse / NSHostingView レベル）
- `StickyNativeApp/MemoWindowView.swift`（WindowDragHandleView の acceptsFirstMouse）
- `StickyNativeApp/MemoWindowController.swift`（window lifecycle・showAndFocusEditor）

---

## 今回触る関連ファイル

| ファイル | 役割 | 変更予定 |
|---|---|---|
| `StickyNativeApp/SeamlessWindow.swift` | NSPanel サブクラス | あり（`becomeKey` override 追加） |
| `StickyNativeApp/MemoWindowController.swift` | window lifecycle | なし（参照のみ） |
| `StickyNativeApp/AppDelegate.swift` | activation policy | なし（参照のみ） |

---

## 問題一覧

### W-01: Mission Control 選択後にメモウィンドウが背面に戻る

**再現条件**:

- pin が OFF の状態
- 3本指ジェスチャー（Mission Control / Exposé）でウィンドウ一覧を表示
- メモウィンドウを選択する

**症状**: メモが一瞬前面に出るが、直後に別アプリのウィンドウが最前面に戻る。メモが他ウィンドウの裏に隠れていなくても発生する。

**根本原因**:

`.accessory` ポリシー・`.nonactivatingPanel`・`showAndFocusEditor()` 内の明示 activate の3つが噛み合っていない。

- `NSApp.setActivationPolicy(.accessory)`: OS による自動アクティベートが起きにくい
- `.nonactivatingPanel`: ウィンドウへのクリックや OS レベルの前面化でもアプリをアクティベートしない
- `showAndFocusEditor()`: アプリ内操作時のみ `NSApp.activate(ignoringOtherApps: true)` を明示呼び出し

Mission Control がウィンドウを選択したとき、`NSApp.activate` は呼ばれない。別アプリが「自分がアクティブ」のままウィンドウを前に戻す。

---

## 過去の失敗試行

### 試行1: `.nonactivatingPanel` 削除

- ウィンドウ自体が消滅する事象が発生。差し戻し済み。
- 詳細: `bug-nonactivating-panel-focus-failed-attempts.md`

### 試行2: `windowDidBecomeMain` delegate 追加

- 発火せず。修正効果なし。差し戻し済み。
- 原因: NSPanel は設計上 "main window" にならないため、`windowDidBecomeMain` は発火しない。`canBecomeMain` を `true` に override しても無効。

---

## 修正方針

### 根拠

Alfred・Raycast・Multi 等の主要メニューバー常駐アプリが採用している確立されたパターンを採用する。

正しい hook は **`becomeKey()` インスタンスメソッド override**（delegate の `windowDidBecomeKey` ではない）。

- `becomeKey()` は NSWindow のインスタンスメソッドであり、Mission Control による選択でも発火する
- `windowDidBecomeMain` / `windowDidBecomeKey`（delegate）との違い: delegate は NSPanel では期待通りに発火しないケースがある
- `becomesKeyOnlyIfNeeded = true` が設定されていても、Mission Control による明示選択は「key が必要な操作」として扱われるため発火する想定（実測で確認）

### 実装内容

**SeamlessWindow.swift** に `becomeKey()` override を追加する。

```swift
final class SeamlessWindow: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  override func becomeKey() {
    NSApp.activate(ignoringOtherApps: true)
    super.becomeKey()
  }
}
```

`orderFront` / `orderFrontRegardless` の override は**今回は入れない**。Mission Control は内部で WindowServer の private API を使う可能性があり、`orderFront` override だけでは bypass されるケースがある。`becomeKey()` が発火することを先に確認する。

---

## 修正フェーズ

### Phase 疎通確認

**目的**: `becomeKey()` が Mission Control 選択時に発火し、W-01 が解決することを実測で確認する。

**変更内容**（仮・疎通確認用）:

```swift
// SeamlessWindow.swift
override func becomeKey() {
  NSApp.activate(ignoringOtherApps: true)
  super.becomeKey()
}
```

**疎通確認が通過したら**: 本文書の「疎通確認結果」セクションに結果を追記し、レビュー承認後に本実装フェーズへ進む。

**疎通確認が失敗したら**（`becomeKey()` が発火しない）: `orderFront` + `orderFrontRegardless` override を `SeamlessWindow.swift` に追加して再確認する。変更先は引き続き `SeamlessWindow.swift` に限定する。

### Phase 実装（疎通確認通過・レビュー承認後）

疎通確認のコードを本実装として確定しコミットする。  
変更行数: 3〜4行・変更ファイル: 1件。

### 疎通確認結果（記入欄）

```
確認日:
実機確認項目の結果:（全項目の ✓/✗）
判定: 通過 / orderFront 追加へ移行 / 差し戻し
備考:
```

---

## Gate 条件

| フェーズ | 通過条件 |
|---|---|
| 疎通確認着手 | W-01 の再現を実機で確認済みであること |
| 疎通確認通過 | 実機確認項目（下記）がすべて ✓ であること |
| 実装確定 | 疎通確認通過 + レビュー承認 |

---

## 技術詳細確認

### `becomeKey()` と delegate `windowDidBecomeKey` の違い

| | 発火タイミング | NSPanel での信頼性 |
|---|---|---|
| `becomeKey()` override（NSWindow instance method） | ウィンドウが key になる瞬間 | 高。Mission Control 含む |
| `windowDidBecomeKey` delegate | key になった後の通知 | 今回は未採用（`becomeKey()` override で同等の効果が得られるため） |
| `windowDidBecomeMain` delegate | main になった後の通知 | 実測で発火しないことを確認済み（試行2） |

### `showAndFocusEditor()` との二重呼び出し

`showAndFocusEditor()` は既に `NSApp.activate(ignoringOtherApps: true)` を呼ぶ。`becomeKey()` override と二重になるケース（メニューバーからメモを開く等）では同じ activate が2回呼ばれるが、`NSApp.activate` の連続呼び出しは無害。

### `becomesKeyOnlyIfNeeded = true` との関係

- 通常クリック（背景）: key にならないケースがある → `becomeKey()` 発火しない（想定通り）
- TextEditor クリック: key になる → `becomeKey()` 発火 → activate（副作用として TextEditor フォーカス時も activate する）
- Mission Control 選択: key になる（想定）→ `becomeKey()` 発火 → activate

TextEditor フォーカス時に activate が走ることは、メモが前面にある状態での通常操作なので影響なし。

### `restorePersistedOpenMemos` への影響

起動時に複数ウィンドウを連続 show する際、各ウィンドウが `becomeKey` を経由する可能性がある。`NSApp.activate` の連続呼び出しは無害だが、window ordering の競合が起きないかを確認する。

### pin / close / reopen の状態遷移への影響

- **pin ON**: `window.level = .floating` で独立管理。本修正に依存しない
- **close**: `windowWillClose` 経由。本修正に依存しない
- **reopen**: `showAndFocusEditor()` 経由。上記の通り、二重 activate は無害
- **drag**: `isMovableByWindowBackground` と WindowDragHandle の組み合わせ。本修正に依存しない

---

## 回帰・副作用チェック

| 項目 | 確認内容 |
|---|---|
| W-01 修正確認 | Mission Control でメモ選択後、前面を維持するか |
| 直接クリック | 別ウィンドウ操作後にメモをクリックして前面に出るか |
| TextEditor フォーカス | クリックで即時入力できるか（`becomeKey` による不要な activate がないか） |
| global shortcut | ショートカット後にゼロクリック入力できるか |
| pin ON 回帰 | 他アプリ使用中もメモが前面に留まるか |
| close / reopen 回帰 | × / ゴミ箱 / Reopen の各フローが正常か |
| 複数ウィンドウ restore 回帰 | 再起動後の複数メモ一括復元が正常か |
| drag 回帰 | ヘッダ帯・背景マテリアルのドラッグが正常か |

---

## 実機確認項目

1. **W-01 修正確認**: 3本指 Mission Control でメモを選択後、前面を維持するか
2. **直接クリック確認**: 別アプリ操作後にメモをクリックして前面に出るか
3. **TextEditor 確認**: メモ非アクティブ状態からクリックして即時入力できるか
4. **global shortcut 確認**: ショートカット後にゼロクリック入力できるか
5. **pin ON 確認（回帰）**: pin ON で他アプリ使用中もメモが前面に留まるか
6. **close / reopen 確認（回帰）**: × / ゴミ箱 / Reopen の各フローが正常か
7. **複数ウィンドウ restore 確認（回帰）**: 再起動後に複数メモが正常に復元されるか

---

## セルフチェック結果

### SSOT整合
- [x] ux-principles を確認した
- [x] technical-decision を確認した
- [x] planning-guidelines を確認した

### 変更範囲
- [x] 主目的は1つ（W-01 の修正）
- [x] 高リスク疎通確認テーマは1つ（`becomeKey()` の発火確認）
- [x] ついで作業を入れていない

### 技術詳細
- [x] ファイルごとの責務が明確（SeamlessWindow のみ変更）
- [x] イベント経路と状態遷移が説明できる
- [x] 過去失敗試行との差異が明確

### Window / Focus
- [x] `becomeKey()` と delegate の違いを明文化
- [x] `becomesKeyOnlyIfNeeded` との関係を整理
- [x] `showAndFocusEditor()` との二重呼び出しを確認

### Persistence
- [x] 本修正は persistence 経路に影響しない
- [x] `restorePersistedOpenMemos` への副作用を確認項目に含めた

### 実機確認
- [x] global shortcut を含めた
- [x] 1 click 操作を含めた
- [x] ゼロクリック入力を含めた

---

## 変更履歴

- 2026-04-14: 新規作成。過去2回の失敗試行を踏まえ、`becomeKey()` override アプローチで再構成
- 2026-04-14: レビュー指摘3点を修正。windowDidBecomeKey の棄却理由を「未採用」に修正。fallback の変更先を SeamlessWindow に限定と明記。becomesKeyOnlyIfNeeded の断定表現を緩和
