# 多言語対応 & メニュー整理 計画

作成: 2026-04-23
更新: 2026-04-23 (rev.6)

---

## SSOT 参照宣言

ガイド §2 は以下を上位文書と定義しているが、`/Users/hori/Desktop/Sticky/migration/` ディレクトリが現環境に存在しないため参照不可。

> 参照不可: migration/01_product_decision.md, 02_ux_principles.md, 04_technical_decision.md, 06_roadmap.md, 07_project_bootstrap.md, 08_human_checklist.md, 09_seamless_ux_spec.md

代替 SSOT として以下を参照した:

- `docs/product/product-vision.md`
- `docs/product/ux-principles.md`
- `docs/architecture/technical-decision.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`

多言語対応は UX 原則（「すぐ書ける」「シームレスUX」）と直接衝突しないことを確認。言語切り替えは設定操作であり、window lifecycle・focus・seamless window には非接触。

---

## 今回触る関連ファイル

| ファイル | 変更内容 |
|---|---|
| `StickyNativeApp/AppSettings.swift` | `AppLanguage` enum 追加、`language` プロパティ追加 |
| `StickyNativeApp/Strings.swift` | **新規作成** — 全ユーザー向け文字列を一元管理（Str.* キー数: 73） |
| `StickyNativeApp/MenuBarController.swift` | Language サブメニュー追加、ショートカット項目削除、`buildMenu()` 切り出し |
| `StickyNativeApp/HomeView.swift` | 文字列を `Str.*` に置き換え |
| `StickyNativeApp/HomeViewModel.swift` | 文字列を `Str.*` に置き換え |
| `StickyNativeApp/HomeWindowController.swift` | ウィンドウタイトルを `Str.*` に置き換え、言語変更通知で更新 |
| `StickyNativeApp/SettingsView.swift` | 文字列を `Str.*` に置き換え |
| `StickyNativeApp/SettingsWindowController.swift` | ウィンドウタイトルを `Str.*` に置き換え |
| `StickyNativeApp/MemoWindowView.swift` | アラート・ボタン文字列を `Str.*` に置き換え |
| `StickyNativeApp/CheckableTextView.swift` | コンテキストメニュー文字列を `Str.*` に置き換え |
| `StickyNativeApp/MemoTitleFormatter.swift` | デフォルトタイトルを `Str.*` に置き換え |

削除しないファイル:
- `ShortcutsWindowController.swift` — メニューから外すだけで残す

---

## 問題一覧

| ID | 問題 |
|---|---|
| U-01 | 全文字列が日本語ハードコードで英語ユーザーが使えない |
| U-02 | 文字列が10ファイルに分散しており言語追加コストが高い |
| U-03 | メニューに未実装のホットキー項目が残っている（誤案内） |
| A-01 | 言語設定の永続化・変更通知の仕組みが存在しない |
| A-02 | 既存インストールユーザーへのデフォルト言語移行戦略が未定義 |

---

## 修正フェーズ

### Phase 1: AppSettings 拡張 + Strings.swift 新規作成

**目的:** 言語切り替えの基盤を作る（A-01, A-02, U-02 解消）

#### AppSettings 変更

```swift
enum AppLanguage: String { case english, japanese }

// 既存ユーザー移行戦略:
// UserDefaults に "appLanguage" キーが未設定 = 既存インストール → japanese をデフォルトにする
// キーが存在する場合は保存された rawValue から復元し、不正値は .english にフォールバック
private static func defaultLanguage() -> AppLanguage {
    guard let saved = UserDefaults.standard.string(forKey: "appLanguage") else {
        return .japanese  // 既存ユーザーは日本語維持
    }
    return AppLanguage(rawValue: saved) ?? .english
}

@Published var language: AppLanguage = AppLanguage.defaultLanguage()
```

問題 A-02 の解消: キーが未設定なら `.japanese`、保存値があれば rawValue から復元、不正値のみ `.english` にフォールバック。

#### Strings.swift 新規作成

全ユーザー向け文字列（Str.* キー数: **73**）を static computed property に集約。
ShortcutsWindowController は今回メニューから非表示にするため対象外（将来対応）。

**73 の導出根拠:**

| 操作 | 数 |
|---|---|
| ファイル別合計（ShortcutsWindowController 除く10ファイル） | 79 |
| HomeView "New Folder" が L94 ボタン・L517 プレースホルダで2箇所、Str.* キーは1つ | -1 |
| 削除するメニュー項目（"ショートカット" / "キーボードショートカット..."） | -2 |
| "All Memos" が HomeView(L71, L233) と HomeWindowController(L24) の3箇所に重複、Str.* キーは1つ | -1 |
| "デフォルト" / "カラフル" が MenuBarController と SettingsView で同じ MemoColorMode 選択肢として重複、Str.* キーは各1つ | -2 |
| **Str.* キー合計** | **73** |

補足:
- "小" / "中" / "大" も MenuBarController・SettingsView の両方で使われるが、SettingsView の集計 16 件に含まれていないため二重カウントに該当しない（MenuBarController のみで計上済み）。
- SettingsSection の rawValue（"Font Size" 等）は `Label(section.rawValue, ...)` で表示文字列に使われているため Str.* 対象に含む（後述）。

対象文字列一覧（ファイル別）:

**MenuBarController.swift (15 ※削除2件を除く)**
新規メモ / すべてのメモ / 最後に閉じたメモを開く / StickyNativeを終了 /
小 / 中 / 大 / デフォルト / カラフル / 文字サイズ / メモサイズ / メモカラー /
新規メモ作成 ⌘+⌥+Enter / メモ / 設定
~~キーボードショートカット... / ショートカット~~ ← Phase 2a で削除するため対象外

**HomeView.swift (19ユニーク ※"New Folder" が L94 ボタン・L517 プレースホルダで2箇所使用、Str.* キーは1つ)**
Hide Sidebar / Show Sidebar / All Memos / Trash / New Folder / Untitled / Search /
Empty Trash / memo / memos / Folders / Done / Restore / Pin in List / Unpin from List /
Move to Trash / Remove from Folder / Move to Folder / Folder

**HomeViewModel.swift (11)**
Search Results / Pinned / No results / No memos / Trash is empty /
No memos in this folder / Today / Yesterday / Previous 7 Days / Previous 30 Days / Earlier

**HomeWindowController.swift (0 ※"All Memos" は HomeView と共有キー)**
"All Memos" は HomeView.swift:71, HomeView.swift:233, HomeWindowController.swift:24 の3箇所で使用。
すべて `Str.allMemos` 1キーで共有するため、HomeWindowController は独立したキーを持たない。

**SettingsView.swift (16)**
Font Size / Memo Size / Memo Color / Hotkeys ← SettingsSection.rawValue を表示に使用 → `displayName` 経由で翻訳対象（後述）
エディタのフォントサイズ / 新規メモのデフォルトサイズ / カスタム / 新規メモのカラー /
デフォルト / カラフル / 新規メモを標準カラーで固定します。/ 新規メモを複数カラーで順番に作成します。/
グローバルショートカット / 新規メモを作成 / ⌘+⌥+Enter / カスタマイズは今後対応予定です。

**SettingsWindowController.swift (1)**
Settings

**MemoWindowView.swift (3)**
このメモをゴミ箱に移しますか？ / ゴミ箱に移す / キャンセル

**CheckableTextView.swift (9)**
太字 / 下線 / 取り消し線 / リンクを開く / リンクをコピー / 切り取り / コピー / ペースト / すべて選択

**MemoTitleFormatter.swift (1)**
New Memo

**ShortcutsWindowController.swift — 今回対象外**
メニューから非表示にするだけで画面は表示されないため Strings.swift の対象外とする。
将来メニューに戻す際に追加対応する（10文字列: キーボードショートカット / グローバル / 他）。

**Gate:** `Strings.swift` がビルドエラーなくコンパイルされること

---

### Phase 2a: メニュー構造変更（削除 + Language サブメニュー追加）

**目的:** メニューから不要項目を除き、Language 選択 UI を作る（U-03 解消）

変更内容:
1. **削除**: `ショートカット` サブメニュー（ホットキー表示）
2. **削除**: `キーボードショートカット...` メニューアイテム
3. **追加**: `Language / 言語` サブメニュー（English / 日本語、チェックマーク付き）

この時点では文字列はまだハードコードのまま。構造変更だけ。

**Gate:**
- ショートカット項目が消えていること
- Language サブメニューで English / 日本語 が選択でき、`AppSettings.shared.language` に反映されること

---

### Phase 2b: buildMenu() 切り出し + 言語変更通知機構

**目的:** 言語切り替え時にメニューを再構築できる仕組みを作る（A-01 解消）

変更内容:
- メニュー構築ロジックを `buildMenu()` として独立させる
- `AppSettings.$language` の変更を `MenuBarController` が監視し `buildMenu()` を再呼び出し
- `NSWindow` タイトル更新のために `NotificationCenter.post(.languageChanged)` を発行

通知経路:
```
AppSettings.shared.language = newValue（UserDefaults に保存）
→ @Published が変更を通知
→ MenuBarController: Combine sink → buildMenu() 再実行
→ HomeWindowController / SettingsWindowController: Notification → window.title 更新
→ SwiftUI views: @StateObject AppSettings.shared → body 再計算
```

**Gate:**
- Language 選択後、アプリ再起動なしでメニューが再構築されること（この時点では文字列はまだハードコードでよい）
- 確認手段: `buildMenu()` 冒頭に `print("[MenuBar] buildMenu called, language: \(AppSettings.shared.language)")` を仮置きし、Language 切り替え時にコンソールに出力されることで再呼び出しを確認する。Phase 2c 完了後に print は削除する。

---

### Phase 2c: 全メニュー文字列を Str.* に置き換え

**目的:** MenuBarController の全ハードコード文字列を除去（U-01, U-02 の MenuBarController 分を解消）

`buildMenu()` 内の全文字列リテラルを `Str.*` に差し替え。

**Gate:** English / 日本語 選択でメニュー全体の文字列が即時切り替わること

---

### Phase 3: SwiftUI Views の文字列置き換え

**目的:** HomeView / SettingsView 等の全ハードコード文字列を `Str.*` に置き換え（U-01, U-02 完全解消）

対象ファイル:
- `HomeView.swift`
- `HomeViewModel.swift`
- `HomeWindowController.swift`
- `SettingsView.swift`
- `SettingsWindowController.swift`
- `MemoWindowView.swift`
- `CheckableTextView.swift`
- `MemoTitleFormatter.swift`

各 SwiftUI view は `@StateObject private var settings = AppSettings.shared` を使用する。
`language` 変更時に自動再描画される。

#### SettingsSection の翻訳対応

`SettingsView.swift:27` で `Label(section.rawValue, ...)` が rawValue を表示文字列として使用しているため、日本語モードで英語固定になる。翻訳対応（option b）として `displayName` プロパティを追加する:

```swift
// SettingsView.swift の SettingsSection enum に追加
var displayName: String {
    switch self {
    case .font:      return Str.settingsFontSize
    case .memo:      return Str.settingsMemoSize
    case .memoColor: return Str.settingsMemoColor
    case .hotkeys:   return Str.settingsHotkeys
    }
}
```

`Label(section.rawValue, ...)` → `Label(section.displayName, ...)` に変更。
rawValue はコード内部の識別子として残す（変更なし）。

**Gate:**
- 言語切り替え後にすべての SwiftUI 画面が即時切り替わること
- アラートダイアログ、コンテキストメニューも切り替わること

---

## 技術詳細確認

### 責務配置

| 責務 | 置き場所 |
|---|---|
| 言語設定の永続化 | `AppSettings` (UserDefaults key: `"appLanguage"`) |
| 文字列定義 | `Strings.swift`（単一ファイル、全 73 キー） |
| メニュー再構築トリガー | `MenuBarController` が `AppSettings.$language` を Combine で監視 |
| SwiftUI 再描画 | `@StateObject private var settings = AppSettings.shared` |
| NSWindow タイトル更新 | `languageChanged` 通知を受けて各 WindowController が更新 |

### AppKit / SwiftUI 境界

- **AppKit 側** (`MenuBarController`, `*WindowController`): Combine + NotificationCenter で言語変更を受け取る
- **SwiftUI 側** (`HomeView`, `SettingsView`, `MemoWindowView`): `@StateObject` を使用する

#### @StateObject vs @ObservedObject の使い分け

| パターン | 使う場所 | 理由 |
|---|---|---|
| `@StateObject private var settings = AppSettings.shared` | SwiftUI View | View がオーナー。View 再作成時も参照が安定する |
| `@ObservedObject var settings: AppSettings` | 親から渡された場合 | オーナーシップが外部にある場合のみ |
| Combine sink | AppKit（MenuBarController 等） | SwiftUI 外は Combine で直接 `$language` を購読 |

シングルトンを SwiftUI View 内で直接参照する場合は `@StateObject` が適切。
`@ObservedObject` は View が再作成されるたびにオーナーシップが曖昧になるリスクがある。

### 後続 Phase との衝突確認

- SQLite スキーマ変更なし
- Window lifecycle に影響なし（設定操作は非接触）
- `AppSettings` の他プロパティとの衝突なし（新プロパティ追加のみ）

---

## 削除対象の確認

| 項目 | 対応 |
|---|---|
| `ショートカット` サブメニュー（ホットキー表示） | Phase 2a で削除 |
| `キーボードショートカット...` メニューアイテム | Phase 2a で削除 |
| `ShortcutsWindowController.swift` | 削除しない（メニューから外すのみ） |
| `HotkeyManager` 関連 | 今回は触らない |

---

## 回帰 / 副作用チェック

- [ ] 既存メモの表示・編集・保存に影響がないこと
- [ ] メモカラー・フォントサイズ・メモサイズの設定が引き続き動作すること
- [ ] アプリ再起動後に選択した言語が復元されること
- [ ] 既存インストール（UserDefaults に `appLanguage` キーなし）では起動後も日本語であること
- [ ] 新規インストールでは起動後に英語がデフォルトになること
- [ ] 日本語選択時に既存の日本語 UI と一致すること
- [ ] `SettingsView` のセクションヘッダー（Font Size / Memo Size 等）が言語に応じて切り替わること（`section.displayName` 経由で翻訳される）
- [ ] `SettingsSection.rawValue` はコード内識別子として残り、UI 表示では使われていないこと

---

## 実機確認項目

- [ ] メニューバーアイコン → Language → English 選択 → メニューが英語に切り替わる
- [ ] メニューバーアイコン → Language → 日本語 選択 → メニューが日本語に切り替わる
- [ ] All Memos ウィンドウを開いた状態で言語切り替え → 即時反映される
- [ ] アプリ再起動 → 前回選択した言語が復元される
- [ ] 既存インストール相当（UserDefaults を消去した状態）: 起動後に日本語になっている
- [ ] `ショートカット` サブメニューがメニューに存在しないこと
- [ ] `キーボードショートカット...` がメニューに存在しないこと
- [ ] アラートダイアログが言語に応じて表示される
- [ ] コンテキストメニューが言語に応じて表示される

---

## セルフチェック結果

### SSOT 整合
- [x] migration/* 参照不可を明示し、docs/* を代替 SSOT として使用
- [x] docs/product/product-vision.md を確認した
- [x] docs/product/ux-principles.md を確認した（UX 原則との衝突なし）
- [x] docs/architecture/technical-decision.md を確認した
- [x] stickynative-ai-planning-guidelines.md を確認した

### 変更範囲
- [x] Phase ごとに主目的は1つ（Phase 2 を 2a/2b/2c に分割済み）
- [x] ついで作業を入れていない（HotkeyManager 等は非接触）

### 技術詳細
- [x] ファイルごとの責務が明確
- [x] UserDefaults の保存経路が一本化されている
- [x] イベント経路（Combine + Notification + @StateObject）が説明できる
- [x] @StateObject / @ObservedObject の使い分けを明示した

### Window / Focus
- [x] Window 責務は非接触
- [x] Focus 制御は非接触
- [x] seamless window に影響なし

### Persistence
- [x] SQLite スキーマ変更なし
- [x] 言語設定は UserDefaults（AppSettings）に一本化

### 実機確認
- [ ] 言語切り替えを実機で確認する
- [ ] 既存インストール相当の挙動を確認する

---

## 変更履歴

- 2026-04-23: 初版作成
- 2026-04-23: 指摘事項5件を反映（SSOT明示、Phase 2分割、A-02追加、文字列実カウント82確定、セルフチェック追加）
- 2026-04-23: 指摘事項5件を反映 rev.3（defaultLanguage バグ修正、@StateObject 使い分け明示、SettingsSection 回帰チェック復活、Phase 2b/2c の Issue ID 追記、ShortcutsWindowController を今回対象外とし文字列数を72に修正）
- 2026-04-23: 指摘事項2件を反映 rev.4（72の導出根拠を表で明示・ファイル別カウント修正、Phase 2b Gate に print ログによる確認手段を追記）
- 2026-04-23: 指摘事項2件を反映 rev.5（SettingsSection.displayName 追加で翻訳対応・キー数75に修正、"All Memos" 3箇所共有キーとしてカウント整理）
- 2026-04-23: 指摘事項1件を反映 rev.6（"デフォルト"/"カラフル" のクロスファイル重複 -2 を導出根拠に追加、キー数 75→73 に修正）
