# Rich Text Editor Probe Result

作成: 2026-04-23

---

## Phase 1: Persistence Probe

対象:

- `StickyNativeApp/SQLiteStore.swift`
- 既存 DB コピー: `/tmp/stickynative_richtext_probe/Library/Application Support/StickyNative/memos.db`
- 元 DB: `/Users/hori/Library/Application Support/StickyNative/memos.db`

目的:

- nullable `rich_text_data` column を追加しても、既存 DB open / fetch が壊れないことを確認する。
- Phase 1 では `PersistedMemo` / save API / editor model は変更しない。

実施内容:

1. 既存 `memos.db` を `/tmp` 配下へコピーした。
2. `SQLiteStore` を一時 HOME / `CFFIXED_USER_HOME` で初期化した。
3. `SQLiteStore.fetchAll()` を呼び、既存 reader が `rich_text_data` を無視したまま動くことを確認した。
4. `PRAGMA table_info(memos);` で column 追加結果を確認した。

結果:

- `SQLiteStore` 初期化: pass
- `fetchAll()`: pass
- `rich_text_data` column: added as nullable `BLOB`
- `selectColumns` / `memoRow`: unchanged in Phase 1
- 実 DB: direct migration は未実施。検証は DB コピーのみ。

確認後 schema excerpt:

```text
13|color_index|INTEGER|1|0|0
14|is_list_pinned|INTEGER|1|0|0
15|content_edited_at|REAL|1|0|0
16|rich_text_data|BLOB|0||0
```

次 Phase 判定:

- Phase 1 Gate は通過。
- Phase 2 では `PersistedMemo.richTextData` / SQLite row decode / save API wiring に進める。
