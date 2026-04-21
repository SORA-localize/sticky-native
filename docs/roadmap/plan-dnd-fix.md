# D&D 修正計画

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-21 | 初版作成 |
| 2026-04-21 | AI planning guide レビュー反映：必須構成、Issue ID、Phase、技術詳細、回帰チェックを追加 |
| 2026-04-21 | 再レビュー反映：migration SSOT 参照、K-01 分割、folder row 専用 drop target、実機確認表現を修正 |

---

## SSOT 参照宣言

| 文書 | 参照箇所 | 判断への影響 |
|------|----------|-------------|
| `/Users/hori/Desktop/Sticky/migration/README.md` | migration SSOT の位置付け | 上位文書を優先する前提を確認 |
| `/Users/hori/Desktop/Sticky/migration/01_product_decision.md` | product decision | D&D 補修は Home 管理 UI の操作改善であり、product decision 変更なし |
| `/Users/hori/Desktop/Sticky/migration/02_ux_principles.md` | シームレス UX / 軽量操作の原則 | D&D は Home 管理 UI に閉じ、memo window の初速や focus を阻害しない |
| `/Users/hori/Desktop/Sticky/migration/04_technical_decision.md` | SwiftUI / AppKit 責務、local persistence | D&D は SwiftUI Home UI の範囲で扱い、AppKit window 基盤に触れない |
| `/Users/hori/Desktop/Sticky/migration/06_roadmap.md` | roadmap | D&D 補修は既存 Home / Folder 管理の補修であり、phase 方針変更なし |
| `/Users/hori/Desktop/Sticky/migration/07_project_bootstrap.md` | project bootstrap | build / project 構成確認の前提として参照 |
| `/Users/hori/Desktop/Sticky/migration/08_human_checklist.md` | human checklist | 実機確認項目の粒度の参考。今回の仕様判断には影響なし |
| `/Users/hori/Desktop/Sticky/migration/09_seamless_ux_spec.md` | SeamlessWindow / first mouse / focus | 今回は SeamlessWindow、first mouse、focus を対象外とする根拠 |
| `docs/roadmap/stickynative-ai-planning-guidelines.md` | 計画書必須構成、Issue ID、Gate、技術詳細確認 | 本計画の構成基準 |
| `docs/roadmap/plan-folder-dnd.md` | Phase 3: Drag & Drop 実装、UTType 登録、Trash D&D 無効化 | 今回の修正対象と回帰確認の根拠 |
| `docs/architecture/technical-decision.md` | SwiftUI / AppKit 採用方針 | D&D は SwiftUI 標準 API の範囲で修正する |
| `docs/architecture/persistence-boundary.md` | 保存責務 | D&D 後のフォルダ移動は既存 persistence 経路へ委譲する |

本計画は `plan-folder-dnd.md` の D&D 実装後に発生した「フォルダ行へドロップできない」問題を、最小差分で検証・修正するための補修計画である。
上位 migration SSOT に照らし、今回の変更は Home 管理 UI 内の D&D 補修に限定する。`SeamlessWindow`、focus、first mouse、global shortcut、window lifecycle は対象外であり、仕様変更しない。

---

## 今回触る関連ファイル

| ファイル | 触る理由 |
|----------|----------|
| `StickyNativeApp/HomeView.swift` | `SidebarRowView` の drop target、未使用 `scope`、`.if()` 拡張、Trash view の drag 可否を確認・修正する |
| `StickyNativeApp/MemoTransferItem.swift` | `Transferable` / `UTType.memoItem` の定義確認。原則変更しない |
| `StickyNative.xcodeproj/project.pbxproj` | 生成 Info.plist への UTType 登録方法を確認。必要な場合のみ変更する |

---

## 問題一覧

| ID | 種別 | 内容 |
|----|------|------|
| U-05 | D&D | フォルダ行へメモをドロップしても受理されない |
| U-06 | D&D | Trash view のメモがドラッグ可能な場合、元計画の Gate 条件に反する |
| A-01 | View 責務 | `SidebarRowView.scope` が `body` 内で未使用 |
| A-02 | View 責務 | `HomeView` の `.if()` 拡張が drop target の条件付けに使われており、原因調査を難しくしている |
| K-01a | 設定整合 | `Info.plist` は生成方式のため、project 設定上の確認先が曖昧 |
| K-01b | 設定整合 | build 生成物に `UTExportedTypeDeclarations` が含まれるか、または未登録でも同一プロセス内 D&D が成立するか未確認 |
| K-02 | 検証整合 | SourceKit エラーを実エラーとして扱うか、index cache 起因として扱うかがビルドで未確認 |

---

## 現状の問題

### SourceKit エラー

`HomeViewModel`・`HomeScope`・`Folder` は別ファイルに存在しているため、SourceKit の index cache に起因する可能性がある。ただし確認なしに無視しない。Phase 1 完了後の `xcodebuild` で実ビルドエラーとして残るかを Gate 条件にする。

### タップ vs ドラッグの競合

`.draggable` と `.onTapGesture` は基本的に別経路で処理されるため、今回の主原因とはみなさない。

- 素早いクリック: `.onTapGesture` -> `onOpen()`
- クリックして移動: `.draggable` -> drag 開始

ただし、実機確認でクリック開封が阻害されていないことは回帰チェックに含める。

### ドロップできない原因仮説

`SidebarRowView` の `.if(onDrop != nil)` 経由で `.dropDestination` を条件付けしていることが主原因候補。

```swift
.if(onDrop != nil) { view in
  view.dropDestination(for: MemoTransferItem.self) { items, _ in
    guard let item = items.first else { return false }
    onDrop?(item.id)
    return true
  } isTargeted: { targeted in
    isDropTargeted = targeted
  }
}
```

この構造では、drop 対応行と非対応行で SwiftUI の view 型が分岐し、実際の drop target 認識や検証が追いづらい。現時点では「根本原因」と断定せず、Phase 1 の修正で検証する。

### 副次原因候補

`plan-folder-dnd.md` で中リスクとしていた UTType 登録も確認対象に含める。現在の project は `GENERATE_INFOPLIST_FILE = YES` のため、単純に `StickyNativeApp/Info.plist` を探すだけでは確認できない。

確認対象:

- `StickyNativeApp/MemoTransferItem.swift` の `UTType.memoItem`
- `StickyNative.xcodeproj/project.pbxproj` の Info.plist 生成設定
- build 生成物の `Info.plist` に `UTExportedTypeDeclarations` が入るか

---

## Issue -> Phase 対応表

| Issue | 解決 Phase |
|-------|------------|
| U-05 | Phase 1 |
| U-06 | Phase 2 |
| A-01 | Phase 2 |
| A-02 | Phase 1 / Phase 2 |
| K-01a | Phase 1 |
| K-01b | Phase 3 |
| K-02 | Phase 1 |

---

## 修正フェーズ

### Phase 1: Folder row drop target の疎通確認と最小修正

**主目的:** フォルダ行への drop が受理される状態にする。

**変更対象:** `StickyNativeApp/HomeView.swift`

**確認対象:** `StickyNative.xcodeproj/project.pbxproj`

1. `SidebarRowView` の `.dropDestination` を `.if(onDrop != nil)` 経由ではなく、folder row のみに付与する。
2. All Memos / Trash 行には `.dropDestination` を付与しない。
3. `isTargeted` は folder row hover 中だけ `true` にする。
4. project が生成 Info.plist 方式であることを確認し、UTType 詳細確認は Phase 3 に送る。

修正案 A（第一候補）:

`folderSidebarRow(folder:)` 側で folder row のみに `.dropDestination` を付与する。通常の `sidebarRow(...)` は drop 関連引数を持たず、All Memos / Trash 行には drop target を一切付けない。

```swift
private func folderSidebarRow(folder: Folder) -> some View {
  SidebarRowView(...)
    .dropDestination(for: MemoTransferItem.self) { items, _ in
      guard let item = items.first else { return false }
      onAssignFolder(item.id, folder.id)
      return true
    } isTargeted: { targeted in
      // folder row の hover state を更新する
    }
}
```

修正案 B（第一候補で row hover state の配置が不自然な場合）:

`SidebarRowView` 内で `baseRow` と `dropConfiguredRow` を分ける。ただし `.dropDestination` は `onDrop != nil` の folder row のみに付け、`.if()` 汎用拡張には戻さない。

```swift
@ViewBuilder
private var dropConfiguredRow: some View {
  if let onDrop {
    baseRow
      .dropDestination(for: MemoTransferItem.self) { items, _ in
        guard let item = items.first else { return false }
        onDrop(item.id)
        return true
      } isTargeted: { targeted in
        isDropTargeted = targeted
      }
  } else {
    baseRow
  }
}
```

`baseRow` は Button 本体、`dropConfiguredRow` は folder row のみ drop target を持つ wrapper とする。

**検証用代替案:** folder row 専用 wrapper でも drop が受理されない場合に限り、一時的に `.dropDestination` 常時付与案を試して切り分ける。その場合も All Memos / Trash 行の OS フィードバックを確認し、仕様として採用するかは Phase 2 で判断する。

**Gate 条件:**

- [ ] `xcodebuild -project StickyNative.xcodeproj -scheme StickyNative -configuration Debug build` が通ること
- [ ] SourceKit エラーが実ビルドエラーとして残らないこと
- [ ] メモ行をドラッグ開始すると drag ghost が表示されること
- [ ] フォルダ行 hover 中にアプリ側ハイライトが出ること
- [ ] フォルダ行へ drop するとメモが移動し、カウントが更新されること
- [ ] 生成 Info.plist 方式であることを確認し、UTType 詳細は Phase 3 の Gate で扱うこと

補足: 通常 build で SourceKit 相当の問題が再現しないが Xcode 上だけ残る場合のみ、DerivedData 起因として clean build を検討する。clean build は Phase 1 の必須 Gate ではない。

### Phase 2: 回帰整理と不要コード削除

**主目的:** D&D 補修後の不要コードと元計画の Gate 漏れを整理する。

**変更対象:** `StickyNativeApp/HomeView.swift`

1. `SidebarRowView.scope` を削除する。
2. `sidebarRow()` / `folderSidebarRow()` から `scope` 引数渡しを削除する。
3. `.if()` 拡張の使用箇所がゼロであることを確認し、`private extension View { func if(...) }` を削除する。
4. 現状 `MemoRowView` は `isTrashView` に関係なく `.draggable(MemoTransferItem(id: memo.id))` を付与しているため、`isTrashView == true` では `.draggable` を付与しない構造に変更する。
5. クリック開封と D&D が両方成立することを実機確認する。
6. All Memos / Trash 行が drop target として見えないことを確認する。Phase 1 の検証用代替案で常時 `.dropDestination` を試した場合は、OS フィードバックが UX 上許容できるかをここで判断する。

**Gate 条件:**

- [ ] `SidebarRowView.scope` の参照が残っていないこと
- [ ] `.if()` 拡張の使用箇所が残っていないこと
- [ ] Trash view のメモがドラッグできないこと
- [ ] 非 Trash view のメモはドラッグできること
- [ ] All Memos / Trash 行でアプリ側 drop highlight が出ないこと
- [ ] All Memos / Trash 行が OS レベルでも drop 可能に見えないこと。見える場合は folder row 専用 wrapper に戻すこと
- [ ] メモ行クリックで通常どおり window が開くこと
- [ ] D&D 後に選択中 scope とカウント表示が破綻しないこと

### Phase 3: UTType / Info.plist 設定確認

**主目的:** Transferable の content type 設定が runtime で drop を阻害していないことを確認する。

**変更対象:** `StickyNativeApp/MemoTransferItem.swift` / `StickyNative.xcodeproj/project.pbxproj`

1. `MemoTransferItem` が `Transferable, Codable` であり、`CodableRepresentation(contentType: .memoItem)` を使っていることを確認する。
2. `UTType.memoItem` の exported identifier が `com.stickynative.memo-item` であることを確認する。
3. Phase 1 で確認した生成 Info.plist 方式を前提に、build 生成物の `Info.plist` に `UTExportedTypeDeclarations` が存在するか確認する。
4. 存在しない場合は、Xcode project 側で生成 Info.plist に UTType declaration を入れる方法を明文化してから実装する。

**Gate 条件:**

- [ ] `MemoTransferItem` の content type が `.memoItem` で一貫していること
- [ ] 生成 Info.plist に `UTExportedTypeDeclarations` が含まれること、または未登録でも同一プロセス内 D&D が成立することを実機で確認すること
- [ ] UTType 未登録が原因の場合、project 設定変更後に D&D が成立すること

---

## 技術詳細確認

### 責務配置

| 責務 | 配置 |
|------|------|
| drag payload | `MemoTransferItem` |
| drag source | `MemoRowView` |
| drop target | `SidebarRowView` または folder row 専用 wrapper |
| drop hover state | `SidebarRowView.isDropTargeted` |
| folder assignment | `HomeView.onAssignFolder` から既存 handler へ委譲 |
| persistence | 既存 `PersistenceCoordinator` / store 経路を使い、今回追加しない |

### メモリで持つ情報

- `isDropTargeted`: View 局所 state。永続化しない。
- `MemoTransferItem.id`: drag 中だけ使う memo ID。永続化しない。
- folder assignment 結果: 既存 persistence 経路で保存し、`viewModel.reload()` 相当の既存更新経路で UI に反映する。

### SwiftUI / AppKit 境界

今回の変更は Home 管理 UI 内の SwiftUI D&D に限定する。`SeamlessWindow`、focus、global shortcut、window lifecycle には触れない。

### イベント経路

```text
MemoRowView.draggable
  -> MemoTransferItem(id)
  -> SidebarRowView.dropDestination
  -> onDrop(memoID)
  -> HomeView.onAssignFolder(memoID, folderID)
  -> 既存 persistence 更新
  -> 既存 reload / published state 更新
  -> memo list と count が再描画
```

### 状態遷移

| 操作 | 期待状態 |
|------|----------|
| drag 開始 | memo ID を payload として保持 |
| folder hover | `isDropTargeted = true` で folder row のみハイライト |
| folder drop | folder assignment を実行し、対象 scope / count を更新 |
| All Memos / Trash hover | drop target ではないためアプリ側ハイライトなし |
| All Memos / Trash drop | drop target ではないため移動なし |
| Trash view drag | drag 開始しない |

### 後続 Phase との衝突

- DB schema は変更しない。
- folder assignment の保存経路は既存経路に限定する。
- window / focus / shortcut の責務には触れない。
- Home / Trash / Folder 管理 UI の文言や構造を追加変更しない。

---

## 変更しないこと

- SQLite schema
- `MemoTransferItem` の payload 形式。ただし UTType 登録が原因と判明した場合を除く
- folder 作成・rename・delete の仕様
- All Memos / Trash の意味
- window lifecycle / focus / global shortcut

---

## 回帰・副作用チェック

| 観点 | 確認方法 |
|------|----------|
| drop target 認識 | folder row hover で highlight が出ること |
| drop 実行 | drop 後に memo の folder assignment と count が更新されること |
| drop 対象外 | All Memos / Trash が drop target として見えず、drop しても移動しないこと |
| Trash drag | Trash view の memo から drag が始まらないこと |
| click open | 非 Trash view の memo click で window が開くこと |
| SourceKit | `xcodebuild` で実エラーがないこと |
| UTType | 生成 Info.plist または実機 D&D で content type 問題がないこと |
| 不要コード | `SidebarRowView.scope` と `.if()` 拡張が残っていないこと |

---

## 実機確認項目

- [ ] 非 Trash view のメモをクリックすると memo window が開く
- [ ] 非 Trash view のメモをドラッグ開始すると drag ghost が出る
- [ ] フォルダ行 hover で背景色が変化する
- [ ] フォルダ行 drop でメモが移動する
- [ ] 移動後に移動元リスト・移動先 count が更新される
- [ ] All Memos 行が drop target として見えず、移動しない
- [ ] Trash 行が drop target として見えず、移動しない
- [ ] Trash view のメモはドラッグできない
- [ ] All Memos / Trash 行が drop target として見えない

---

## Section 12 セルフチェック結果

### SSOT 整合

- [x] `stickynative-ai-planning-guidelines.md` を確認した
- [x] migration README を確認した
- [x] `01_product_decision.md` を確認した
- [x] `02_ux_principles.md` を確認した
- [x] `04_technical_decision.md` を確認した
- [x] `06_roadmap.md` を確認した
- [x] `07_project_bootstrap.md` を確認した
- [x] `08_human_checklist.md` を確認した
- [x] `09_seamless_ux_spec.md` を確認した
- [x] `plan-folder-dnd.md` を確認した
- [x] architecture 文書との責務境界を確認した

### 変更範囲

- [x] 主目的は D&D 補修に限定している
- [x] window / focus / shortcut には触れない
- [x] DB schema には触れない

### 技術詳細

- [x] ファイルごとの責務を明記した
- [x] メモリ state と persistence の境界を明記した
- [x] イベント経路と状態遷移を明記した

### Window / Focus

- [x] Window 責務に触れない
- [x] Focus 制御に触れない
- [x] first mouse の扱いを今回の対象外として明記した

### Persistence

- [x] 保存経路は既存 folder assignment 経路に限定した
- [x] frame / open 状態には触れない
- [x] relaunch 時の扱いには触れない

### 実機確認

- [x] D&D の実機確認項目を定義した
- [x] click open の回帰確認を定義した
- [x] Trash view の drag 無効確認を定義した
