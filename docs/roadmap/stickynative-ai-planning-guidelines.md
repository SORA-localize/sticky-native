# StickyNative AI Planning Guidelines

最終更新: 2026-04-12

## 1. 目的

この文書は、`StickyNative` の AI 主導開発において、短絡的実装、window 基盤の継ぎ足し、UX 仕様逸脱、再利用不能な実験コードの混入を防ぐための計画・レビュー用ガイドラインを定める。

本プロダクトでは `menu bar`, `global shortcut`, `window lifecycle`, `acceptsFirstMouse`, `focus`, `local persistence` が密接に絡むため、思いつきで UI を先に作る進め方を禁止する。

## 2. 必ず参照する SSOT

計画・実装・レビュー時は、以下を上位文書として扱う。

- `/Users/hori/Desktop/Sticky/migration/README.md`
- `/Users/hori/Desktop/Sticky/migration/01_product_decision.md`
- `/Users/hori/Desktop/Sticky/migration/02_ux_principles.md`
- `/Users/hori/Desktop/Sticky/migration/04_technical_decision.md`
- `/Users/hori/Desktop/Sticky/migration/06_roadmap.md`
- `/Users/hori/Desktop/Sticky/migration/07_project_bootstrap.md`
- `/Users/hori/Desktop/Sticky/migration/08_human_checklist.md`
- `/Users/hori/Desktop/Sticky/migration/09_seamless_ux_spec.md`

StickyNative ローカル文書として、以下を作業中の SSOT 補助とする。

- `docs/product/product-vision.md`
- `docs/product/ux-principles.md`
- `docs/product/mvp-scope.md`
- `docs/architecture/technical-decision.md`
- `docs/roadmap/roadmap.md`

ルール:

- 仕様判断に迷ったら、会話ではなく文書を確認する
- 文書と実装がズレる場合は、先に文書を更新する
- 会話中の合意より、更新済み文書を優先する

## 3. StickyNative の開発原則

- 最優先は `シームレスUX` と `思考の初速`
- Phase 1 では `1 memo = 1 window` を崩さない
- seamless UX は polish ではなく基盤要件として扱う
- UI の見た目より、window 挙動と focus 挙動を優先する
- SwiftUI 単独で無理に閉じず、必要な責務は AppKit に置く
- 高機能化より `すぐ出る / すぐ書ける / 1 click で触れる / すぐ戻れる` を優先する
- 旧プロジェクトのコードはコピー起点にしない

## 4. Do / Don't

### Do

- 実装前に上位 SSOT を確認する
- 変更は `最小単位` で入れる
- high risk 領域は疎通確認フェーズを分ける
- `Window`, `View`, `Shortcut`, `Persistence` の責務分離を維持する
- 実装後は `build` と必要な実機確認を行う
- 文書間の不整合を見つけたら先に是正する

### Don't

- UI だけを先に作り込まない
- 標準 macOS 挙動から逸脱しつつ、理由を文書化しない
- `acceptsFirstMouse` や focus を後付けで継ぎ足す前提にしない
- window frame と persistence を UI イベントごとに二重管理しない
- 一つのフェーズで複数の主目的を持ち込まない
- プローブコードを本実装に残さない

## 5. StickyNative 特有の高リスク領域

1. `Seamless Window`
- 非アクティブ状態からの 1 click 操作
- `canBecomeKey` / `canBecomeMain`
- titlebar / drag / background material の整合

2. `Global Shortcut`
- `Cmd+Option+Enter` の安定動作
- 権限や環境差での破綻

3. `Focus Model`
- 呼び出し直後のゼロクリック入力
- reopen 時の focus 復帰

4. `Window Lifecycle`
- create / focus / pin / close / reopen
- 複数 window 時の整合

5. `Local Persistence`
- draft 保持
- frame 保存
- app relaunch 後の reopen

## 6. 計画書の必須構成

AI に計画を作らせる場合、最低限以下を含める。

1. `SSOT参照宣言`
2. `今回触る関連ファイル`
3. `問題一覧`
4. `修正フェーズ`
5. `Gate条件`
6. `回帰/副作用チェック`
7. `変更履歴`
8. `実機確認項目`
9. `技術詳細確認`

### 技術詳細確認で必ず書くこと

計画書は要件整理だけで終わらせず、実装前に以下の技術詳細を確認する。

- どの責務をどのファイル / クラス / View に置くか
- どの情報をメモリで持ち、どの情報をまだ持たないか
- AppKit と SwiftUI の責務境界をどう切るか
- ユーザー操作がどのイベント経路を通るか
- close / reopen / pin / drag の状態遷移をどこで管理するか
- 後続 Phase の persistence や管理 UI と衝突しないか

ルール:

- 高リスク領域では、フェーズ計画に技術詳細の節を作る
- 実装者が「どのファイルに何を書くか」を迷う状態で着手しない
- 技術詳細が未確定なら、実装ではなく先に文書を更新する

## 7. 問題一覧の ID 体系

- `A-`: Architecture / 基盤・責務
- `W-`: Window / window lifecycle と挙動
- `F-`: Focus / first mouse / key focus
- `U-`: UI / visual / interaction
- `P-`: Persistence / 保存・reopen
- `K-`: Knowledge / 文書・仕様整合

例:

- `W-01: SeamlessWindow の責務境界が未定義`
- `F-02: global shortcut 後の editor focus が未検証`
- `P-01: relaunch 後の draft 回収ルールが未確定`

## 8. MECE 検査

### 検査A: Issue → Phase 対応

- すべての Issue に対応する Phase がある
- すべての Phase に対応する Issue がある

### 検査B: SSOT 整合

- `01`, `02`, `06`, `07`, `09` と矛盾していない
- 矛盾がある場合は、先に文書側へ差分理由を反映している

### 検査C: DRY / KISS

- window 制御が複数箇所に分散していない
- focus 制御が UI と AppKit の両方で競合していない
- persistence の保存経路が一本化されている

## 9. フェーズ管理の閾値

### 1 フェーズの上限

- 主目的: `1つ`
- 高リスク疎通確認: `1テーマ`
- 新規ファイル: 原則 `2` 以内
- 触る責務: 原則 `1レイヤ` のみ

### 逸脱時

- 閾値を超える場合は先に計画を分割する
- 「ついでにやる」を禁止する

## 10. 疎通確認の扱い

以下は本実装前に単独で疎通確認する。

- `SeamlessWindow`
- `SeamlessHostingView`
- `acceptsFirstMouse`
- `global shortcut`
- `@FocusState`
- SQLite 保存

ルール:

- 疎通確認は本実装と混ぜない
- プローブは後で削除または置換する
- 結果を文書に残す
- 疎通未通過なら次フェーズへ進まない

## 11. レビュー観点

- seamless UX の核を壊していないか
- AppKit と SwiftUI の責務境界が曖昧になっていないか
- 一般的 macOS 挙動からの逸脱に理由があるか
- 後続フェーズの Home / Trash / Session を阻害していないか
- 0 から作り直した意味を失う継ぎ足し設計になっていないか
- 技術詳細確認が不足したまま「雰囲気で実装」できる計画になっていないか

## 12. 提出前セルフチェック

```md
## セルフチェック結果

### SSOT整合
[ ] migration README を確認した
[ ] 01_product_decision を確認した
[ ] 02_ux_principles を確認した
[ ] 06_roadmap を確認した
[ ] 07_project_bootstrap を確認した
[ ] 09_seamless_ux_spec を確認した

### 変更範囲
[ ] 主目的は1つ
[ ] 高リスク疎通確認テーマは1つ
[ ] ついで作業を入れていない

### 技術詳細
[ ] ファイルごとの責務が明確
[ ] メモリ管理と persistence の境界が明確
[ ] イベント経路と状態遷移が説明できる

### Window / Focus
[ ] Window 責務が一箇所に集約されている
[ ] Focus 制御が UI と AppKit で競合していない
[ ] first mouse の扱いが明文化されている

### Persistence
[ ] 保存経路は一本化されている
[ ] frame と open 状態の責務が明確
[ ] relaunch 時の扱いが定義されている

### 実機確認
[ ] global shortcut を確認する
[ ] 1 click 操作を確認する
[ ] ゼロクリック入力を確認する
```

## 13. 変更履歴

- 2026-04-12: 初版作成
- 2026-04-12: 計画書に技術詳細確認を必須化
