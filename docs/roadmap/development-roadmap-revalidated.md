# Development Roadmap Revalidated

最終更新: 2026-04-12

## SSOT 参照宣言

- `/Users/hori/Desktop/Sticky/migration/06_roadmap.md`
- `/Users/hori/Desktop/Sticky/migration/07_project_bootstrap.md`
- `/Users/hori/Desktop/Sticky/migration/09_seamless_ux_spec.md`
- `docs/roadmap/stickynative-ai-planning-guidelines.md`

## フェーズ一覧

### Phase 0: Planning Reset

目的:
- seamless UX を前提に SSOT と計画ルールを固定する

成果物:
- migration 文書更新
- StickyNative planning guideline
- フェーズ別ロードマップ
- Phase 1 詳細計画

Gate:
- 上位文書の矛盾が解消している
- 以後の実装が `SeamlessWindow` 前提で解釈できる

### Phase 1: Seamless Window Probe

目的:
- seamless UX の土台だけを疎通確認する

対象:
- `SeamlessWindow`
- `SeamlessHostingView`
- `acceptsFirstMouse`
- `canBecomeKey` / `canBecomeMain`
- `@FocusState`

Gate:
- 別アプリ前面から 1 click 操作できる
- shortcut 直後にゼロクリック入力できる

### Phase 2: Window Core MVP

目的:
- `1 memo = 1 window` の最小体験を成立させる

対象:
- menu bar app
- global shortcut
- memo window create / focus / pin / close / reopen
- drag / resize

Gate:
- Phase 1 の seamless 基盤の上で基本操作が自然に動く

### Phase 3: Draft Persistence

目的:
- close / relaunch をまたいで draft を失わない

対象:
- SQLite
- memo draft
- frame
- open state
- reopen metadata

Gate:
- app 再起動後も draft と reopen が成立する

### Phase 4: Management Surface

目的:
- 後から回収・整理する導線を作る

対象:
- Home
- Trash
- Settings
- 検索

Gate:
- 「書く」と「整理する」が分離する

### Phase 5: Session Reintroduction

目的:
- session を論理単位として再導入する

対象:
- session モデル
- session 表示
- session 間移動

Gate:
- session が複雑化ではなく整理価値として機能する

### Phase 6: Polish

目的:
- 日常利用レベルまで詰める

対象:
- visual polish
- performance
- edge case
- import 要否再評価

Gate:
- 常用しても違和感が大きく残らない

## 問題一覧

- `K-01`: seamless UX を含めた新 Phase 区分が明文化されていなかった
- `W-01`: seamless window の疎通確認と本実装が分離されていなかった
- `F-01`: 1 click 操作とゼロクリック入力の Gate が不足していた
- `P-01`: persistence 導入タイミングと window core の責務境界が曖昧だった

## 回帰 / 副作用チェック

- seamless UX を理由に Phase 1 へ persistence や管理 UI を持ち込まない
- probe 実装をそのまま量産しない
- AppKit 側で成立すべき責務を SwiftUI 側へ押し込まない

## 変更履歴

- 2026-04-12: seamless UX 前提でフェーズを再分割
