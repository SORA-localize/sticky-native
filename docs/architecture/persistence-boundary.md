# Persistence Boundary

最終更新: 2026-04-12

## 方針差分

旧 `migration/06_roadmap.md` では初期フェーズから local draft 永続化をまとめて扱っていた。
新 repo では window core と persistence の責務を分離し、`Phase 2` では in-memory reopen のみ、`Phase 3` で SQLite による永続化を導入する。

## ただし広げない範囲

- 旧 `sticky.db` は読まない
- Trash はまだ持たない
- Session はまだ持たない
- autosave 戦略の高度化はまだやらない

## Phase 2 の非永続責務

- close 後の同一 session 内 reopen
- reopen 用の最小メモリメタデータ
  - `memo id`
  - 最後の `window origin`
  - 最後の `pin` 状態

## Phase 3 の保存責務

- memo 本文
- window frame
- pin 状態
- open / close 状態
- reopen 導線に必要な更新日時

## Phase 3 でまだ持たないもの

- Trash 用の削除状態
- Session の論理グルーピング
- 検索最適化用の補助 index
