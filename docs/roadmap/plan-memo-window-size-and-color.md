# Memo Window Size And Color Plan

最終更新: 2026-04-15

## SSOT 参照宣言

migration 上位文書（planning guideline §2 必須参照セット）:
- `/Users/hori/Desktop/Sticky/migration/README.md`
- `/Users/hori/Desktop/Sticky/migration/01_product_decision.md`
- `/Users/hori/Desktop/Sticky/migration/02_ux_principles.md`
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
- `docs/architecture/persistence-boundary.md`
- `docs/architecture/technical-decision.md`
- `docs/roadmap/roadmap.md`
- `docs/roadmap/development-roadmap-revalidated.md`
- `docs/roadmap/phase-1-seamless-window-probe-result.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`

本計画は `1 memo = 1 window` と seamless UX を壊さないことを前提にし、window lifecycle と persistence の責務分離を維持する。

## 今回触る関連ファイル

既存:
- `StickyNativeApp/MemoWindowController.swift`
- `StickyNativeApp/MemoWindowView.swift`
- `StickyNativeApp/MemoEditorView.swift`
- `StickyNativeApp/MemoWindow.swift`
- `StickyNativeApp/WindowManager.swift`
- `StickyNativeApp/PersistenceModels.swift`
- `StickyNativeApp/PersistenceCoordinator.swift`
- `StickyNativeApp/SQLiteStore.swift`
- `StickyNativeApp/AppSettings.swift`

新規候補:
- `StickyNativeApp/MemoColorTheme.swift`

文書:
- `docs/roadmap/plan-memo-window-size-and-color.md`
- 必要なら `docs/architecture/domain-model.md`（memo 属性の color 追加を明文化する場合のみ）

## 問題一覧

- `U-09`: memo window の最小サイズが実質 `420x280` に固定されており、狭いサイズへの調整幅が不足している
- `W-03`: memo window のサイズ制約が SwiftUI 側の見た目制約中心で、window core 側の最小サイズ方針が明文化されていない
- `U-10`: memo window に memo 単位の色表現がなく、複数 window を見分ける視覚差が弱い
- `A-05`: 色の責務配置が未定義で、AppKit 側の window chrome と SwiftUI 側の surface のどちらに適用すべきか未整理
- `P-03`: memo ごとの `colorIndex` が永続化されておらず、close/reopen/relaunch で色を保持できない
- `P-04`: 新規 memo 作成時の色ローテーション状態をどこで保持するか未定義
- `K-05`: 将来の管理 UI / 色変更 UI を阻害しない color model の設計境界が未文書化

## 目的

- デフォルトサイズ `440x300` は維持したまま、最小サイズを `320x220` まで下げて調整幅を広げる
- memo window に 5 色ローテーションの色モデルを導入する
- 各 memo 自身の色保持と、新規 memo 作成時の色順継続を分離して設計する
- すりガラス表現と色付けの両立方法を、責務境界込みで着手可能な粒度まで確定する

## スコープ In

- memo window の最小サイズ方針の明文化
- memo window の色モデル定義
- memo 個別 `colorIndex` の永続化
- app 全体の「次に使う色 index」の保持
- `material + tint` の見た目方針
- close / reopen / relaunch 時の色保持仕様

## スコープ Out

- ユーザーが任意に色を切り替える UI
- Home / Settings からの色編集
- session ごとの色ローテーション分岐
- 最大サイズ制約の導入
- pinned 状態に応じた別テーマ適用

## 現状整理

### サイズ

- デフォルトサイズは `440x300`
- 実質の最小サイズは `MemoWindowView` の `minWidth: 420`, `minHeight: 280`
- `NSWindow.minSize` / `maxSize` は明示されていない

### 色・背景

- 背景表現は `material / vibrancy` 系を前提としている
- `window` 自体は透明系の seamless surface を採用している
- memo 単位の theme / tint モデルは未導入

### 永続化

- `origin_x`, `origin_y`, `width`, `height`, `is_pinned`, `is_open` は保存済み
- 色は DB に保存していない
- `AppSettings` は `UserDefaults` を使う既存導線がある

## 技術詳細確認

### 責務配置

#### サイズ制約

- `MemoWindowController.swift`
  - window core の責務として `defaultContentSize` と `minimumContentSize` を持つ
  - `NSWindow.minSize` をここで適用する
- `MemoWindowView.swift`
  - SwiftUI layout 側の `minWidth` / `minHeight` を controller 側と一致させる
  - 見た目制約はここ、window core の制約は controller 側という二層構造にする

理由:
- 最小サイズを SwiftUI だけで持つと resize 挙動の責務が view に寄りすぎる
- ただし editor / header の layout 崩れ防止には SwiftUI 側最小値も必要

#### 色モデル

- `MemoColorTheme.swift`（新規）
  - 5 色パレットと tint 計算ロジックだけを持つ
  - 永続化値は `rawValue: Int` の `0...4` に固定する
  - 不正値は `0`（先頭色）へフォールバックする
  - UI 表示色、border 色、editor tint 色などをここに閉じる
- `MemoWindow.swift`
  - memo の in-memory 属性として `colorTheme` を保持する
- `WindowManager.swift`
  - 新規 memo 作成時の次色決定を担当する
- `PersistenceCoordinator.swift` / `SQLiteStore.swift`
  - memo 個別色の永続化を担当する
- `AppSettings.swift`
  - app 全体の `nextMemoColorIndex` を保持する

理由:
- AppKit / SwiftUI / persistence の境界を跨ぐため、色定義・割当・保存を 1 ファイルに寄せない
- 将来の色変更 UI 追加時も `MemoColorTheme` と persistence を再利用できる

補足:
- in-memory の正は `MemoColorTheme`
- persistence の正は `colorIndex`
- 復元時は `colorIndex -> MemoColorTheme` 変換を 1 箇所に閉じる

### AppKit ↔ SwiftUI 境界

初期実装では「見える色」は SwiftUI 側を正とし、AppKit 側は clear を維持する。

- `NSWindow` レベル:
  - `window.backgroundColor` は clear のまま維持する
  - 色 tint は本適用しない
  - 必要なら shadow / border 補助に限って色を使う
- SwiftUI レベル:
  - `material` をベースにし、その上へ low opacity の tint を重ねる
  - border / header dot / editor background など memo surface の視覚差は SwiftUI 側で担う

採用理由:
- 視覚表現の主戦場は SwiftUI 側に置いた方が調整しやすい
- AppKit と SwiftUI の両方で tint を掛けると、透明領域・外周・material 面で二重着色になるリスクがある
- 既存の seamless surface は `window.backgroundColor = .clear` と SwiftUI `material` の組み合わせで成立しているため、この主従を崩さない

棄却案:
- 色を AppKit 側の `window.backgroundColor` のみで表現する
  - `material` との重なり制御が不明瞭で、UI 部分の調整粒度が粗い
- 色を AppKit と SwiftUI の両方へ同時に本適用する
  - 二重着色と可読性低下のリスクが高く、実装ブレも大きい

### イベント経路

#### 新規 memo 作成時の色決定

`WindowManager.createNewMemoWindow()`
→ `AppSettings` から `nextMemoColorIndex` を読む
→ 次色を決定する
→ `MemoWindow` の in-memory color を確定する
→ 新規 memo window を生成する
→ `AppSettings.nextMemoColorIndex` をその場で次値へ進める
→ memo が初めて永続化されるタイミングで、予約済み `colorIndex` を DB 保存する

ローテーション消費イベント:
- 色ローテーションを消費するイベントは「新規 memo window を作成した瞬間」に固定する
- 色は作成順で予約・確定し、保存順では決めない
- これにより、未保存の window を複数連続で開いても色が重複しない
- empty memo auto-delete された window も色スロットは消費する
- これは「重複のない作成順ローテーション」を優先した設計上のトレードオフとして許容する

保存タイミング:
- 初回の `saveDraft` / `flush` で memo 行を upsert するとき、予約済み `colorIndex` を同時保存する
- `nextMemoColorIndex` は保存時には進めない
- 既存 memo 行への update でも `colorIndex` は保持されるが、ローテーション状態には影響しない
- これにより「色の確定順」と「ローテーション消費順」がどちらも作成順で一致する

#### reopen / restore

`WindowManager.openMemo(id:)`
→ `PersistenceCoordinator.fetchMemo(id:)`
→ `PersistedMemo.colorIndex` を読む
→ `MemoWindow` の in-memory color を復元する
→ `MemoWindowController` / `MemoWindowView` に同一色が渡る

`WindowManager.restorePersistedOpenMemos()`
→ 同じ経路で color を復元する

### 状態遷移管理

#### close

- 色は window close 自体では変化しない
- `frame`, `isOpen`, `draft`, `isPinned` と独立した memo 属性として扱う
- close 時に別途 color を上書きしない

#### reopen

- close 前の DB 上の `colorIndex` を再利用する
- `closedMemoRecords` に色を別保持する必要はない
- reopen は persistence を正として復元する

#### pin / unpin

- pin は `window.level` の責務
- color と pin は独立
- 初期実装では「pinned だから色を変える」は行わない

### Persistence 境界

memo 個別の色:
- `SQLiteStore` の `memos` テーブルに `color_index INTEGER NOT NULL DEFAULT 0` を追加する
- `PersistedMemo` に `colorIndex` を追加する
- `saveDraft` と、`PersistedMemo` を返す全 fetch 経路で色を通す
- 対象は `fetchMemo`, `fetchOpenMemos`, `fetchAllMemos`, `fetchTrashedMemos` に相当する全一覧 / 単体取得
- SQLite migration は `ALTER TABLE memos ADD COLUMN color_index INTEGER NOT NULL DEFAULT 0;` を使う
- migration は app 起動時、`fetchMemo*` より前に完了させる
- 既存 DB の既存行は SQLite の DEFAULT により `0` として読み出せる状態にする
- 追加後の backfill SQL は不要とするが、「列が存在しない状態で decode しない」ことを Gate に含める

app 全体の次に使う色:
- `AppSettings` に `nextMemoColorIndex` を追加する
- `UserDefaults` で保持する

理由:
- memo ごとの属性と app 全体の作成順状態は責務が異なる
- DB に「最後に使った色」を持つと memo persistence と app preference が混線する
- `lastUsed` だと「最後に使った値」か「次に使う値」か解釈が割れるため、`nextMemoColorIndex` に寄せる
- `nextMemoColorIndex` は「次に作られる memo window に割り当てる色」を表す
- したがってこの値は作成時に進み、永続化成否には依存しない

### 後続 Phase との衝突確認

#### Phase 4 管理 UI との衝突

- 現時点では Home / Settings から色変更 UI は持たない
- ただし将来 UI を追加する余地を残すため、色は memo 属性として独立保存する
- `MemoColorTheme` を独立ファイルにすることで、後続 UI からの参照先を固定できる

#### window lifecycle との衝突

- `WindowManager` が色割当の入口になるが、保持の正は DB 側に置く
- これにより lifecycle と persistence の責務分離は維持できる

## 修正フェーズ

### Phase 1: 最小サイズ方針の明文化

目的:
- `U-09`, `W-03` を解消し、最小サイズの責務を window core と SwiftUI layout の両方で一致させる

対象ファイル:
- `StickyNativeApp/MemoWindowController.swift`
- `StickyNativeApp/MemoWindowView.swift`

主目的:
- サイズ制約の明文化のみ

Gate:
- デフォルトサイズが `440x300` のまま維持される
- 最小サイズが `320x220` に統一される
- window を縮めたとき `pin / trash / close / drag handle / editor` が破綻しない

### Phase 2: 色モデルと永続化境界の導入

目的:
- `U-10`, `A-05`, `P-03`, `P-04`, `K-05` を解消し、色の型・保存先・イベント経路を確定する

対象ファイル:
- `StickyNativeApp/MemoColorTheme.swift`（新規）
- `StickyNativeApp/MemoWindow.swift`
- `StickyNativeApp/WindowManager.swift`
- `StickyNativeApp/PersistenceModels.swift`
- `StickyNativeApp/PersistenceCoordinator.swift`
- `StickyNativeApp/SQLiteStore.swift`
- `StickyNativeApp/AppSettings.swift`

主目的:
- 色モデルと persistence の導入のみ

Gate:
- 新規 memo 作成時に 5 色ローテーションの次色が決まる
- ローテーション消費イベントが「window 作成時」に固定される
- 未保存の window を複数連続で開いても色が重複しない
- `nextMemoColorIndex` は window 作成時のみ進み、autosave / flush による保存では進まない
- `colorIndex` が memo persistence を通って復元できる
- migration 後、既存 DB でも `PersistedMemo` を返すすべての fetch 経路が `color_index` 欠落で失敗しない
- app 再起動後も新規 memo の色順が前回の続きになる
- close / reopen / restore で memo 自身の色が保持される

### Phase 3: UI 適用と glass 両立

目的:
- 色モデルを window surface に反映し、material と競合しない表現へ落とす

対象ファイル:
- `StickyNativeApp/MemoWindowController.swift`
- `StickyNativeApp/MemoWindowView.swift`
- `StickyNativeApp/MemoEditorView.swift`

主目的:
- 見た目適用のみ

Gate:
- 色付き window でも material 感が維持される
- 5 色の差が memo 識別に十分見える
- 可読性が落ちない
- pin / close / reopen / autosave など既存挙動に影響しない

## 回帰 / 副作用チェック

- `1 memo = 1 window` の lifecycle を崩さない
- global shortcut 起点の新規 window 作成経路に色追加が割り込んでも focus を壊さない
- empty memo auto-delete と色 persistence が競合しない
- off-screen 補正の `frame` 保存経路と色保存経路を混線させない
- pin は level 管理のみで、色変更の条件にしない
- Home / Settings / Shortcuts window には色仕様を波及させない

## 実機確認項目

1. 新規 memo を 6 個連続で作成し、5 色が順番に回って 6 個目で先頭色に戻ること
   条件: 保存前でも各 window が重複しない色を持つこと
2. 色付き memo を close → reopen しても同じ色で出ること
3. アプリ再起動後に open memo が同じ色で restore されること
4. 再起動後に新規 memo を作ると、前回ローテーションの続き色になること
5. 最小サイズまで縮めても header 操作と本文入力が成立すること
6. glass 感を残したまま色差が視認できること
7. pin ON / OFF で色が変わらず、window level だけが変わること
8. `Cmd+Option+Enter` からの新規 window 作成後も即入力できること

## セルフチェック結果

### SSOT整合
[x] migration README を確認した
[x] 01_product_decision を確認した
[x] 02_ux_principles を確認した
[x] 06_roadmap を確認した
[x] 07_project_bootstrap を確認した
[x] 09_seamless_ux_spec を確認した

### 変更範囲
[x] 主目的は Phase ごとに 1 つ
[x] 高リスク疎通確認テーマは増やしていない
[x] ついで作業を入れていない

### 技術詳細
[x] ファイルごとの責務を明記した
[x] メモリ管理と persistence の境界を明記した
[x] イベント経路と状態遷移を記載した

### Window / Focus
[x] Window 責務を `MemoWindowController` / `WindowManager` に限定した
[x] Focus 制御を今回の色計画に混入させていない
[x] first mouse / shortcut 既存前提を壊さない方針を記載した

### Persistence
[x] memo 個別色と app 全体色順の保存先を分離した
[x] close / reopen / relaunch の復元経路を明記した
[x] frame 保存経路と色保存経路を混線させない方針を記載した

### 実機確認
[x] ローテーション確認項目を定義した
[x] reopen / relaunch の確認項目を定義した
[x] 最小サイズと glass 可読性の確認項目を定義した

## 変更履歴

- 2026-04-15: 初版作成
- 2026-04-15: レビュー指摘を反映し、SSOT 参照、問題一覧、技術詳細確認、フェーズ/Gate、セルフチェックを追加して全面改訂
