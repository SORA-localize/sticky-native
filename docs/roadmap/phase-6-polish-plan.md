# Phase 6 Polish Plan

最終更新: 2026-04-13

## SSOT 参照宣言

migration 上位文書（planning guideline §2 必須参照セット）:
- `/Users/hori/Desktop/Sticky/migration/README.md`
- `/Users/hori/Desktop/Sticky/migration/01_product_decision.md`
- `/Users/hori/Desktop/Sticky/migration/02_ux_principles.md`
- `/Users/hori/Desktop/Sticky/migration/03_domain_and_data.md`
- `/Users/hori/Desktop/Sticky/migration/04_technical_decision.md`
- `/Users/hori/Desktop/Sticky/migration/06_roadmap.md`
- `/Users/hori/Desktop/Sticky/migration/07_project_bootstrap.md`
- `/Users/hori/Desktop/Sticky/migration/08_human_checklist.md`
- `/Users/hori/Desktop/Sticky/migration/09_seamless_ux_spec.md`

StickyNative ローカル補助文書:
- `docs/product/product-vision.md`
- `docs/product/ux-principles.md`
- `docs/product/mvp-scope.md`
- `docs/architecture/domain-model.md`
- `docs/roadmap/roadmap.md`
- `docs/roadmap/development-roadmap-revalidated.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`

## 今回触る関連ファイル

既存:
- `StickyNativeApp/MemoWindow.swift`
- `StickyNativeApp/MemoWindowView.swift`
- `StickyNativeApp/MemoWindowController.swift`
- `StickyNativeApp/MemoEditorView.swift`
- `StickyNativeApp/WindowManager.swift`
- `StickyNativeApp/MenuBarController.swift`
- `StickyNativeApp/AppDelegate.swift`
- `docs/architecture/domain-model.md`（Phase 6-4 の import 判断結果を反映）
- `docs/roadmap/roadmap.md`（Phase 6-4 の import 判断結果を反映）

新規（Phase 6-3 で追加）:
- `StickyNativeApp/SettingsWindowController.swift`
- `StickyNativeApp/SettingsView.swift`
- `StickyNativeApp/AppSettings.swift`

## 問題一覧

- `U-06`: `Cmd+S`（明示フラッシュ）・`Cmd+Enter`（保存して close）が未実装（`ux-principles.md` に記載あり）
- `U-07`: `MemoWindow.title` が常に `"Quick Memo"` で固定されており、draft の内容が window ヘッダーに反映されない
- `W-02`: window がスクリーン外に配置された場合（外部ディスプレイ切断等）に回復手段がない
- `U-08`: Settings パネルがなく、フォントサイズ等の基本設定を変更できない
- `K-04`: 旧 Sticky データの import 要否が未判断（`01_product_decision.md §7` 保留）

## 目的

- `ux-principles.md` に記載された keyboard shortcut を実装して仕様を完結させる
- memo window のタイトル表示を draft 連動に直す
- 日常使用で発生する edge case を塞ぐ
- 最低限の Settings を設ける
- import 要否を判断して保留を解消する

## スコープ In

- `Cmd+S`: autosave をその場でフラッシュする（U-06）
- `Cmd+Enter`: フラッシュして window close（U-06）
- memo window ヘッダーのタイトルを draft 先頭行に連動させる（U-07）
- off-screen window を開いたとき画面内に補正する（W-02）
- Settings パネル: フォントサイズ（小/中/大）の設定（U-08）
- import 要否の判断（K-04）（実装は判断次第）
- `MenuBarController` に Settings 項目を追加

## スコープ Out

- shortcut キーの変更（HotkeyManager 改修は大きいため Phase 7 以降）
- window テーマ・カラーカスタマイズ
- cloud sync / export
- iOS / iPadOS 対応

## 技術詳細確認

### U-06: Cmd+S / Cmd+Enter の実装方針

SwiftUI の `TextEditor` はキーボード入力をすべてキャプチャするが、`Cmd+` 系は `.keyboardShortcut` modifier を Button に付けることで割り込める。

実装:
- `MemoWindowView` に不可視 Button を 2 つ追加し、`.keyboardShortcut` を付与する
  - `Cmd+S` → `onSave` コールバックを呼ぶ
  - `Cmd+Enter` → `onSaveAndClose` コールバックを呼ぶ
- `MemoWindowController` に `onSave` / `onSaveAndClose` を追加する
- `.keyboardShortcut(.return, modifiers: .command)` と `.keyboardShortcut("s", modifiers: .command)`

`Cmd+Enter` の二重保存問題:
- `Cmd+Enter` のフローは「flush → performClose」となり、`windowWillClose` でも `onFlush` が呼ばれて二重保存になる可能性がある
- 対策: `MemoWindowController` に `private var didExplicitFlush = false` フラグを持たせる
  - `onSaveAndClose` で flush 後に `didExplicitFlush = true`
  - `windowWillClose` で `!didExplicitFlush` のときのみ `onFlush` を呼ぶ
  - `window?.performClose(nil)` を呼ぶ（delegate 経由の通常の close フロー）
- `Cmd+S` は flush のみでフラグを立てない（その後も autosave debounce は継続する）

補足:
- autosave は引き続き 1.5s debounce で動作する。`Cmd+S` は「今すぐ保存」のユーザー意図に応えるフラッシュであり、autosave の代替ではない

### U-07: ウィンドウヘッダーのタイトル連動

現状:
- `MemoWindow.title` は `"Quick Memo"` を返す computed property で固定
- `MemoWindowView` の header で `memo.title` を表示している

修正:
- `MemoWindow.title` を `PersistenceCoordinator.generateTitle(from: draft)` と同じロジックで draft から生成する computed property に変更する
- `MemoWindow.draft` は `@Published` なので SwiftUI は自動的に再描画する
- 生成ロジック: 先頭の非空行を最大 30 文字（window ヘッダーは短いため 50 より短く）
- draft が空の場合: `"New Memo"` を返す（Untitled より意図が明確）

補足:
- `PersistenceCoordinator.generateTitle` は DB 保存用（50 文字）であり、別途管理する

### W-02: off-screen 回復

発生条件:
- 保存された `origin_x / origin_y` が、現在接続されているディスプレイの可視領域外を指している

対応:
- `WindowManager` にヘルパー関数 `clampedFrame(_ frame: NSRect) -> NSRect` を追加する
  - `NSScreen.screens` の全画面の union rect を求め、frame の origin を画面内に収まるよう補正する
  - サイズは変更しない。origin の x/y のみ調整する
  - 判定: frame の左上が最近傍スクリーンの visible frame 内に 50px 以上入っていない場合に補正を適用する
  - 補正後の origin は `NSScreen.main?.visibleFrame.origin` を基準に最小マージン 20px を確保する
- `openMemo(id:)` と `restorePersistedOpenMemos()` で controller の window を表示する前に `clampedFrame` を適用する
- `window.center()` は使わない（既存の配置位置を活かす方が自然なため）
- 補正は表示時のみ。DB への origin 書き戻しは行わない（補正後に window を動かしたら次回は正常な位置が保存される）

### U-08: Settings パネル

構成:
- `MenuBarController` に "Settings..." 項目を追加（`Cmd+,` 標準キー）
- `SettingsWindowController`: 通常の NSWindow（300×200 程度）、singleton
- `SettingsView`: SwiftUI、フォントサイズ選択（小=13, 中=16, 大=19）
- `AppSettings`: `UserDefaults` ベースの設定モデル（`@MainActor`, `ObservableObject`）
  - `editorFontSize: Double`（デフォルト 16）
- `MemoEditorView` が `AppSettings` を `@EnvironmentObject` で参照し、`font(.system(size: appSettings.editorFontSize))` を適用する
- `AppDelegate` で `AppSettings` を生成し、`NSHostingView` の environment に inject する

補足（Cmd+, の扱い）:
- `NSApp.setActivationPolicy(.accessory)` の場合、標準の `Cmd+,` global shortcut は first responder chain に依存するため、memo window がフォーカスされていない状態では発火しない
- よって Settings の起動は **メニューバーアイコン → "Settings..." のみ** とする。`Cmd+,` のグローバル登録はしない
- `NSMenuItem` への key equivalent 設定は視覚的ヒントとして `⌘,` を表示するが、実際の発火は status menu を開いてから行う前提とする。これは macOS 標準の「Preferences をどこからでも `Cmd+,` で開ける」挙動の完全実装ではない

### K-04: import 判断

旧 Sticky データ（`~/Library/Application Support/Sticky/sticky.db` 等）の import について:
- 本計画書では「判断」を Phase 6-4 で行い、「実装する場合は Phase 7」とする
- 判断観点:
  - 旧データにアクセスする必要が現在あるか
  - 旧アプリはまだ使用しているか
  - import のコストに見合う価値があるか

### イベント経路

- `Cmd+S`:
  - `MemoWindowView`（不可視ボタン）→ `onSave` → `MemoWindowController.onFlush(id, draft)` → `AutosaveScheduler.flush` → `PersistenceCoordinator.saveDraft`

- `Cmd+Enter`:
  - `MemoWindowView`（不可視ボタン）→ `onSaveAndClose` → `MemoWindowController` で `didExplicitFlush = true` + flush + `window?.performClose(nil)`
  - `windowWillClose`: `didExplicitFlush == true` のとき `onFlush` をスキップ（二重保存防止）

- font size 変更:
  - `SettingsView` → `AppSettings.editorFontSize` 更新 → `MemoEditorView` が `@EnvironmentObject` 経由で再描画

## 修正フェーズ

### Phase 6-1: Keyboard Shortcuts + タイトル連動

目的:
- `Cmd+S` / `Cmd+Enter` を実装し、`ux-principles.md` の仕様を満たす（U-06）
- memo window ヘッダーのタイトルを draft 先頭行に連動させる（U-07）

対象ファイル: `MemoWindow.swift`, `MemoWindowView.swift`, `MemoWindowController.swift`

逸脱理由: U-06（shortcut）と U-07（タイトル連動）はどちらも同一の memo window surface で動作を確認する必要がある。分割すると「shortcut は動くがヘッダーが "Quick Memo" 固定」という不完全な中間状態でのテストを強いられ、確認の意味が薄くなる。変更ファイルも同一 3 ファイルに収まるため逸脱を許容する。

Gate:
- memo を書いた状態で `Cmd+S` を押すと autosave が即時フラッシュされる（1.5s 待たずに DB に反映）
- `Cmd+Enter` で window が閉じ、draft が保存される
- memo window ヘッダーに draft 先頭行（最大 30 文字）が表示される
- draft が空のとき `"New Memo"` と表示される

### Phase 6-2: Off-screen Recovery + Edge Cases

目的:
- off-screen に配置された window を画面内に回復する（W-02）

対象ファイル: `WindowManager.swift`

Gate:
- 外部ディスプレイを切断してからアプリを再起動しても、memo window が画面内に表示される
- 通常の配置（画面内）には影響しない

### Phase 6-3: Settings パネル

目的:
- フォントサイズを変更できる最小 Settings を作る（U-08）

対象ファイル: `AppSettings.swift`（新規）, `SettingsView.swift`（新規）, `SettingsWindowController.swift`（新規）, `MenuBarController.swift`, `AppDelegate.swift`, `MemoEditorView.swift`

逸脱理由: 新規ファイル 3 本は AppSettings（モデル）/ SettingsView（UI）/ SettingsWindowController（lifecycle）の責務分離として許容する（Phase 4-3 の HomeWindow 追加と同じ構造）

Gate:
- menu bar の "Settings..." から Settings ウィンドウが開く
- フォントサイズを変更すると開いている memo window のエディタに即時反映される
- 設定は再起動後も保持される

### Phase 6-4: Import 判断

目的:
- 旧 Sticky データ import の要否を判断し K-04 を解消する

Gate:
- import する / しない の判断が文書化されている
- する場合: Phase 7 スコープとして `docs/roadmap/roadmap.md` と `domain-model.md` の両方に記載
- しない場合: スコープ外として `domain-model.md` と `docs/roadmap/roadmap.md` の両方に明記

## Gate 条件

- 常用しても `ux-principles.md` に記載された基本操作に違和感が残らない
- `Cmd+S` / `Cmd+Enter` / `Cmd+W` がすべて期待通りに動く
- Settings が保持され、再起動後も有効なままである

## コードレビュー Gate

- `Cmd+S` / `Cmd+Enter` の実装が `TextEditor` の入力を妨げない（通常の `s` / `Enter` は影響しない）
- off-screen 補正が origin 保存を上書きしない（画面内補正は表示時のみ、DB 書き込みは発生しない）
- `AppSettings` が `WindowManager` に混入していない（`MemoEditorView` の EnvironmentObject 経由のみ）
- `SettingsWindowController` が `HomeWindowController` と同じ singleton パターンで管理されている

## 回帰 / 副作用チェック

- `Cmd+Enter` が `TextEditor` 内の改行入力（通常の Return）と競合しない
- タイトル連動の再計算が autosave の debounce を乱さない
- off-screen 補正が pinned window のレベル設定を変更しない
- Settings ウィンドウが memo window の focus 挙動に干渉しない
- `UserDefaults` への書き込みが main thread で行われる

## 実機確認項目

1. memo を書いて `Cmd+S` → DB の `updated_at` が更新されていること
2. `Cmd+Enter` で window が閉じ、内容が保存されていること
3. `Cmd+W` で window が閉じること（既存動作の確認）
4. memo window ヘッダーに draft 先頭行が表示されること
5. draft を空にすると `"New Memo"` と表示されること
6. 外部ディスプレイを抜いてアプリを再起動しても window が画面内に表示されること
7. "Settings..." から Settings ウィンドウが開くこと
8. フォントサイズを変更すると即時に memo window のエディタに反映されること
9. アプリを再起動してもフォントサイズ設定が保持されていること

## 変更履歴

- 2026-04-13: 初版作成
- 2026-04-13: レビュー指摘対応（SSOT 補完、関連ファイルに MenuBarController/domain-model.md 追加、Phase 6-1 逸脱理由明記、Cmd+Enter 二重保存防止フラグ設計を技術詳細に追加、off-screen 補正を clampedFrame 一本化、Cmd+, はアクセサリーアプリでは status menu 経由のみと明記、import 判断の反映先を roadmap.md と domain-model.md の両方に指定）
- 2026-04-13: 二次レビュー指摘対応（関連ファイルに roadmap.md を追加、Cmd+, が macOS 標準 Preferences shortcut の完全実装でないことを明示）
