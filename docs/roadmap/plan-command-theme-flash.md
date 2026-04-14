# 実装計画書: コマンドテーマカラー & フラッシュフィードバック

作成: 2026-04-14

---

## 目的

メモウィンドウの4つのショートカットを実行したとき、コマンドごとのテーマカラーでウィンドウ縁を一瞬光らせてフィードバックを提供する。あわせて Default Shortcut ウィンドウにもカラーを表示し、コマンドと色の対応を一目で把握できるようにする。

---

## カラー設計

| コマンド | キー | カラー名 | Hex | RGB (0–1) |
|---|---|---|---|---|
| 保存 | ⌘S | ソフトブルー | `#4DA3F5` | (0.30, 0.64, 0.96) |
| 保存して閉じる | ⌘Return | ミントグリーン | `#34C97A` | (0.20, 0.79, 0.48) |
| 閉じる | ⌘W | ウォームイエロー | `#F5C842` | (0.96, 0.78, 0.26) |
| ゴミ箱 | ⌘Delete | ソフトレッド | `#F56060` | (0.96, 0.38, 0.38) |

いずれも彩度を抑えた目に優しいトーン。

---

## アニメーション仕様

- **手法**: SwiftUI `withAnimation(.easeOut)` + overlay opacity
- **トリガー**: 各ショートカット実行時
- **動作**: テーマカラーの縁が瞬時に出現し、0.5秒かけてフェードアウト
- **縁の太さ**: lineWidth 2（通常の白縁 lineWidth 1 より少し太く目立たせる）
- **フェード開始タイミング**: トリガーから 50ms 後（視認性確保のため）

---

## 実装フェーズ

### Phase 1: CommandTheme 定義

**新規ファイル**: `StickyNativeApp/CommandTheme.swift`

```swift
import SwiftUI

enum CommandTheme: Equatable {
  case save
  case saveAndClose
  case close
  case trash

  var color: Color {
    switch self {
    case .save:         return Color(red: 0.30, green: 0.64, blue: 0.96)
    case .saveAndClose: return Color(red: 0.20, green: 0.79, blue: 0.48)
    case .close:        return Color(red: 0.96, green: 0.78, blue: 0.26)
    case .trash:        return Color(red: 0.96, green: 0.38, blue: 0.38)
    }
  }

  var label: String {
    switch self {
    case .save:         return "保存"
    case .saveAndClose: return "保存して閉じる"
    case .close:        return "閉じる"
    case .trash:        return "ゴミ箱に移す"
    }
  }
}
```

**変更ファイル**: `StickyNative.xcodeproj/project.pbxproj`（ファイル登録）

---

### Phase 2: MemoWindowUIState にフラッシュ状態追加

**変更ファイル**: `StickyNativeApp/MemoWindowUIState.swift`

2種類の Task を管理する。

- `flashTask`: フェードアウトを担当。連打で上書きされる
- `actionTask`: 遅延アクション（close / modal 表示）を担当。新しいアクションが来たら前のものをキャンセルして意図しない遅延発火を防ぐ

```swift
// 追加
@Published var flashCommand: CommandTheme? = nil
private var flashTask: Task<Void, Never>?
private var actionTask: Task<Void, Never>?

func triggerFlash(_ command: CommandTheme) {
  flashTask?.cancel()
  flashCommand = command
  flashTask = Task { @MainActor in
    try? await Task.sleep(for: .milliseconds(50))
    guard !Task.isCancelled else { return }
    withAnimation(.easeOut(duration: 0.5)) {
      flashCommand = nil
    }
  }
}

func scheduleAction(after ms: Int, action: @escaping @MainActor () -> Void) {
  actionTask?.cancel()
  actionTask = Task { @MainActor in
    try? await Task.sleep(for: .milliseconds(ms))
    guard !Task.isCancelled else { return }
    action()
  }
}
```

**連打時の挙動**:
- `flashTask`: 新しいフラッシュが来たら前のフェードをキャンセルして色を上書き
- `actionTask`: 新しいアクションが来たら前の遅延 close / modal をキャンセル。⌘W 連打で close が2回発火することはない

---

### Phase 3: MemoWindowView の縁フラッシュ

**変更ファイル**: `StickyNativeApp/MemoWindowView.swift`

白縁 overlay の**上に**カラー縁 overlay を重ねて目立たせる。SwiftUI では後から追加した `.overlay` が前面になる。

```swift
// 既存（白縁）
.overlay(
  RoundedRectangle(cornerRadius: 18, style: .continuous)
    .stroke(Color.white.opacity(0.35), lineWidth: 1)
)
// 追加（カラー縁・白縁の上に前面で重なる）
.overlay(
  RoundedRectangle(cornerRadius: 18, style: .continuous)
    .stroke(
      uiState.flashCommand?.color ?? .clear,
      lineWidth: 2
    )
    .opacity(uiState.flashCommand != nil ? 1 : 0)
    .animation(.easeOut(duration: 0.5), value: uiState.flashCommand != nil)
)
```

各ショートカットボタンのアクションに `triggerFlash` を追加する。**close 系は遅延実行**して、フラッシュが視認できる時間（200ms）を確保してから閉じる。

⌘S はフラッシュ後に即時実行（閉じないため遅延不要）。残り3コマンドはフラッシュ後 200ms 遅延してアクションを実行し、フラッシュを必ず視認できるようにする。

```swift
// 保存（フラッシュ後すぐ実行・閉じないので遅延不要）
Button(action: {
  uiState.triggerFlash(.save)
  onSave()
}) { ... }
  .keyboardShortcut("s", modifiers: .command)

// 保存して閉じる（200ms 後に閉じる）
Button(action: {
  uiState.triggerFlash(.saveAndClose)
  uiState.scheduleAction(after: 200) { onSaveAndClose() }
}) { ... }
  .keyboardShortcut(.return, modifiers: .command)

// 閉じる（200ms 後に閉じる）
Button(action: {
  uiState.triggerFlash(.close)
  uiState.scheduleAction(after: 200) { onClose() }
}) { ... }
  .keyboardShortcut("w", modifiers: .command)

// ゴミ箱（200ms 後に確認モーダルを表示・close 系と統一）
Button(action: {
  uiState.triggerFlash(.trash)
  uiState.scheduleAction(after: 200) { showingTrashConfirmation = true }
}) { ... }
  .keyboardShortcut(.delete, modifiers: .command)
```

**設計方針の統一**:
- 全コマンドで「フラッシュを必ず視認できる」体験に統一
- `scheduleAction` は `actionTask` で管理されるため、200ms 以内に別コマンドを押すと前のアクションはキャンセルされる
- 遅延中のキャンセルで意図しない close / modal 発火を防ぐ

---

### Phase 4: Default Shortcut ウィンドウへのカラードット追加

**変更ファイル**: `StickyNativeApp/ShortcutsWindowController.swift`

メモウィンドウセクションの各行に `CommandTheme` の色ドットを追加する。

```swift
// row(key:label:) に color 引数を追加
private func row(key: String, label: String, theme: CommandTheme? = nil) -> some View {
  HStack {
    if let theme {
      Circle()
        .fill(theme.color)
        .frame(width: 8, height: 8)
    }
    Text(label).font(.system(size: 13))
    Spacer()
    Text(key)
      .font(.system(size: 12, design: .monospaced))
      ...
  }
}

// 呼び出し側
row(key: "⌘ + S",     label: "保存",             theme: .save)
row(key: "⌘ + Enter", label: "保存して閉じる",    theme: .saveAndClose)
row(key: "⌘ + W",     label: "閉じる",            theme: .close)
row(key: "⌘ + ⌫",    label: "ゴミ箱に移す（確認あり）", theme: .trash)
```

---

## 変更ファイル一覧

| ファイル | 変更内容 |
|---|---|
| `StickyNativeApp/CommandTheme.swift` | 新規作成 |
| `StickyNative.xcodeproj/project.pbxproj` | CommandTheme.swift を登録 |
| `StickyNativeApp/MemoWindowUIState.swift` | flashCommand / triggerFlash 追加 |
| `StickyNativeApp/MemoWindowView.swift` | フラッシュ overlay・ショートカットに triggerFlash 追加 |
| `StickyNativeApp/ShortcutsWindowController.swift` | カラードット追加 |

---

## Gate 条件

| フェーズ | 通過条件 |
|---|---|
| Phase 1–2 完了 | ビルド成功 |
| Phase 3 完了 | 各ショートカット実行時にウィンドウ縁が対応色でフラッシュすること |
| Phase 4 完了 | Default Shortcut ウィンドウの各行にカラードットが表示されること |
| 実装完了 | 全フェーズ通過 + 実機確認（回帰なし） |

---

## 実機確認項目

1. ⌘S → 青の縁フラッシュが出てフェードアウトするか
2. ⌘Return → 緑の縁フラッシュ後にウィンドウが閉じるか
3. ⌘W → 黄の縁フラッシュ後にウィンドウが閉じるか
4. ⌘Delete → 赤の縁フラッシュ後に確認モーダルが出るか
5. Default Shortcut ウィンドウの4行に正しい色ドットがあるか
6. 複数メモウィンドウが開いている場合、操作したウィンドウだけフラッシュするか
7. フラッシュ中に別のショートカットを連打しても崩れないか

---

## 変更履歴

- 2026-04-14: 新規作成
- 2026-04-14: レビュー指摘3点を修正
  - close 系コマンドを 200ms 遅延実行に変更してフラッシュを視認可能に
  - triggerFlash に Task キャンセル管理を追加して連打競合を解消
  - overlay 順序の説明を「白縁の上にカラー縁を前面で重ねる」に統一
- 2026-04-14: レビュー指摘2点を修正
  - actionTask を追加して遅延アクションのキャンセル管理を明記（意図しない遅延 close / modal 発火を防止）
  - trash を close 系と統一（200ms 遅延後にモーダル表示）。⌘S 即時・残り3コマンド 200ms 遅延で体験を整理
- 2026-04-14: 軽微な文言修正。closeTask → actionTask（modal も担当するため）。「全4コマンド統一」の表現を「⌘S 即時・残り3コマンド 200ms 遅延」に修正
