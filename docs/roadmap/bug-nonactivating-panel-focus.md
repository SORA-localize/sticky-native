# Bug計画書: Pin OFF 時のウィンドウフォーカス問題

作成: 2026-04-13  
最終更新: 2026-04-13（原因分析を全面改訂）

---

## SSOT 参照宣言

上位 SSOT（判断根拠）:

- `/Users/hori/Desktop/Sticky/migration/02_ux_principles.md`（seamless UX の要件定義）
- `/Users/hori/Desktop/Sticky/migration/09_seamless_ux_spec.md`（acceptsFirstMouse / focus / activation の仕様）

ローカル補助 SSOT:

- `docs/product/ux-principles.md`
- `docs/architecture/technical-decision.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`

実装参照ファイル:

- `StickyNativeApp/AppDelegate.swift`（activation policy の設定）
- `StickyNativeApp/SeamlessWindow.swift`（NSPanel サブクラス・canBecomeKey）
- `StickyNativeApp/SeamlessHostingView.swift`（acceptsFirstMouse / NSHostingView レベル）
- `StickyNativeApp/MemoWindowView.swift`（WindowDragHandleView の acceptsFirstMouse）
- `StickyNativeApp/MemoWindowController.swift`（window lifecycle・showAndFocusEditor）
- `StickyNativeApp/WindowManager.swift`（showAndFocusEditor 呼び出し経路）

---

## 今回触る関連ファイル

| ファイル | 役割 | 変更予定 |
|---|---|---|
| `StickyNativeApp/MemoWindowController.swift` | window lifecycle・delegate | あり |
| `StickyNativeApp/SeamlessWindow.swift` | NSPanel サブクラス | 要検討 |
| `StickyNativeApp/AppDelegate.swift` | activation policy | なし（参照のみ） |
| `StickyNativeApp/MemoWindowView.swift` | WindowDragHandleView の acceptsFirstMouse | なし（参照のみ） |

---

## 問題一覧

### W-01: Exposé / 重なりクリックでメモが一瞬前に出てすぐ背面に戻る

**再現条件**:
- pin OFF のメモウィンドウが別ウィンドウに少しでも重なっている
- 別ウィンドウを操作した後、3本指 Exposé でメモを選択する（または直接クリック）

**症状**: メモが一瞬前面に出るが、直後に元のウィンドウが最前面に戻る

**根本原因: 3つの設定の activation 経路が噛み合っていない**

```
AppDelegate.swift:13
  NSApp.setActivationPolicy(.accessory)
  → Dock 非表示の常駐アプリ。NSApp.activate 自体は呼べるが、
    OS 経由での自動アクティベートは起きにくい

MemoWindowController.swift styleMask
  .nonactivatingPanel
  → クリックや OS レベルのウィンドウ前面化でもアクティベートしない

MemoWindowController.swift:88-93  showAndFocusEditor()
  NSApp.activate(ignoringOtherApps: true)
  makeKeyAndOrderFront / orderFrontRegardless
  → アプリ内操作のときだけ明示的に activate する経路
```

問題は `.accessory` 単体ではなく、3つの設定の組み合わせにある。`showAndFocusEditor()` はメニューバー・hotkey・Home パネルからの操作でしか呼ばれないため、Exposé 経由でウィンドウが選択されたとき `NSApp.activate` が呼ばれない。`.nonactivatingPanel` によりウィンドウも activation をトリガーしないため、別アプリ（`.regular`）が「自分がアクティブ」のままウィンドウを前に戻す。

**pin ON が問題ない理由**: `window.level = .floating` により window level の高さで常に前面維持。activation とは独立して動作する。

---

## 過去の試行と失敗記録

### 試行1: `.nonactivatingPanel` 削除（疎通確認）—— 失敗

```swift
// 試した変更
styleMask: [.borderless, .resizable, .fullSizeContentView]  // .nonactivatingPanel を削除
// window.becomesKeyOnlyIfNeeded = true も削除
```

**結果**: ウィンドウ自体が消滅する事象が発生。差し戻し済み。  
**教訓**: `.nonactivatingPanel` の削除だけでは解決せず、別の問題を引き起こした。原因の切り分けが不十分だった。

---

## 修正方針（改訂版）

`.nonactivatingPanel` の削除はリスクが高く失敗済みのため、別アプローチを取る。

**方針**: OS がウィンドウを前面に出したとき（Exposé 含む）を検知し、その時点で `NSApp.activate` を呼ぶ経路を追加する。

### 候補A: `NSWindowDelegate.windowDidBecomeMain` で activate

`MemoWindowController`（NSWindowDelegate）に `windowDidBecomeMain` を追加し、ウィンドウがメインになった時点で `NSApp.activate` を呼ぶ。

```swift
func windowDidBecomeMain(_ notification: Notification) {
  NSApp.activate(ignoringOtherApps: true)
}
```

- `.nonactivatingPanel` と `becomesKeyOnlyIfNeeded` は現状維持
- 内部操作（`showAndFocusEditor`）との二重呼び出しは無害

**注意**: 今の仮説は「Exposé / 直接クリック経由では `.nonactivatingPanel` が activation 経路に乗らない」というものなので、その経路では `didBecomeMain` 自体が発火しない可能性が高い。疎通確認として試す価値はあるが、発火しないことが本線シナリオである点を前提として進める。

### 候補B: `SeamlessWindow.orderFront` override

```swift
override func orderFront(_ sender: Any?) {
  NSApp.activate(ignoringOtherApps: true)
  super.orderFront(sender)
}
```

- OS からの `orderFront` 呼び出しにも反応できる可能性がある
- 候補Aより OS レベルの経路に近い
- ただし起動時 restore など全 `orderFront` に適用されるため副作用の確認要

### 推奨

候補Aから疎通確認する（変更量が小さく安全なため）。ただし **発火しない可能性が高い**ことを前提に置き、失敗時は即座に候補Bへ移行する。

---

## 修正フェーズ

### Phase 疎通確認

**目的**: `windowDidBecomeMain` が Exposé 選択時に発火するか確認する。

**変更内容**（仮・疎通確認用）:

```swift
// MemoWindowController.swift に追加
func windowDidBecomeMain(_ notification: Notification) {
  NSApp.activate(ignoringOtherApps: true)
}
```

**疎通確認が通過したら**: 本文書の「疎通確認結果」セクションに結果を追記し、レビュー承認後に本実装フェーズへ進む。  
**疎通確認が失敗したら**（`didBecomeMain` が発火しない）: 候補Bの疎通確認に移行する。

### Phase 実装（疎通確認通過・レビュー承認後）

疎通確認のコードを本実装として確定しコミットする。  
変更行数: 3行以内・変更ファイル: 1件。

### 疎通確認結果（記入欄）

疎通確認完了後にここへ追記する。

```
確認日:
試行した候補: A / B
実機確認項目の結果: （全項目の ✓/✗ を記載）
判定: 通過 / 候補B移行 / 差し戻し
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

### activation 経路の全体像

| 起動経路 | `NSApp.activate` が呼ばれるか |
|---|---|
| メニューバー / hotkey / Home | `showAndFocusEditor()` 経由で呼ばれる ✓ |
| Exposé / Mission Control 選択 | **呼ばれない** ← これが問題 |
| 直接クリック（非アクティブ時） | 呼ばれない（`.nonactivatingPanel` のため） |

### `acceptsFirstMouse` の実装経路（2箇所）

**① SeamlessHostingView.acceptsFirstMouse**（NSHostingView レベル）  
SwiftUI Button 等の一般領域。hitTest で返るのは深いサブビューのため確実な保証はないが、NSPanel の first-click 感度でカバーされる可能性あり。

**② WindowDragHandleView.acceptsFirstMouse**（MemoWindowView.swift）  
ドラッグ専用 NSView。pin/trash/× とは独立した経路。本修正の影響を受けない。

### `showAndFocusEditor()` との二重呼び出し

候補Aを採用した場合、`showAndFocusEditor()` と `windowDidBecomeMain` の両方で `NSApp.activate` が呼ばれるケースがある（例: メニューバーからメモを開く）。`NSApp.activate` の二重呼び出しは無害だが、`makeKeyAndOrderFront` と `orderFrontRegardless` が重複して呼ばれないことを確認する。

### `restorePersistedOpenMemos` への影響

複数ウィンドウを連続で restore する際、各ウィンドウで `windowDidBecomeMain` が発火すると `NSApp.activate` が連続呼び出しされる。無害な想定だが実測要。

### pin / close / reopen の状態遷移への影響

- **pin ON → OFF**: `window.level` 変更のみ。本修正に依存しない
- **close**: `windowWillClose` 経由。本修正に依存しない
- **reopen**: `showAndFocusEditor()` 経由。`windowDidBecomeMain` との二重呼び出し確認要
- **drag**: `isMovableByWindowBackground` と WindowDragHandle の組み合わせ。本修正に依存しない

---

## 回帰・副作用チェック

| 項目 | 確認内容 |
|---|---|
| W-01 修正確認 | Exposé でメモを選択後、前面を維持するか |
| 直接クリック | 別ウィンドウ操作後にメモをクリックして前面に出るか |
| pin ON 回帰 | 他アプリ使用中もメモが前面に留まるか |
| close / reopen | × / ゴミ箱 / Reopen の各フローが正常か |
| drag | ヘッダ帯・背景マテリアルのドラッグが正常か |
| TextEditor focus | クリックでキーウィンドウになり入力できるか |
| global shortcut | ショートカット後にゼロクリック入力できるか |
| 複数ウィンドウ restore | 再起動後の複数メモ一括復元が正常か |

---

## 実機確認項目

疎通確認フェーズで以下をすべて確認する。

1. **W-01 修正確認**: Exposé でメモを選択後、前面を維持するか
2. **直接クリック確認**: 別ウィンドウ操作後にメモをクリックして前面に出るか
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
- [x] 高リスク疎通確認テーマは1つ（`windowDidBecomeMain` の発火確認）
- [x] ついで作業を入れていない

### 技術詳細
- [x] ファイルごとの責務が明確
- [x] イベント経路と状態遷移が説明できる
- [x] acceptsFirstMouse の2経路を記載

### Window / Focus
- [x] Window 責務が MemoWindowController に集約されている
- [x] activation の3方向競合を明文化した
- [x] 過去の失敗試行（`.nonactivatingPanel` 削除）を記録した

### Persistence
- [x] 本修正は persistence 経路に影響しない
- [x] restorePersistedOpenMemos への副作用を確認項目に含めた

### 実機確認
- [x] global shortcut を含めた
- [x] 1 click 操作を含めた
- [x] ゼロクリック入力を含めた

---

## 変更履歴

- 2026-04-13: 初版作成（メモとして）
- 2026-04-13: planning guideline に基づき全セクション追加・再構成
- 2026-04-13: 原因分析を全面改訂。3方向競合を明記。`.nonactivatingPanel` 削除失敗を記録。修正方針を `windowDidBecomeMain` 経由に変更
- 2026-04-13: レビュー指摘3点を修正。.accessory の説明を精度修正。候補Aの発火不確実性を明示。MemoWindowView.swift を関連ファイルに追加
