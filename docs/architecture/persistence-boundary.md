# Persistence Boundary

最終更新: 2026-04-11

## 方針差分

旧 `migration/06_roadmap.md` では Phase 1 の local draft を process 生存中の一時保持としていた。
今回は要件として `app 再起動をまたがない local draft 保持` が明示されたため、新 repo では Phase 1 から SQLite を導入する。

## ただし広げない範囲

- 旧 `sticky.db` は読まない
- Trash はまだ持たない
- Session はまだ持たない
- autosave 戦略の高度化はまだやらない

## Phase 1 の保存責務

- memo 本文
- title 自動生成
- window frame
- pin 状態
- open / close 状態
- reopen 導線に必要な更新日時
