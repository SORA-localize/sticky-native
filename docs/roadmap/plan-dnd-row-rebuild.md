# 計画：Home メモ行 D&D の row surface 再設計

作成日: 2026-04-22

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-22 | 初版作成：境界線付近だけ掴める D&D 実装を破棄し、一般的な row drag surface / action surface 分離方針で再計画 |
| 2026-04-22 | 再レビュー反映：`.onTapGesture` と `.draggable` の競合を最優先リスクに昇格し、実装前に gesture probe Phase を追加 |
| 2026-04-22 | 再レビュー反映2：UTType 未登録を独立リスクとして追加し、明示 Info.plist / project 設定確認を Phase 4 に追加 |
| 2026-04-22 | 再レビュー反映3：Section 12 セルフチェックに relaunch 対象外を明記 |
| 2026-04-22 | 再レビュー反映4：Phase 1 probe の配置・起動・削除手順を具体化し、UTType 登録と folder drop 確認を Phase 分割 |

---

## 目的

Home 管理 UI のメモ行 D&D を、一般的なメモアプリの挙動に合わせて作り直す。

現在の `MemoRowView` は root `HStack` に tap / hover / draggable / contextMenu / row trailing buttons を重ねており、メモ行全体を自然に掴めない。実機確認では、メモ同士の境界線付近だけが drag 開始点になる挙動が確認された。これは payload / DB / folder drop 以前の row hit testing / gesture 設計問題として扱う。

この計画では、後付け modifier 調整ではなく、まず `.onTapGesture` と `.draggable` の共存可否を単独 probe で確認する。その結果を踏まえて、`MemoRowView` の責務を `drag surface` と `action surface` に分離する。

---

## SSOT 参照宣言

### 参照できた文書

| 文書 | 参照箇所 | 判断への影響 |
|------|----------|-------------|
| `docs/roadmap/stickynative-ai-planning-guidelines.md` | 計画必須構成、Issue ID、MECE、フェーズ上限、probe ルール | 本計画の構成と Phase 分割の基準 |
| `docs/roadmap/plan-folder-dnd.md` | 既存 Folder / D&D 計画 | 後付け `.draggable` 方針が現観測と合わないため、D&D 部分だけ再計画対象 |
| `docs/product/product-vision.md` | `1 memo = 1 window`、思考の初速 | Home D&D は中心体験を壊さない管理 UI の補助操作として扱う |
| `docs/product/ux-principles.md` | 自然 / 軽い / 明快、macOS 標準挙動優先 | 行全体を自然に掴める D&D と、ボタン操作の明確な分離を優先 |
| `docs/product/mvp-scope.md` | Home / Trash / Settings は後続管理 UI | window / focus 基盤に触れず Home 管理 UI に閉じる根拠 |
| `docs/roadmap/roadmap.md` | Phase 4 Home、Phase 5 Session | D&D 修正を Management Surface / Folder 整理の範囲に限定 |
| `docs/architecture/technical-decision.md` | SwiftUI / AppKit / SQLite 境界 | Home row UI は SwiftUI、window / focus は対象外 |
| `docs/architecture/domain-model.md` | Memo / Session / SQLite schema | folder assignment の既存保存経路を変更しない根拠 |
| `docs/architecture/persistence-boundary.md` | persistence 責務 | D&D UI 復旧と persistence hardening を分離 |

### 参照不能だった上位 migration SSOT

AI planning guide は以下を必須 SSOT としているが、この workspace では `/Users/hori/Desktop/Sticky/migration` が存在せず参照不能だった。

```text
/Users/hori/Desktop/Sticky/migration/README.md
/Users/hori/Desktop/Sticky/migration/01_product_decision.md
/Users/hori/Desktop/Sticky/migration/02_ux_principles.md
/Users/hori/Desktop/Sticky/migration/04_technical_decision.md
/Users/hori/Desktop/Sticky/migration/06_roadmap.md
/Users/hori/Desktop/Sticky/migration/07_project_bootstrap.md
/Users/hori/Desktop/Sticky/migration/08_human_checklist.md
/Users/hori/Desktop/Sticky/migration/09_seamless_ux_spec.md
```

暫定判断:

- migration SSOT が参照不能なため、repo 内の `docs/product/*`、`docs/architecture/*`、`docs/roadmap/*` を暫定 SSOT とする。
- migration 文書が復旧した場合、実装前に SSOT 整合を再確認する。
- window / focus / first mouse / global shortcut / SeamlessWindow は今回の対象外。
- Home 管理 UI の D&D に閉じる。

---

## 今回触る関連ファイル

| ファイル | 扱い |
|----------|------|
| `StickyNativeApp/HomeView.swift` | 主対象。`MemoRowView` と `SidebarRowView` の D&D 責務を整理 |
| `StickyNativeApp/HomeDragGestureProbeView.swift` | Phase 1 の一時 probe 用ファイル。Phase 1 完了後に削除し、production に残さない |
| `StickyNativeApp/MemoTransferItem.swift` | 既存 payload 型。必要なら保持または最小修正 |
| `StickyNativeApp/Info.plist` | `UTExportedTypeDeclarations` を明示登録する対象 |
| `StickyNative.xcodeproj/project.pbxproj` | `INFOPLIST_FILE = StickyNativeApp/Info.plist` へ切り替える対象 |
| build 後 `Info.plist` | `UTExportedTypeDeclarations` 確認対象 |
| `StickyNativeApp/HomeWindowController.swift` | 既存 `onAssignFolder` 到達確認のみ。原則変更しない |
| `StickyNativeApp/PersistenceCoordinator.swift` | 既存 assignment 経路確認のみ。原則変更しない |
| `StickyNativeApp/FolderStore.swift` | 既存 assignment 経路確認のみ。原則変更しない |
| `StickyNativeApp/SQLiteStore.swift` | 既存 `updateMemoFolder` 経路確認のみ。原則変更しない |
| `docs/roadmap/plan-folder-dnd.md` | 参照のみ。本計画内で旧 D&D 方針との差分を明記し、原則編集しない |
| `docs/roadmap/plan-dnd-row-rebuild.md` | 本計画書 |

今回触らないもの:

- `SeamlessWindow`
- `SeamlessHostingView`
- first mouse / focus
- global shortcut
- DB schema / migration
- persistence hardening

---

## 現状確認

現行 `MemoRowView` の構造:

```text
List row
└─ MemoRowView root HStack
   ├─ title / preview
   ├─ Spacer
   └─ date / pin Button / trash Button

root HStack に以下を後付け:
- contentShape(Rectangle())
- onTapGesture
- onHover
- .if(!isTrashView) { draggable(MemoTransferItem) }
- contextMenu
```

実コード上の事実:

- `StickyNativeApp/HomeView.swift:324-328` で root `HStack` に `.contentShape(Rectangle())`、`.onTapGesture`、`.onHover`、`.if(!isTrashView) { $0.draggable(MemoTransferItem(id: memo.id)) }` が付いている。
- `isTrashView == true` では `.draggable` を付与しない条件分岐は既実装。
- `StickyNativeApp/HomeView.swift:420-428` で `SidebarRowView` に `.dropDestination(for: MemoTransferItem.self)` と `isDropTargeted` 更新は既実装。
- したがって folder drop target の「実装追加」ではなく、まず drag source 成立後に既存 drop target が実機で機能するかを確認する。
- 実装前の `StickyNative.xcodeproj/project.pbxproj` は `GENERATE_INFOPLIST_FILE = YES` の生成 Info.plist 方式。
- 実装前の直近 Debug build の `StickyNative.app/Contents/Info.plist` には `UTExportedTypeDeclarations` が存在しない。
- `MemoTransferItem.swift` は `UTType(exportedAs: "com.stickynative.memo-item")` を定義しているが、生成 Info.plist に exported type declaration がないため、システムが drag payload type を drop target へ正式認識しない可能性がある。

観測結果:

- メモ同士の境界線付近だけから掴める。
- メモ行全体を自然に掴めない。
- folder hover / drop / DB 以前に、drag source の hit testing / gesture 設計が壊れている可能性が高い。
- folder hover highlight が出ない、drop で移動しないという現象は、drag source 不成立だけでなく、UTType 未登録にも起因し得る。drag source 成立と UTType 登録の両方を満たしてから再検証する。

判断:

- `.draggable` の modifier 順や UTType だけを調整する問題ではない。
- 最優先の根本原因候補は、SwiftUI macOS `List` 内で `.onTapGesture` が `.draggable` の drag gesture 認識を阻害していること。
- メモ同士の境界線付近だけ掴める挙動は、`listRowInsets(top: 5, bottom: 5)` の padding 領域など、row content の tap gesture が発火しにくい場所だけ drag gesture が通っている可能性と整合する。
- `MemoRowView` を、主操作領域の `drag surface` とボタン領域の `action surface` に分ける必要はあるが、それだけでは不十分な可能性がある。
- `drag surface` 上で click open と `.draggable` を共存させる方法は、実装前の単独 probe で確定する。

---

## 問題一覧

| ID | 種別 | 内容 |
|----|------|------|
| U-20 | UI / D&D | memo row 全体を掴めず、境界線付近だけ drag source になる |
| U-21 | UI / Gesture | `MemoRowView` root に tap / hover / draggable / contextMenu / button 操作が混在している |
| U-22 | UI / D&D | folder row hover highlight が出ない。drag source 不成立に加え、UTType 未登録が独立原因として存在する |
| U-23 | UI / D&D | folder drop 後に memo が移動しない。drag source 不成立に加え、UTType 未登録が独立原因として存在する |
| U-24 | UI / Gesture | `.onTapGesture` と `.draggable` の共存方法が未確定で、surface 分離だけでは再発する可能性がある |
| A-20 | Architecture | D&D を後付け modifier で足しており、row 操作責務が分離されていない |
| A-21 | Architecture | D&D UI 復旧と persistence hardening が混ざると原因切り分けが崩れる |
| K-20 | Knowledge | 既存 `plan-folder-dnd.md` の `.draggable` 後付け方針が現観測と合わない |
| K-21 | Knowledge | migration SSOT が参照不能なため、暫定 SSOT で進めている |
| K-22 | Knowledge / Config | `com.stickynative.memo-item` の `UTExportedTypeDeclarations` が生成 Info.plist に未登録 |
| P-20 | Persistence | assignment 保存経路には `try?` などの弱さがあるが、今回の drag source 修正とは別問題 |

---

## Issue -> Phase 対応表

| Issue | 解決 Phase |
|-------|------------|
| K-20 | Phase 0 |
| K-21 | Phase 0 |
| K-22 | Phase 4 |
| U-24 | Phase 1 で単独 gesture probe を実施し、click open と drag の共存方法を確定 |
| U-20 | Phase 1 で gesture 原因を切り分け、Phase 2 で row surface 設計を確定、Phase 3 で実装して解消 |
| U-21 | Phase 2 で責務分離設計を確定、Phase 3 で root modifier 混在を解消 |
| U-22 | Phase 5 で UTType 登録後、既存 drop target の hover 動作を確認し、必要時のみ最小修正 |
| U-23 | Phase 5 で UTType 登録後、既存 assignment 経路を確認し、必要時のみ最小修正 |
| A-20 | Phase 2 |
| A-21 | Phase 6 |
| P-20 | 別計画 |

### U-20 / K-22 解決後の確認項目

以下は `SidebarRowView` 側の基礎実装は存在するが、drag source 不成立と UTType 未登録の両方に影響されるため、Phase 5 で確認する。

| 項目 | 現状 | 確認 Phase |
|------|------|------------|
| folder hover highlight | `SidebarRowView.isDropTargeted` と background は既実装。ただし drag source 不成立または UTType 未登録で `isTargeted` が発火しない可能性がある | Phase 5 |
| folder drop assignment | `onDrop -> onAssignFolder -> handleAssignFolder -> coordinator -> FolderStore -> SQLiteStore.updateMemoFolder` は既存経路あり。ただし drag source 不成立または UTType 未登録で drop handler が呼ばれない可能性がある | Phase 5 |
| All Memos / Trash drop target 除外 | `onDrop: nil` により drop target にならない構造が既実装 | Phase 5 |

---

## 実装方針

### 一般的な row D&D 構造

目標構造:

```text
MemoRowView
└─ full-width row container
   ├─ drag surface
   │  ├─ title
   │  ├─ preview
   │  └─ date
   └─ action surface
      ├─ pin Button
      └─ trash / restore Button
```

方針:

- `drag surface` は、title / preview / date を含む主操作面とする。
- `drag surface` に `.draggable` を持たせる。
- click open の実装方法は Phase 1 の gesture probe 結果で確定する。`.onTapGesture` をそのまま併用する前提にしない。
- `action surface` は pin / trash / restore の button 操作だけを持つ。
- button 領域は drag surface に含めない。
- row container は full-width / stable height / stable content shape を持つ。
- Trash view の memo は drag source にしない。

### folder drop

drag source が成立した後にだけ扱う。

- folder row の drop target は `SidebarRowView` に既実装。
- All Memos / Trash は `onDrop: nil` で drop target にならない構造が既実装。
- folder hover は `isDropTargeted` による background highlight が既実装。
- `MemoTransferItem` の `UTType(exportedAs: "com.stickynative.memo-item")` に対応する `UTExportedTypeDeclarations` は Info.plist に未登録。
- 実装検証で、`INFOPLIST_KEY_UTExportedTypeDeclarations` にネストした配列を build setting として追加しても build 後 Info.plist に反映されないことを確認したため、Phase 4 では `StickyNativeApp/Info.plist` を明示追加し、`INFOPLIST_FILE = StickyNativeApp/Info.plist` に切り替える。
- 追加する declaration は `UTTypeIdentifier = com.stickynative.memo-item`、`UTTypeDescription = StickyNative Memo Drag Item`、`UTTypeConformsTo = public.data` とする。
- Phase 5 では、UTType 登録後に既存 drop target / hover / assignment が実機で成立するかを確認する。
- 実機確認で壊れている場合のみ、folder row 側の最小修正を行う。

### persistence

今回の D&D UI 復旧では persistence 経路を変更しない。

既存経路:

```text
HomeView.onAssignFolder
-> HomeWindowController.handleAssignFolder
-> PersistenceCoordinator.assignFolder
-> FolderStore.assignToMemo
-> SQLiteStore.updateMemoFolder
-> viewModel.reload
```

`try?` の error visibility、foreign key enforcement、trashed memo 制約は別計画で扱う。

---

## 修正フェーズ

### Phase 0: 計画確定と旧方針の破棄

主目的: 後付け D&D 方針を破棄し、row surface 分離方針を正式な実装前提にする。

作業:

1. 本計画を作成する。
2. `plan-folder-dnd.md` は編集せず、本計画内で旧 D&D 方針との差分を明記する。
3. 実装修正前に、今回の対象を `HomeView.swift` / `MemoTransferItem.swift` 中心に限定する。

Gate:

- [ ] 旧方針の破棄理由が本計画に反映されている
- [ ] `.draggable` 後付け調整を主方針にしていない
- [ ] `.onTapGesture` と `.draggable` の競合を最優先リスクとして扱っている
- [ ] `plan-folder-dnd.md` を編集せず、本計画内に旧方針との差分を記録している
- [ ] row surface / action surface 分離が主方針になっている
- [ ] persistence hardening を混ぜていない

### Phase 1: click open と drag gesture の単独疎通確認

主目的: `.onTapGesture` / `Button` / gesture priority と `.draggable` が macOS SwiftUI `List` 内で共存できる方法を、本実装前に確認する。

成果物:

- 一時 probe の観測結果
- 採用する click open 実装方式
- probe 由来の差分が残っていない状態

probe 方針:

1. `StickyNativeApp/HomeDragGestureProbeView.swift` を一時追加する。
2. `HomeDragGestureProbeView` は `#if DEBUG` で囲み、Debug build 専用にする。
3. `HomeView` の header または temporary toolbar に `#if DEBUG` 限定の起動ボタンを一時追加し、sheet / popover で probe view を開く。
4. `HomeDragGestureProbeView` 内に `List` 外の drag surface と、`List` 内 row の drag surface を並べて比較する。
5. 以下を段階的に比較する。前段が失敗した場合、次段へ進まず原因を記録する。
   - `.draggable` のみ
   - `.draggable + .onTapGesture`
   - `.draggable + .onTapGesture + action surface`
6. click open 実装候補として以下を同じ条件で比較する。
   - `.onTapGesture + .draggable`
   - `Button` / `.buttonStyle(.plain)` + `.draggable`
   - `.simultaneousGesture(TapGesture()) + .draggable`
   - drag gesture と tap 判定を明示的に分ける実装
7. それぞれで click open 相当の action と drag ghost が両立するか確認する。
8. 結果を本計画または別の probe 結果メモに記録する。
9. `HomeDragGestureProbeView.swift` と `HomeView` の probe 起動 hook を削除する。
10. probe コードは本実装に残さない。

Gate:

- [ ] `List` 内で `.draggable` のみの drag ghost が出る
- [ ] `List` 内で `.draggable + .onTapGesture` の drag ghost 可否が記録されている
- [ ] `List` 内で `.draggable + .onTapGesture + action surface` の drag ghost 可否が記録されている
- [ ] `List` 外で click action と drag ghost の両立可否が記録されている
- [ ] `List` 内で click action と drag ghost の両立可否が記録されている
- [ ] `.onTapGesture + .draggable` の可否が記録されている
- [ ] `Button + .draggable` の可否が記録されている
- [ ] `.simultaneousGesture + .draggable` の可否が記録されている
- [ ] 採用する click open 実装方式が決まっている
- [ ] `StickyNativeApp/HomeDragGestureProbeView.swift` が削除されている
- [ ] `HomeView` の probe 起動 hook が削除されている
- [ ] `rg -n "HomeDragGestureProbe|DND-GESTURE-PROBE" StickyNativeApp` が no match
- [ ] probe 由来の差分が残っていない

### Phase 2: MemoRowView row surface 設計

主目的: Phase 1 の結果を前提に、memo row の drag source を一般的な row 構造に作り替える設計を確定する。

成果物: 設計確認のみ。production code 変更は Phase 3 で行う。

技術詳細:

| 責務 | 配置 |
|------|------|
| row layout container | `MemoRowView.body` |
| drag surface | `MemoRowView` 内の private computed view または private subview |
| action surface | `MemoRowView` 内の private computed view または private subview |
| payload | `MemoTransferItem` |
| click open | Phase 1 で決めた方式 |
| pin / trash / restore | action surface |
| hover state | `MemoRowView` の local `@State` |

設計条件:

- `drag surface` は `.frame(maxWidth: .infinity, alignment: .leading)` を持つ。
- `drag surface` は `.contentShape(Rectangle())` を持つ。
- `drag surface` に `.draggable(MemoTransferItem(id: memo.id))` を付ける。
- click open は Phase 1 で drag と両立確認済みの方式だけを使う。
- `action surface` の button は drag surface の外に置く。
- root に tap / draggable / button を全部混ぜない。
- `isTrashView == true` では `.draggable` を付与しない既存分岐を維持する。

Gate:

- [ ] `drag surface` と `action surface` の責務が明確
- [ ] click open と drag source の両立方式が Phase 1 結果に基づいている
- [ ] button 操作領域が drag source と分離されている
- [ ] Trash view で `.draggable` を付与しない既存構造を維持する方針が明確
- [ ] `.onTapGesture` と `.draggable` の競合を再導入しない設計になっている
- [ ] 変更対象が `HomeView.swift` 中心に閉じている

### Phase 3: MemoRowView 最小実装

主目的: memo row 全体の主操作面を自然に掴める状態にする。

作業:

1. `MemoRowView` を full-width row container に整理する。
2. title / preview / date を `drag surface` に入れる。
3. pin / trash / restore を `action surface` に分離する。
4. 非 Trash view の `drag surface` にのみ `.draggable(MemoTransferItem(id: memo.id))` を付与する。
5. click open は Phase 1 で採用した方式で実装する。
6. 既存 context menu は row container または drag surface に置き、button 操作と競合しないことを確認する。

Gate:

- [ ] build が通る
- [ ] title / preview 領域から drag ghost が出る
- [ ] date 領域から drag ghost が出る
- [ ] click open と drag ghost が同じ主操作面で両立する
- [ ] pin / trash / restore button は click 操作できる
- [ ] button 領域の click が drag source と競合しない
- [ ] memo row click open が維持される
- [ ] Trash view の memo は drag できない

### Phase 4: UTType registration

主目的: `MemoTransferItem` の custom UTType を明示 Info.plist に登録し、drop target が型を認識できる前提を作る。

作業:

1. 実装前の build 設定が `GENERATE_INFOPLIST_FILE = YES` であることを確認する。
2. generated Info.plist build setting では nested `UTExportedTypeDeclarations` が build 後 Info.plist に反映されないことを確認する。
3. `StickyNativeApp/Info.plist` を明示追加し、`StickyNative.xcodeproj/project.pbxproj` を `GENERATE_INFOPLIST_FILE = NO` / `INFOPLIST_FILE = StickyNativeApp/Info.plist` に切り替える。
4. `StickyNativeApp/Info.plist` に `com.stickynative.memo-item` の `UTExportedTypeDeclarations` を追加する。
5. build 後の `StickyNative.app/Contents/Info.plist` に exported type declaration が入ったことを確認する。

追加する declaration:

```text
UTExportedTypeDeclarations:
- UTTypeIdentifier = com.stickynative.memo-item
- UTTypeDescription = StickyNative Memo Drag Item
- UTTypeConformsTo = public.data
```

Gate:

- [ ] build が通る
- [ ] 明示 `StickyNativeApp/Info.plist` 方式へ切り替わっている
- [ ] `StickyNativeApp/Info.plist` に `UTExportedTypeDeclarations` がある
- [ ] build 後の Info.plist に `UTExportedTypeDeclarations` がある
- [ ] build 後の Info.plist に `com.stickynative.memo-item` の exported type declaration がある

### Phase 5: Folder drop target 動作確認・必要時の最小修正

主目的: drag source 成立後、UTType 登録を満たした状態で、既実装の folder row hover / drop / assignment が実機で成立するか確認する。

作業:

1. `SidebarRowView` の既存 `.dropDestination(for: MemoTransferItem.self)` と `isDropTargeted` highlight を確認する。
2. All Memos / Trash が `onDrop: nil` で drop target にならないことを確認する。
3. memo drag 中に folder hover highlight が出るか実機確認する。
4. drop 時に既存 `onAssignFolder(memoID, folder.id)` が呼ばれるか確認する。
5. drop 後に `viewModel.reload()` 経由で list / count が更新されることを確認する。
6. UTType 登録後も既存実装が機能しない場合のみ、folder row 側の最小修正を行う。

Gate:

- [ ] build が通る
- [ ] `SidebarRowView` の drop target が既実装であることを確認済み
- [ ] build 後の Info.plist に `com.stickynative.memo-item` の exported type declaration がある
- [ ] memo drag 中に folder row hover highlight が出る
- [ ] All Memos / Trash が drop target として見えない
- [ ] folder drop 後に memo が対象 folder に移動する
- [ ] folder count / All Memos count が更新される
- [ ] 同一 folder への drop で壊れない

### Phase 6: Persistence hardening 分離

主目的: D&D UI 復旧と DB hardening を混ぜない。

作業:

1. `P-20` は本計画の実装対象外として残す。
2. 必要なら `docs/roadmap/plan-folder-persistence-hardening.md` を別途作る。
3. D&D UI 復旧中に `FolderStore` / `SQLiteStore` の throws 化や FK 変更を混ぜない。

Gate:

- [ ] D&D UI 復旧計画が SwiftUI Home UI の責務に閉じている
- [ ] persistence hardening が別計画として扱われている
- [ ] DB schema 変更がない

---

## 回帰・副作用チェック

| 観点 | 確認方法 |
|------|----------|
| row drag | title / preview / date の主操作面から drag ghost が出る |
| row click | drag surface click で memo window が開く |
| row actions | pin / trash / restore button が click できる |
| Trash | Trash view の memo は drag source にならない |
| folder hover | drag 中に folder row が highlight される |
| folder drop | drop 後に memo が移動し count が更新される |
| UTType | build 後 Info.plist に `UTExportedTypeDeclarations` / `com.stickynative.memo-item` がある |
| All Memos / Trash | drop target として見えない |
| window / focus | SeamlessWindow / focus / first mouse に触っていない |
| persistence | DB schema / assignment 保存経路を変更していない |

---

## 実機確認項目

- [ ] 非 Trash view の title / preview 領域から drag ghost が出る
- [ ] 非 Trash view の date 領域から drag ghost が出る
- [ ] pin button が drag ではなく pin toggle として動作する
- [ ] trash button が drag ではなく trash 操作として動作する
- [ ] memo row click で window が開く
- [ ] build 後 Info.plist に `UTExportedTypeDeclarations` / `com.stickynative.memo-item` がある
- [ ] memo drag 中に folder row hover highlight が出る
- [ ] folder row drop で memo が folder に移動する
- [ ] 移動後に元リストと count が更新される
- [ ] All Memos 行が drop target として見えない
- [ ] Trash 行が drop target として見えない
- [ ] Trash view の memo は drag できない

---

## 技術詳細確認

### ファイルごとの責務

| ファイル | 責務 |
|----------|------|
| `HomeView.swift` | Home UI、memo row drag surface、folder row drop target。Phase 1 probe 起動 hook は一時追加のみ |
| `HomeDragGestureProbeView.swift` | Phase 1 gesture probe 専用の一時ファイル。probe 完了後に削除 |
| `MemoTransferItem.swift` | D&D payload 型 |
| `StickyNativeApp/Info.plist` | UTType declaration の明示登録 |
| `StickyNative.xcodeproj/project.pbxproj` | 明示 `Info.plist` 参照への切り替え |
| build 後 `Info.plist` | `UTExportedTypeDeclarations` の検証対象 |
| `HomeWindowController.swift` | 既存 assignment handler。原則変更しない |
| `PersistenceCoordinator.swift` | 既存 assignment dispatch。原則変更しない |
| `FolderStore.swift` | 既存 folder assignment store。原則変更しない |
| `SQLiteStore.swift` | 既存 `updateMemoFolder`。原則変更しない |

### メモリで持つ情報

- `MemoRowView.isHovered`
- `SidebarRowView.isDropTargeted`
- drag payload の `memo.id`

新規に永続化する情報はない。

### AppKit / SwiftUI 境界

- SwiftUI: Home row D&D、folder hover / drop visual
- AppKit: 変更なし
- Xcode project / Info.plist: D&D payload UTType registration
- SQLite: 変更なし

### イベント経路

```text
memo row drag surface drag
-> MemoTransferItem(id: memo.id)
-> folder row dropDestination
-> HomeView onAssignFolder
-> HomeWindowController.handleAssignFolder
-> PersistenceCoordinator.assignFolder
-> FolderStore.assignToMemo
-> SQLiteStore.updateMemoFolder
-> HomeWindowController.viewModel.reload
```

### Gesture / hit testing 分析

現行の問題候補:

- root `HStack` に `.onTapGesture` と `.draggable` が同時に付いている。
- 最優先の根本原因候補は、`.onTapGesture` が SwiftUI macOS `List` 内の drag gesture 認識を先に消費または阻害していること。
- `.draggable` は `.if(!isTrashView)` wrapper 経由で条件付与されている。
- root `HStack` 内に row trailing の `Button` 群が存在する。
- SwiftUI `List` は macOS 上で row selection / gesture 管理を持つため、row 内 gesture と drag gesture が競合しやすい。
- 実機ではメモ同士の境界線付近だけ掴める。`listRowInsets(top: 5, bottom: 5)` の padding 領域では content 側の tap gesture が発火しにくく、drag gesture が通っている可能性がある。
- したがって、button 分離だけでは不十分で、click open と drag の共存方式を先に確定する必要がある。

本計画で確認すること:

- Phase 1 の `HomeDragGestureProbeView` temporary probe で、`List` 外と `List` 内それぞれの click + drag 共存方法を確認する。
- 最初に `List` 内の `.draggable` のみで drag ghost が出るかを確認する。これが失敗する場合、tap gesture 以前に `List` row と `.draggable` の組み合わせ自体を疑う。
- 次に `.draggable + .onTapGesture`、最後に `.draggable + .onTapGesture + action surface` を確認し、どの段階で壊れるかを記録する。
- `.onTapGesture + .draggable` が drag gesture を阻害する場合、その組み合わせは production の `drag surface` では採用しない。
- `Button + .draggable`、`.simultaneousGesture + .draggable`、tap / drag 判定分離のいずれかから、実機で成立した方式だけを Phase 2 設計に採用する。
- row trailing の `Button` 群は drag surface から分離し、button の click が drag source と競合しないことを確認する。
- modifier 順序だけの調整で済ませず、gesture 疎通確認と surface 分離を両方行う。

### UTType / Info.plist 分析

現行の問題:

- `MemoTransferItem.swift` は `UTType(exportedAs: "com.stickynative.memo-item")` を定義している。
- 実装前の `StickyNative.xcodeproj/project.pbxproj` は `GENERATE_INFOPLIST_FILE = YES` の生成 Info.plist 方式。
- 実装前の直近 Debug build の `StickyNative.app/Contents/Info.plist` には `UTExportedTypeDeclarations` が存在しない。
- generated Info.plist build setting へ nested `UTExportedTypeDeclarations` を追加しても、build 後 Info.plist へ反映されないことを確認済み。
- 旧計画 `docs/roadmap/plan-folder-dnd.md` は、カスタム UTType 未登録を中リスクとして明記していた。

影響:

- system が drag payload type を drop target 側へ正式認識できない場合、`dropDestination(for: MemoTransferItem.self)` の `isTargeted` が発火せず、folder hover highlight が出ない。
- drop handler に item が渡らず、`onDrop?(item.id)` まで到達しない可能性がある。

本計画で確認すること:

- Phase 4 で明示 `StickyNativeApp/Info.plist` に `com.stickynative.memo-item` を登録し、build 後に確認する。
- build 後の app bundle の Info.plist に `UTExportedTypeDeclarations` が入っていることを Gate にする。
- UTType 登録後に hover / drop を実機確認する。

### 状態遷移

- drag 中: `SidebarRowView.isDropTargeted = true`
- drop 成功: assignment 保存後 reload
- Trash view: drag source なし
- All Memos / Trash row: drop target なし

---

## セルフチェック結果

### SSOT 整合

- [x] migration README は参照不能であることを明記した
- [x] 01_product_decision は参照不能であることを明記した
- [x] 02_ux_principles は参照不能であることを明記した
- [x] 06_roadmap は参照不能であることを明記した
- [x] 07_project_bootstrap は参照不能であることを明記した
- [x] 09_seamless_ux_spec は参照不能であることを明記した
- [x] repo 内 product / architecture / roadmap docs を暫定 SSOT として確認した

### 変更範囲

- [x] 主目的は Home memo row D&D 復旧
- [x] 高リスク疎通確認テーマは gesture 共存 probe、row drag source、folder drop を Phase 分離した
- [x] ついで作業を入れていない

### 技術詳細

- [x] ファイルごとの責務が明確
- [x] メモリ管理と persistence の境界が明確
- [x] イベント経路と状態遷移が説明できる

### Window / Focus

- [x] Window 責務に触れない
- [x] Focus 制御に触れない
- [x] first mouse に触れない

### Persistence

- [x] 保存経路は既存経路を使う
- [x] DB schema は変更しない
- [x] persistence hardening は別計画に分離した
- [x] relaunch 時の扱いは対象外。今回の変更は Home 管理 UI の D&D 操作に閉じ、reopen / relaunch 用 persistence は変更しない

### 実機確認

- [ ] row drag ghost を確認する
- [ ] folder hover highlight を確認する
- [ ] folder drop assignment を確認する
