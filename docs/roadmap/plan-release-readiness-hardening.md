# Release Readiness Hardening Plan

作成: 2026-04-22  
ステータス: 計画中（実装未着手）

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-22 | 初版作成。ほぼ完成状態を前提に、新機能追加ではなく配布前仕上げ・回帰確認・成果物整理へスコープを固定 |

---

## SSOT参照宣言

本計画は `docs/roadmap/stickynative-ai-planning-guidelines.md` に従う。

### migration 上位文書の確認結果

planning guideline では `/Users/hori/Desktop/Sticky/migration/*` を必須 SSOT として参照するよう定義されているが、2026-04-22 時点の作業環境では `/Users/hori/Desktop/Sticky/migration` が存在しない。

したがって、本計画では repo 内のローカル補助文書と現行実装を暫定 SSOT とする。migration 文書が復旧した場合は、実装前または次回計画更新時に再照合する。

### StickyNative ローカル補助文書

- `docs/roadmap/stickynative-ai-planning-guidelines.md`
- `docs/product/product-vision.md`
- `docs/product/ux-principles.md`
- `docs/product/mvp-scope.md`
- `docs/product/current-feature-summary.md`
- `docs/architecture/technical-decision.md`
- `docs/architecture/domain-model.md`
- `docs/architecture/persistence-boundary.md`
- `docs/roadmap/roadmap.md`
- `docs/roadmap/development-roadmap-revalidated.md`
- `docs/roadmap/phase-6-polish-plan.md`
- `LOCAL_RETROSPECTIVE.md`

### SSOT整合メモ

- `product-vision.md`: 主体験は `Cmd+Option+Enter -> すぐ書く -> 元作業に戻る -> 1 click で再編集`。配布前仕上げではこの体験を変えない。
- `ux-principles.md`: 「速い」「自然」「可逆」「軽い」「明快」を優先する。説明 UI や hover bubble などの新規 affordance は本計画に入れない。
- `technical-decision.md`: App lifecycle / menu bar / shortcut / window は AppKit、UI は SwiftUI、persistence は SQLite。仕上げ作業でも責務境界を動かさない。
- `phase-6-polish-plan.md`: Phase 6 は日常利用レベルの edge case を詰める段階。本計画は Phase 6 の最終仕上げとして扱う。
- `LOCAL_RETROSPECTIVE.md`: 配布物、署名、notarization、古い `.app` 混在の反省がある。本計画では成果物整理と検証 Gate を明文化する。

---

## 目的

StickyNative は機能面ではほぼ完成と判断し、新規機能追加ではなく以下を行う。

- 開発用ログや古い配布物による判断ノイズを減らす
- version / build / release candidate の扱いを固定する
- 実機回帰確認を Gate 化し、完成済み体験を壊していないことを確認する
- 保存・整理系の失敗が完全に無音にならない最低限の error visibility を検討する

---

## スコープ In

- 開発用 window lifecycle `NSLog` の削除
- version / build number の運用方針確認
- 古い `.app` / zip / 配布候補の扱い整理
- release candidate の実機確認チェックリスト固定
- `try?` による persistence / folder 操作失敗の最低限の可視化方針策定と必要最小実装
- 既存 Smart Links の回帰確認

## スコープ Out

- Smart Links hover bubble / tooltip / popover の追加
- Home memo row D&D の修正
- window と他アプリ window の layer 連携
- 大規模な persistence error handling 再設計
- cloud sync / export / import
- UI の大幅 redesign
- keyboard shortcut 変更
- DB schema 変更

---

## 今回触る関連ファイル

### 確認対象

| ファイル | 扱い |
|----------|------|
| `StickyNative.xcodeproj/project.pbxproj` | `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` の確認。原則変更しないが、配布直前に必要なら build number だけ更新 |
| `StickyNativeApp/Info.plist` | version key の参照確認。原則変更しない |
| `StickyNativeApp/SeamlessWindow.swift` | 開発用 `NSLog` 削除候補 |
| `StickyNativeApp/MemoWindowController.swift` | 開発用 `NSLog` 削除候補 |
| `StickyNativeApp/PersistenceCoordinator.swift` | `try?` による保存失敗の可視化候補 |
| `StickyNativeApp/FolderStore.swift` | folder 操作失敗の可視化候補 |
| `StickyNativeApp/SQLiteStore.swift` | SQLite error source。大改修しない |
| `StickyNativeApp/CheckableTextView.swift` | Smart Links / first mouse / IME 回帰確認対象。原則変更しない |
| `LOCAL_RETROSPECTIVE.md` | 配布確認観点の参照。必要なら追記 |
| `docs/product/current-feature-summary.md` | 実機確認後に現機能 summary を更新する場合のみ |

### 作成・更新対象

| ファイル | 扱い |
|----------|------|
| `docs/roadmap/plan-release-readiness-hardening.md` | 本計画書 |

---

## 問題一覧

| ID | 分類 | 内容 |
|----|------|------|
| `K-40` | Knowledge | ほぼ完成状態に対して、次に何を足すべきか / 足さないべきかの判断基準が未固定 |
| `K-41` | Knowledge | migration SSOT が現環境で unavailable のため、ローカル文書を暫定 SSOT とする条件を明記する必要がある |
| `K-42` | Knowledge | version / build number / release candidate app の扱いが配布前 Gate として固定されていない |
| `K-43` | Knowledge | 既存 repo 内に古い `.app` が複数あり、検証対象と配布対象を取り違えるリスクがある |
| `U-40` | UI | 開発用 `NSLog` が配布物に残ると、完成状態の polish として粗く見える |
| `P-40` | Persistence | `PersistenceCoordinator` / `FolderStore` の write 系 `try?` が保存・整理操作の失敗を無音化している |
| `P-41` | Persistence | `fetchAllMemos()` / `fetchTrashedMemos()` / `fetchOpenMemos()` / `fetchAllFolders()` の read 系失敗が空配列へ落ち、Home / Trash / relaunch reopen が「データなし」に見えるリスクがある |
| `W-40` | Window | 配布前に window lifecycle / focus / first mouse の最終回帰 Gate がまとまっていない |
| `A-40` | Architecture | 仕上げ作業に新規 UX や D&D 修正を混ぜると、完成済み体験を崩す可能性がある |

---

## Issue -> Phase 対応

| Issue | Phase | 対応内容 |
|-------|-------|----------|
| `K-40` | Phase 0 | 本計画で「足すより固める」方針を固定 |
| `K-41` | Phase 0 | migration unavailable と暫定 SSOT を明記 |
| `K-42` | Phase 1 | version / build / release candidate 命名と確認方法を固定 |
| `K-43` | Phase 1 / Phase 5 | 検証対象 app を1つに固定し、古い配布物との混同を避ける |
| `U-40` | Phase 2 | 開発用 window lifecycle `NSLog` を削除 |
| `P-40` | Phase 3 | persistence / folder write 操作の失敗可視化を最小限で設計・実装 |
| `P-41` | Phase 3 / Phase 4 | read/fetch 失敗時に空状態へ見えるリスクを error log と実機 Gate で扱う |
| `W-40` | Phase 4 | window / focus / first mouse / Smart Links の実機回帰 Gate を実施 |
| `A-40` | Phase 0 / Phase 5 | スコープ外を明記し、実装後も新規 UX を混ぜていないことを確認 |

---

## 技術詳細確認

### 責務配置

`SeamlessWindow.swift`:

- window focus / key / orderFront の挙動を持つ。
- 配布前仕上げでは挙動変更をしない。
- 開発用 window lifecycle log だけを削除する。

`MemoWindowController.swift`:

- memo window lifecycle、focus request、pin level、close 時 flush を管理する。
- 配布前仕上げでは `showAndFocusEditor`, `applyPinState`, `windowWillClose` の挙動を変えない。
- 開発用 window lifecycle log だけを削除する。

`PersistenceCoordinator.swift`:

- UI / WindowManager から SQLiteStore への保存境界。
- 現状は `try?` で多くの失敗を握りつぶす。
- write 系だけでなく read/fetch 系も確認対象に含める。特に `fetchAllMemos()` / `fetchTrashedMemos()` / `fetchOpenMemos()` は失敗時に空配列へ落ちるため、Home / Trash / relaunch reopen が「データなし」に見えるリスクがある。
- `fetchDraft(id:)` / `fetchMemo(id:)` も失敗時に `nil` へ落ちるため、対象 memo が存在しない場合と DB read failure を区別できない。
- Phase 3 では全 API の throws 化はしない。まず `Logger` または small helper による lightweight error visibility に留める。
- Phase 3 の persistence error logging は Phase 2 の window lifecycle log cleanup 対象に含めない。

`FolderStore.swift`:

- Home / folder UI の小さな persistence wrapper。
- folder 操作失敗の無音化を最小限に改善する。
- `fetchAll()` は失敗時に空配列へ落ちるため、folder が本当にない状態と folder read failure を区別できない。
- Home UI の redesign や folder D&D 修正はしない。

`CheckableTextView.swift`:

- AppKit text editing、first mouse、Smart Links、context menu の責務を持つ。
- 本計画では hover bubble を追加しない。
- Phase 4 の実機確認対象にするだけとし、問題が出た場合は別計画化する。

### メモリで持つ情報 / 持たない情報

持つ情報:

- release candidate の検証対象 path / version / build number
- 実機確認結果
- 最低限の persistence error log

持たない情報:

- hover hint の表示状態
- D&D gesture probe state
- 他アプリ window との layer 連携 state
- 新しい DB schema / migration state

### AppKit / SwiftUI 境界

- AppKit: window lifecycle、menu bar、global shortcut、`NSTextView` event、release candidate app の runtime 挙動確認
- SwiftUI: Memo / Home / Settings の既存 UI 表示。配布前仕上げでは UI 構造を変えない
- SQLite: 現行 schema と保存経路を維持する。Phase 3 でも schema 変更なし

### ユーザー操作イベント経路

実機 Gate で確認する主経路:

- New memo: `HotkeyManager` / menu bar -> `WindowManager.createNewMemoWindow()` -> `MemoWindowController.showAndFocusEditor()` -> `CheckableTextView` focus
- Close / reopen: `MemoWindowView` button or shortcut -> `MemoWindowController.windowWillClose` -> `WindowManager.handleWindowClose` -> `WindowManager.reopenLastClosedMemo`
- Pin: `MemoWindowView` -> `MemoWindowController.pinWindow` -> `window.level`
- Save: `MemoWindowView` shortcut -> `MemoWindowController.onFlush` -> `AutosaveScheduler.flush` -> `PersistenceCoordinator.saveDraft`
- Smart Link open: `CheckboxNSTextView.mouseDown` -> `openSmartLinkIfNeeded` -> `NSWorkspace.shared.open`
- Context menu link: `CheckboxNSTextView.menu(for:)` -> `openSmartLink` / `copySmartLink`

### close / reopen / pin / drag 状態遷移

- close / reopen / pin / drag の状態管理は既存の `WindowManager` + `MemoWindowController` に維持する。
- 配布前仕上げでは状態遷移の設計変更を行わない。
- 実機 Gate で複数 window、pin ON/OFF、close/reopen、relaunch 復元を確認する。

### 後続 Phase との衝突

- `plan-dnd-row-rebuild.md`: Home row D&D は未解決リスクだが、本計画では扱わない。D&D を配布価値として出す場合のみ別途実施する。
- `plan-smart-links.md`: Smart Links は実装済みだが、hover hint は追加しない。発見性は右クリック menu と `Command-click` で許容する。
- `plan-editor-scroll-layout-stability.md`: editor layout に問題が出た場合は別計画で扱う。本計画で layout を触らない。
- `plan-standard-window-resize-ux.md`: window chrome / resize の大きな変更は本計画外。

---

## 修正フェーズ

### Phase 0: Scope Freeze

主目的: 「ほぼ完成」状態を前提に、配布前仕上げへスコープを固定する。

作業:

1. 本計画を作成する。
2. hover bubble、D&D、layer 連携、新規 UX をスコープ外として固定する。
3. migration SSOT unavailable の扱いを明記する。

Gate:

- [ ] 本計画に SSOT 参照宣言がある
- [ ] migration unavailable の扱いが明記されている
- [ ] 新規 UX を混ぜない方針が明記されている
- [ ] Issue -> Phase 対応が MECE になっている

### Phase 1: Version / Artifact Gate

主目的: 検証対象と配布対象の取り違えを防ぐ。

前提:

- source project の現確認値は `MARKETING_VERSION = 1.1.0`、`CURRENT_PROJECT_VERSION = 11`。
- `StickyNativeApp/Info.plist` は `CFBundleShortVersionString = $(MARKETING_VERSION)`、`CFBundleVersion = $(CURRENT_PROJECT_VERSION)` を参照する。
- repo 直下の `配布用.app` / `配布用 2.app` / `StickyNative_sandbox.app` は古い検証物として扱い、release candidate の source of truth にしない。

release candidate 命名:

- RC app path: `/tmp/stickynative_release_check/StickyNative.app`
- RC zip path: `/tmp/stickynative_release_check/StickyNative-<MARKETING_VERSION>-build-<CURRENT_PROJECT_VERSION>.zip`
- 例: `/tmp/stickynative_release_check/StickyNative-1.1.0-build-11.zip`
- repo 内に生成済みの古い `.app` は削除対象ではなく、単に検証対象外とする。

前配布 build の source of truth:

1. GitHub Release / 配布 zip が存在する場合は、直近配布 zip 内の `StickyNative.app/Contents/Info.plist` を正とする。
2. GitHub Release / 配布 zip が存在しない場合は、`LOCAL_RETROSPECTIVE.md` またはリリース作業メモに記録された直近配布 version / build を参照する。
3. どちらもない場合は「前配布 build 不明」と記録し、今回の `CURRENT_PROJECT_VERSION` を新しい release baseline とする。ただし、今後の比較のため Phase 5 で version / build / zip path を必ず記録する。

作業:

1. `MARKETING_VERSION` と `CURRENT_PROJECT_VERSION` を確認する。
2. 前配布 build の source of truth を特定する。不明な場合は「前配布 build 不明」と記録する。
3. release candidate を `/tmp/stickynative_release_check/StickyNative.app` に固定する。
4. 古い `配布用.app` / `配布用 2.app` / `StickyNative_sandbox.app` を検証対象にしないことを明記する。
5. RC app の `Info.plist` から `CFBundleShortVersionString` / `CFBundleVersion` を確認する。
6. 必要な場合のみ build number を increment する。

Gate:

- [ ] source project の `MARKETING_VERSION` が `major.minor.patch` 形式
- [ ] 前配布 build の source of truth が記録されている、または「前配布 build 不明」と記録されている
- [ ] 前配布 build が判明している場合、source project の `CURRENT_PROJECT_VERSION` が前配布より増えている
- [ ] 検証対象 app path が `/tmp/stickynative_release_check/StickyNative.app` に決まっている
- [ ] 検証対象 app の `CFBundleShortVersionString` / `CFBundleVersion` を確認済み
- [ ] 古い repo 内 `.app` を release candidate と混同していない

### Phase 2: Debug Log Cleanup

主目的: 配布物から開発用 window lifecycle log を除く。

作業:

1. `SeamlessWindow.swift` の window lifecycle `NSLog` を削除する。
2. `MemoWindowController.swift` の `windowDidBecomeKey` / `windowDidBecomeMain` log を削除する。
3. window behavior は変更しない。
4. build する。

Gate:

- [ ] `rg -n "NSLog\\(" StickyNativeApp/SeamlessWindow.swift StickyNativeApp/MemoWindowController.swift` で配布不要な window lifecycle log が残っていない
- [ ] Phase 2 の log cleanup は window lifecycle log に限定され、Phase 3 の persistence error logging 方針と衝突していない
- [ ] `SeamlessWindow` の `canBecomeKey` / `canBecomeMain` は維持されている
- [ ] `showAndFocusEditor()` の挙動を変更していない
- [ ] build が通る

### Phase 3: Minimal Persistence Error Visibility

主目的: 保存・整理操作および read/fetch の失敗が完全に無音にならない状態にする。

作業:

1. `PersistenceCoordinator` の `try?` を棚卸しする。
2. `FolderStore` の `try?` を棚卸しする。
3. write 系と read/fetch 系を分けて失敗時の見え方を定義する。
4. ユーザーに即時 alert を出すべき操作と、debug/error log で足りる操作を分ける。
5. 大改修せず、最低限の logging か small helper に留める。
6. DB schema は変更しない。

推奨方針:

- autosave / manual save / trash / restore / permanent delete は失敗時 `Logger` または small helper 経由で error visibility を出す。
- folder create / rename / delete / assign は失敗時 `Logger` または small helper 経由で error visibility を出す。
- `fetchAllMemos()` / `fetchTrashedMemos()` は失敗時 `Logger` または small helper 経由で error visibility を出した上で空配列 fallback を維持する。UI alert は出さない。
- `fetchOpenMemos()` は relaunch reopen に直結するため、失敗時 visibility を必須とする。空配列 fallback を維持する場合でも「open memo なし」と区別できる message にする。
- `fetchAllFolders()` は失敗時 `Logger` または small helper 経由で error visibility を出した上で空配列 fallback を維持する。
- `fetchMemo(id:)` / `fetchDraft(id:)` は失敗時 `Logger` または small helper 経由で error visibility を出し、`nil` fallback を維持する。存在なしと read failure の区別は log で行う。
- UI alert は入れない。頻繁な autosave と競合し、軽さを壊すため。
- throws を UI まで伝播する大改修は別計画にする。

Gate:

- [ ] `PersistenceCoordinator` / `FolderStore` の失敗可視化方針が実装に反映されている
- [ ] write 系失敗が完全に無音化されていない
- [ ] read/fetch 系失敗が完全に無音化されていない
- [ ] read/fetch fallback が「空データ」と混同され得る箇所に log 方針がある
- [ ] DB schema 変更がない
- [ ] autosave 経路が `memo.draft -> AutosaveScheduler -> PersistenceCoordinator -> SQLiteStore` のまま
- [ ] Home / Trash / Session UI の構造を変更していない
- [ ] build が通る

### Phase 4: Release Candidate Regression Gate

主目的: 完成済み体験が壊れていないことを実機で確認する。

作業:

1. release candidate app を1つだけ決めて起動する。
2. 実機確認項目を順に実施する。
3. 失敗した項目は本計画内で無理に直さず、原因がスコープ内か外かを判断する。
4. スコープ外の問題は別計画に切り出す。

Gate:

- [ ] global shortcut 後にゼロクリック入力できる
- [ ] 非アクティブ状態から 1 click で editor 操作できる
- [ ] close / reopen / relaunch で draft と frame が復元される
- [ ] pin ON/OFF が window level として動く
- [ ] IME 入力が正常
- [ ] Smart Links の通常 click / Command-click / context menu が期待通り
- [ ] Home search / Trash / restore / empty trash が期待通り
- [ ] 複数 memo window で focus / close / reopen が混線しない

### Phase 5: Release Notes / Final Scope Confirmation

主目的: 配布前に「何を入れたか / 入れなかったか」を固定する。

作業:

1. 必要なら `docs/product/current-feature-summary.md` を現状に合わせて更新する。
2. hover bubble、D&D、layer 連携は次回以降または対象外として明記する。
3. release candidate の version / build / app path / 実機確認結果を記録する。
4. 配布方式が Developer ID 直配布か App Store かを別メモで確認する。

Gate:

- [ ] release candidate の version / build / app path が記録されている
- [ ] 実機確認結果が記録されている
- [ ] スコープ外項目が混ざっていない
- [ ] 配布対象と検証対象が一致している

---

## Gate条件

- [ ] Phase 0 の scope freeze が完了している
- [ ] Phase 1 で検証対象 app が1つに固定されている
- [ ] Phase 2 で不要な開発用 log が残っていない
- [ ] Phase 3 で persistence write 失敗の最低限の visibility がある
- [ ] Phase 3 で persistence read/fetch 失敗の最低限の visibility がある
- [ ] Phase 4 の実機回帰確認が完了している
- [ ] Phase 5 で release candidate 情報が記録されている
- [ ] 新規 UX / D&D / layer 連携を混ぜていない

---

## 回帰 / 副作用チェック

| 観点 | 懸念 | 対策 |
|------|------|------|
| window focus | log cleanup で誤って focus lifecycle を変える | `NSLog` 以外の window method body を変更しない |
| first mouse | editor / hosting view の入力感が変わる | `CheckableTextView` / `SeamlessHostingView` は原則変更しない |
| persistence write | error visibility 追加で autosave が重くなる | alert を入れず、軽量 log に留める |
| persistence read | fetch 失敗が空状態に見えてデータ消失と誤認する | read/fetch fallback 時に error log を残す |
| log checks | Phase 2 の `NSLog` 検査が Phase 3 の persistence error logging を false positive にする | Phase 2 の検査対象を `SeamlessWindow.swift` / `MemoWindowController.swift` の window lifecycle log に限定する |
| release artifact | 古い `.app` を検証してしまう | Phase 1 で app path を1つに固定 |
| Smart Links | hover hint 追加で editor 操作が重くなる | hover hint は本計画のスコープ外 |
| D&D | 未解決の folder D&D に引きずられる | D&D は別計画扱い |
| version | source と app bundle の version がズレる | build 後 app bundle の Info.plist を確認 |

---

## 実機確認項目

### Core

- [ ] app 起動後、menu bar icon が表示される
- [ ] `Cmd+Option+Enter` で新規 memo が出る
- [ ] 新規 memo 表示直後にゼロクリック入力できる
- [ ] 別アプリ前面から既存 memo を 1 click して入力できる
- [ ] 複数 memo window を同時に開ける

### Window

- [ ] memo window を drag できる
- [ ] memo window を resize できる
- [ ] pin ON で他 window より前に留まる
- [ ] pin OFF で通常 window level に戻る
- [ ] close 後、Reopen Last Closed Memo で戻る
- [ ] app relaunch 後、open memo が復元される

### Editor

- [ ] 日本語 IME の入力・変換・確定が正常
- [ ] `Cmd+S` で保存できる
- [ ] `Cmd+Enter` で保存して close できる
- [ ] `Cmd+W` で close できる
- [ ] `Cmd+L` で checkbox toggle できる
- [ ] checkbox 文字 click で toggle できる
- [ ] `Cmd+D` で日付を挿入できる
- [ ] `Cmd+Shift+D` で日時を挿入できる
- [ ] cut / copy / paste / select all が context menu で動く

### Smart Links

- [ ] URL 入力直後に link 表示される
- [ ] URL 上の通常 click は cursor placement / selection として動く
- [ ] URL 上の `Command-click` で default browser が開く
- [ ] URL 上の右 click menu に `リンクを開く` / `リンクをコピー` が出る
- [ ] `リンクをコピー` で pasteboard に URL が入る
- [ ] close / reopen / relaunch 後も URL が link 表示される

### Management

- [ ] All Memos window が開く
- [ ] search で memo が見つかる
- [ ] memo row click で対象 memo window が開く / focus する
- [ ] memo を Trash へ移動できる
- [ ] Trash から restore できる
- [ ] Empty Trash が動く
- [ ] Settings から font size / memo size / memo color mode を変更できる

### Release Candidate

- [ ] 前配布 build の source of truth が記録されている、または「前配布 build 不明」と記録されている
- [ ] 検証対象 app path が `/tmp/stickynative_release_check/StickyNative.app`
- [ ] 検証対象 app の `CFBundleShortVersionString` が期待値
- [ ] 検証対象 app の `CFBundleVersion` が期待値
- [ ] 検証対象 zip path が `/tmp/stickynative_release_check/StickyNative-<MARKETING_VERSION>-build-<CURRENT_PROJECT_VERSION>.zip`
- [ ] codesign / notarization を行う場合、対象 app と配布 zip が一致している

---

## セルフチェック結果

### SSOT整合

[x] migration README は参照不能であることを確認した  
[x] 01_product_decision は参照不能であることを確認した  
[x] 02_ux_principles は参照不能であることを確認した  
[x] 06_roadmap は参照不能であることを確認した  
[x] 07_project_bootstrap は参照不能であることを確認した  
[x] 09_seamless_ux_spec は参照不能であることを確認した  
[x] repo 内 product / architecture / roadmap 文書を暫定 SSOT として確認した  

### 変更範囲

[x] 主目的は release readiness hardening の1つ  
[x] 高リスク疎通確認テーマは release candidate regression gate に分離した  
[x] ついで作業を入れていない  

### 技術詳細

[x] ファイルごとの責務が明確  
[x] メモリ管理と persistence の境界が明確  
[x] イベント経路と状態遷移が説明できる  

### Window / Focus

[x] Window 責務が `WindowManager` / `MemoWindowController` に維持されている  
[x] Focus 制御が UI と AppKit で競合しない計画になっている  
[x] first mouse の扱いが実機 Gate に含まれている  

### Persistence

[x] 保存経路は一本化されたまま  
[x] frame と open 状態の責務が明確  
[x] relaunch 時の扱いが実機 Gate に含まれている  

### 実機確認

[x] global shortcut を確認対象に含めた  
[x] 1 click 操作を確認対象に含めた  
[x] ゼロクリック入力を確認対象に含めた  
