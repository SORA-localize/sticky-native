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
| `StickyNativeApp/SeamlessWindow.swift` | NSPanel サブクラス | あり（`becomeKey` override 内で activation policy を一時切り替え） |
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

**根本原因（ログ実測で確定）**:

2段構造の問題が確認された。

**第1層: `NSApp.activate` の呼び出し経路の問題**（既に解決済み）

- `windowDidBecomeMain` delegate は NSPanel では発火しない
- `becomeKey()` instance method override が正解。Mission Control 選択でも発火する（ログで確認済み）

**第2層: processmanager による activate 抑制**（現在の問題・有力仮説）

- ログ中に `BringFrontModifier ... dontMakeFrontmost=1` が観測されており、`.accessory` ポリシー中に processmanager がこのフラグを付与していると推定される
- このフラグが原因で `NSApp.activate(ignoringOtherApps: true)` が OS レベルで抑制されている可能性が高い
- `becomeKey()` は発火している・`NSApp.activate` も呼ばれている。しかし効果がない
- `setActivationPolicy(.regular)` で本当に解除されるかは **疎通確認で検証する前提**（現時点では未確認）

**ログで確認した Mission Control 選択時のシーケンス（13:41:32）**:

```
[SeamlessWindow] makeKey
[SeamlessWindow] becomeKey          ← ここで NSApp.activate を呼ぶが dontMakeFrontmost=1 で抑制されている可能性が高い
[MemoWindowController] windowDidBecomeMain
[SeamlessWindow] becomeKey          ← 2回目
[MemoWindowController] windowDidBecomeKey
（250ms 後）
[SeamlessWindow] makeKeyAndOrderFront  ← SwiftUI @FocusState による
[SeamlessWindow] makeKey
```

---

## 過去の失敗試行

### 試行1: `.nonactivatingPanel` 削除

- ウィンドウ自体が消滅する事象が発生。差し戻し済み。
- 詳細: `bug-nonactivating-panel-focus-failed-attempts.md`

### 試行2: `windowDidBecomeMain` delegate 追加

- 発火せず。修正効果なし。差し戻し済み。
- 原因: NSPanel は設計上 "main window" にならないため、`windowDidBecomeMain` は発火しない。`canBecomeMain` を `true` に override しても無効。

### 試行3: `becomeKey()` override + `NSApp.activate(ignoringOtherApps: true)` のみ

- `becomeKey()` の発火は確認（ログで実測済み）
- しかし `dontMakeFrontmost=1` により activate が OS レベルで抑制されている可能性が高い
- W-01 は解決せず。現在の実装状態

---

## 修正方針

### 根拠

ログ実測から、`NSApp.activate` が `.accessory` ポリシー中に抑制されている可能性が高い。`NSApp.activate` を何度呼んでも前面化しない。

回避案: `becomeKey()` の瞬間だけ activation policy を `.regular` に切り替えて activate し、直後に元のポリシーに戻す。

- `.regular` ポリシーへの切り替えで `dontMakeFrontmost` フラグが解除されるという仮説（疎通確認で検証する）
- activate 後すぐに `.accessory` に戻すことで、Dock への表示などの副作用を最小化する
- activation policy の一時切り替えによる activate 回避は一般的な回避案として知られているが、一次ソースは持っていない

### 実装内容

**SeamlessWindow.swift** の `becomeKey()` override を更新する。

`setActivationPolicy` は `Bool` を返す。切り替え失敗時は activate を打たず終了する（切り替え失敗のまま activate しても `.accessory` 抑制が残るため）。

```swift
override func becomeKey() {
  let old = NSApp.activationPolicy()
  guard NSApp.setActivationPolicy(.regular) else {
    NSLog("[SeamlessWindow] setActivationPolicy(.regular) failed — skipping activate")
    super.becomeKey()
    return
  }
  NSApp.activate(ignoringOtherApps: true)
  NSApp.setActivationPolicy(old)
  super.becomeKey()
}
```

---

## 修正フェーズ

### Phase 疎通確認（`becomeKey()` 発火） — **完了**

**結果**:

```
確認日: 2026-04-14
実機確認項目の結果: becomeKey() が Mission Control 選択時に発火することをログで確認
判定: 通過
備考: NSApp.activate は呼ばれているが dontMakeFrontmost=1 により抑制されている可能性が高いと判断
      activate 経路の問題ではなく processmanager フラグの問題という仮説が有力
```

### Phase 疎通確認（activation policy 一時切り替え）— **未着手**

**目的**: `becomeKey()` 内で `.regular` に一時切り替えることで、Mission Control 選択後に前面を維持できるかを実測で確認する。

**変更内容**（疎通確認用・ログは維持）:

```swift
// SeamlessWindow.swift
override func becomeKey() {
  NSLog("[SeamlessWindow] becomeKey")
  let old = NSApp.activationPolicy()
  guard NSApp.setActivationPolicy(.regular) else {
    NSLog("[SeamlessWindow] setActivationPolicy(.regular) failed — skipping activate")
    super.becomeKey()
    return
  }
  NSApp.activate(ignoringOtherApps: true)
  NSApp.setActivationPolicy(old)
  super.becomeKey()
}
```

**疎通確認が通過したら**: 本文書の「疎通確認結果」セクションに結果を追記し、レビュー承認後にログを除去して本実装フェーズへ進む。

**疎通確認が失敗したら**（前面維持できない）: `setActivationPolicy(.regular)` の後に `runLoop` を1サイクル回してから戻す等の遅延パターンを試す。変更先は引き続き `SeamlessWindow.swift` に限定する。

### Phase 実装（疎通確認通過・レビュー承認後）

疎通確認のコードから NSLog を除去し、本実装として確定しコミットする。  
変更行数: 5〜6行・変更ファイル: 1件。

### 疎通確認結果（記入欄）

```
確認日:
実機確認項目の結果:（全項目の ✓/✗）
判定: 通過 / 遅延パターンへ移行 / 差し戻し
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
| `becomeKey()` override（NSWindow instance method） | ウィンドウが key になる瞬間 | 高。Mission Control 含む（ログで実測確認） |
| `windowDidBecomeKey` delegate | key になった後の通知 | 今回は未採用（`becomeKey()` override で同等の効果が得られるため） |
| `windowDidBecomeMain` delegate | main になった後の通知 | 実測で発火しないことを確認済み（試行2） |

### `dontMakeFrontmost=1` とは

ログ中に観測された processmanager のフラグ（`BringFrontModifier ... dontMakeFrontmost=1`）。`.accessory` ポリシーのプロセスに付与され、`NSApp.activate` による前面化を抑制すると推定される。`.regular` ポリシーへの切り替えで解除されるという仮説を疎通確認で検証する。

### activation policy の一時切り替えの副作用

- `.regular` への切り替え中は Dock にアイコンが瞬間表示される可能性がある（数フレーム）
- activate 直後に `.accessory` に戻すことで副作用を最小化
- 受け入れ可能な副作用かを疎通確認で実測する

### `showAndFocusEditor()` との二重呼び出し

`showAndFocusEditor()` は既に `NSApp.activate(ignoringOtherApps: true)` を呼ぶ。`becomeKey()` override と二重になるケース（メニューバーからメモを開く等）では同じ activate + policy switch が2回呼ばれるが、連続呼び出しは無害。

### `becomesKeyOnlyIfNeeded = true` との関係

- 通常クリック（背景）: key にならないケースがある → `becomeKey()` 発火しない（想定通り）
- TextEditor クリック: key になる → `becomeKey()` 発火 → policy switch + activate（副作用として TextEditor フォーカス時も activate する）
- Mission Control 選択: key になる（ログで確認済み）→ `becomeKey()` 発火 → policy switch + activate

TextEditor フォーカス時に activate が走ることは、メモが前面にある状態での通常操作なので影響なし。

### `restorePersistedOpenMemos` への影響

起動時に複数ウィンドウを連続 show する際、各ウィンドウが `becomeKey` を経由する可能性がある。policy switch の連続呼び出しは無害だが、window ordering の競合が起きないかを確認する。

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
| TextEditor フォーカス | クリックで即時入力できるか（policy switch による不要な activate がないか） |
| global shortcut | ショートカット後にゼロクリック入力できるか |
| pin ON 回帰 | 他アプリ使用中もメモが前面に留まるか |
| close / reopen 回帰 | × / ゴミ箱 / Reopen の各フローが正常か |
| 複数ウィンドウ restore 回帰 | 再起動後の複数メモ一括復元が正常か |
| drag 回帰 | ヘッダ帯・背景マテリアルのドラッグが正常か |
| Dock アイコン副作用 | policy 切り替え中に Dock への瞬間表示がないか（あっても許容か） |

---

## 実機確認項目

1. **W-01 修正確認**: 3本指 Mission Control でメモを選択後、前面を維持するか
2. **直接クリック確認**: 別アプリ操作後にメモをクリックして前面に出るか
3. **TextEditor 確認**: メモ非アクティブ状態からクリックして即時入力できるか
4. **global shortcut 確認**: ショートカット後にゼロクリック入力できるか
5. **pin ON 確認（回帰）**: pin ON で他アプリ使用中もメモが前面に留まるか
6. **close / reopen 確認（回帰）**: × / ゴミ箱 / Reopen の各フローが正常か
7. **複数ウィンドウ restore 確認（回帰）**: 再起動後に複数メモが正常に復元されるか
8. **Dock 副作用確認**: policy 切り替え中に Dock アイコンが点滅しないか

---

## セルフチェック結果

### SSOT整合
- [x] ux-principles を確認した
- [x] technical-decision を確認した
- [x] planning-guidelines を確認した

### 変更範囲
- [x] 主目的は1つ（W-01 の修正）
- [x] 高リスク疎通確認テーマは1つ（activation policy 一時切り替えの有効性確認）
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
- [x] Dock 副作用確認を含めた

---

## 変更履歴

- 2026-04-14: 新規作成。過去2回の失敗試行を踏まえ、`becomeKey()` override アプローチで再構成
- 2026-04-14: レビュー指摘3点を修正。windowDidBecomeKey の棄却理由を「未採用」に修正。fallback の変更先を SeamlessWindow に限定と明記。becomesKeyOnlyIfNeeded の断定表現を緩和
- 2026-04-14: ログ実測結果を反映。`becomeKey()` 疎通確認フェーズを完了マーク。根本原因を processmanager `dontMakeFrontmost=1` による activate 抑制（有力仮説）に更新。次フェーズを activation policy 一時切り替えプローブに更新
- 2026-04-14: レビュー指摘1点を修正。`dontMakeFrontmost=1` の断定表現を「可能性が高い」に統一
