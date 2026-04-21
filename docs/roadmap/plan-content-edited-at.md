# 計画：コンテンツ編集日時の分離と日付表示改善

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-21 | 初版作成 |
| 2026-04-21 | レビュー指摘を反映：SSOT宣言・ID体系・フェーズ分割・Gate条件・実機確認項目を追加 |
| 2026-04-21 | レビュー指摘 2回目を反映：migration文書参照・色変更根拠・日付フォーマット技術詳細・Gate条件統合・Section 12チェックリストを追加 |
| 2026-04-21 | レビュー指摘 3回目を反映：ALTER TABLE 冪等性の保護方法（PRAGMA table_info ガード）を技術詳細に追記、Gate条件を更新 |

---

## SSOT 参照宣言

本計画は以下のドキュメントを参照して仕様判断している。

#### StickyNative ローカル文書

| 文書 | 参照箇所 | 判断への影響 |
|------|----------|-------------|
| `docs/architecture/domain-model.md` | SQLite スキーマ（Phase 5-1 時点） | `content_edited_at` 追加後のスキーマをここに反映が必要 |
| `docs/architecture/persistence-boundary.md` | Phase 3 の保存責務「reopen 導線に必要な更新日時」 | `updated_at` は引き続き内部更新日時として維持。コンテンツ編集日時は別列で分離する方針と整合 |
| `docs/product/ux-principles.md` | 「明快: pin / close / reopen の意味が曖昧でない」 | セッション割り当てが並べ替えに影響しないことは「明快」原則と整合する |
| `docs/architecture/technical-decision.md` | SQLite 採用・実装境界 | Persistence layer の変更であることを確認。列番号ハードコードは既存方針の延長 |

#### 上位 migration 文書（`/Users/hori/Desktop/Sticky/migration/`）

| 文書 | 整合確認結果 |
|------|------------|
| `02_ux_principles.md` | **影響なし。** 本変更はメモ一覧の並べ替えロジックと日付表示の修正であり、UX 原則（速い・自然・明快）と矛盾しない。「明快」原則の観点ではセッション割り当てが並べ替えに影響しないことは望ましい方向 |
| `09_seamless_ux_spec.md` | **影響なし。** seamless UX 仕様はウィンドウの生成・表示・遷移挙動を規定するものであり、管理画面のリスト並べ替えロジックとは関係しない |

---

## 問題一覧

| ID | 種別 | 内容 |
|----|------|------|
| P-01 | バグ | `updatedAt` がコンテンツ変更以外（セッション割り当て・ウィンドウ移動・開く操作等）でも更新されるため、並べ替え順が意図せず変わる |
| P-02 | バグ | `.today` / `.last7Days` スコープのフィルタも `updatedAt` ベースのため、P-01 と同様に誤判定が起きうる |
| U-01 | UX乖離 | 日付表示が `.relative` スタイル（"2 minutes ago"）であり、Apple メモの挙動（実際の日付・時刻）と異なる |

---

## 実装方針

`updatedAt` はそのまま維持し、新フィールド `content_edited_at` を追加する。
`upsertDraft`（テキスト・タイトル・色変更）のみが `content_edited_at` を更新する。
並べ替え・スコープフィルタ・日付表示をすべて `content_edited_at` ベースに切り替える。

### `updatedAt` が更新される操作と方針

| 操作 | 関数 | `content_edited_at` 更新 | 根拠 |
|------|------|--------------------------|------|
| テキスト・タイトル変更 | `upsertDraft` | ✅ 更新する | コンテンツの直接変更 |
| 色変更 | `upsertDraft` | ✅ 更新する | ※後述 |
| ウィンドウ移動/リサイズ | `updateWindowState` | ❌ 更新しない | ウィンドウ配置はコンテンツではない |
| セッション割り当て | `updateMemoSession` | ❌ 更新しない | 整理操作はコンテンツではない（今回の修正動機） |
| ピン操作（ウィンドウ） | `updatePinned` | ❌ 更新しない | 表示制御はコンテンツではない |
| ゴミ箱移動/復元 | `trash` / `restore` | ❌ 更新しない | ライフサイクル操作はコンテンツではない |
| メモを開く | `markOpen` | ❌ 更新しない | 状態変化はコンテンツではない |

**※ 色変更について：** Apple メモには per-note 色設定がないため直接比較はできない。本アプリでは色はメモの視覚的アイデンティティとして機能し、ユーザーが意図的に設定する表現の一部であるとみなす。また `upsertDraft` が色・テキスト・タイトルを一括で扱う設計上、色だけを除外すると「色だけ変えたのに日付が更新されない」という不一致が生じる。以上の理由からコンテンツ変更として扱う。

---

## 技術リスク評価

### 列番号ハードコード問題（高リスク）

`SQLiteStore.swift` の `memoRow()` は `sqlite3_column_*` の列番号をハードコードしている。`content_edited_at` を `selectColumns` に追加すると `session_id` の列番号が 14 → 15 にシフトする。

**判断：** 今回は既存方針の延長として列番号シフトで対応する。ただし、コメントで列番号マッピングを明示し、将来の列追加時のリスクを残さない。名前ベースへのリファクタは別タスクとする。

更新後の列番号マッピング：
```
0:id  1:draft  2:title  3:origin_x  4:origin_y  5:width  6:height  7:color_index
8:is_pinned  9:is_list_pinned  10:is_open  11:is_trashed
12:created_at  13:updated_at  14:content_edited_at  [15:session_id]
```

### migration の冪等性

既存の `migrate()` は起動のたびに呼ばれるが、以下の 2 段階で冪等性を保証している。

**ALTER TABLE の保護（既存方式）：**  
`migrate()` は最初に `fetchColumnNames()`（`PRAGMA table_info(memos)` ベース）で現在の列一覧を取得し、`!existing.contains("列名")` の場合のみ ALTER TABLE を実行する。この方式はすべての既存列で採用済みであり、`content_edited_at` も同じパターンに従う。

```swift
if !existing.contains("content_edited_at") {
    try exec("ALTER TABLE memos ADD COLUMN content_edited_at REAL NOT NULL DEFAULT 0;")
    try exec("UPDATE memos SET content_edited_at = updated_at WHERE content_edited_at = 0;")
}
```

ALTER TABLE と UPDATE をまとめて `if` ブロック内に置くことで、2 回目以降は両方ともスキップされる。UPDATE を外に出すと毎回実行されるため内側に置くこと。

**UPDATE の冪等性（参考）：**  
`WHERE content_edited_at = 0` の UPDATE は仮に毎回実行されても安全（`upsertDraft` は常に正の値を書き込むため補填後に 0 の行は生まれない）だが、上記の `if` ブロック内配置により実行は 1 回のみとなる。

---

## フェーズ分割

### Phase 1：SQLite スキーマ拡張と migration（高リスク、独立検証）

**変更対象：** `SQLiteStore.swift`、`PersistenceModels.swift`

1. `createSchema()` に `content_edited_at REAL NOT NULL DEFAULT 0` を追加
2. `migrate()` に以下を追加：
   ```sql
   ALTER TABLE memos ADD COLUMN content_edited_at REAL NOT NULL DEFAULT 0;
   UPDATE memos SET content_edited_at = updated_at WHERE content_edited_at = 0;
   ```
3. `selectColumns` に `content_edited_at` を追加（列 14、`session_id` は 15 へシフト）
4. `upsertDraft` のみ `content_edited_at = excluded.content_edited_at` を追加
5. `memoRow()` で `contentEditedAt` を読み取り・`session_id` 列番号を 14 → 15 に修正
6. `PersistedMemo` に `contentEditedAt: Date` フィールドを追加

**Gate 条件（Phase 2 進行前に確認）：**
- [ ] 既存 DB で起動し、クラッシュしないこと
- [ ] `content_edited_at` 列が追加されていること（`PRAGMA table_info(memos)` で確認）
- [ ] 既存メモの `content_edited_at` が `updated_at` と同値で補填されていること
- [ ] migration を 2 回実行しても値が変化しないこと（`!existing.contains` ガードにより ALTER TABLE と UPDATE の両方がスキップされること）
- [ ] `session_id` の読み取りが壊れていないこと（セッション割り当て済みメモが正しく表示される）
- [ ] `docs/architecture/domain-model.md` のスキーマ欄に `content_edited_at` を追記していること

---

### Phase 2：並べ替えとスコープフィルタの切り替え

**変更対象：** `HomeViewModel.swift`

1. `sortedMemos()` のソートキーを `updatedAt` → `contentEditedAt` へ変更
2. `dateSections()` のバケット分類を `contentEditedAt` ベースに変更
3. `scopeMemos` の `.today` / `.last7Days` フィルタを `contentEditedAt` ベースに変更

**Gate 条件（Phase 3 進行前に確認）：**
- [ ] 既存メモの並び順が変わらないこと（Phase 1 migration で `content_edited_at = updated_at` に補填されているため）
- [ ] セッション割り当て後に並べ替え順が変わらないこと
- [ ] ウィンドウを移動後に並べ替え順が変わらないこと
- [ ] テキストを編集した後は並べ替え順が正しく最新に変わること
- [ ] `.today` スコープに今日テキスト編集したメモのみ表示されること

---

### Phase 3：日付表示の切り替え（U-01 対応）

**変更対象：** `HomeView.swift`

`MemoRowView` の日付表示を `contentEditedAt` ベースの実際の日付フォーマットに変更：

| 条件 | 表示例 |
|------|--------|
| 今日 | `15:42` |
| 昨日〜7日前 | `月曜日` |
| 今年中（8日以上前） | `4月3日` |
| それ以前 | `2024/4/3` |

#### 日付フォーマット実装方針

分岐は `Calendar.current` のメソッドで行い、フォーマットは `Date.FormatStyle`（macOS 12+ の標準 API）を使用する。`DateFormatter` は使わない。

```swift
func formattedDate(_ date: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(date) {
        // 例: "15:42"（システムの12/24h設定に従う）
        return date.formatted(.dateTime.hour().minute())
    }
    let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: .now)).day ?? 0
    if days <= 7 {
        // 例: "月曜日"
        return date.formatted(.dateTime.weekday(.wide))
    }
    if cal.isDate(date, equalTo: .now, toGranularity: .year) {
        // 例: "4月3日"
        return date.formatted(.dateTime.month(.wide).day())
    }
    // 例: "2024/4/3"
    return date.formatted(.dateTime.year().month(.defaultDigits).day())
}
```

ロケールは `FormatStyle` がシステムロケールを自動適用するため、個別指定は不要。

**Gate 条件：**
- [ ] 全 4 パターンが実機で正しく表示されること（下記「実機確認項目」参照）
- [ ] システムが 12 時間表示設定のとき、今日の時刻が "3:42 PM" 形式で表示されること

---

## 変更しないこと

- `updatedAt` の更新ロジックはすべてそのまま維持（内部的な最終変更日時として保持）
- `fetchOpen` / `fetchAll` / `fetchTrashed` の SQL ソート順はそのまま（`HomeViewModel` で再ソートするため）
- `updateWindowState`、`updateMemoSession`、`updatePinned`、`trash`、`restore`、`markOpen` は `content_edited_at` に触れない

---

## 回帰・副作用チェック

| 観点 | 確認方法 |
|------|----------|
| migration 直後の既存データの並び順 | Phase 1 migration 後、既存メモが `updated_at` 順で並んでいること（補填値が正しいため） |
| `content_edited_at = 0` の行が残っていないか | migration 後、全メモの `content_edited_at > 0` であること |
| session_id 列番号シフト | セッション割り当て済みメモのセッション名が正しく表示されること |
| fetchOpen での並び順 | SQL ソートは `updated_at` のままだが、HomeView が `contentEditedAt` で再ソートするため影響なし |

---

## 実機確認項目

### Phase 1 完了後
- [ ] 既存 DB を持つ状態でアプリ起動してクラッシュしないこと
- [ ] セッション割り当て済みメモのセッション名が正しく表示されること
- [ ] 新規メモを作成し、`content_edited_at` が設定されること

### Phase 2 完了後
- [ ] テキスト編集 → リストの先頭に移動すること
- [ ] セッション割り当て → リストの順番が変わらないこと
- [ ] ウィンドウ移動 → リストの順番が変わらないこと
- [ ] メモを開く（`markOpen`）→ リストの順番が変わらないこと
- [ ] `.today` スコープ：今日テキスト編集したメモのみ表示、セッション割り当てのみのメモは表示されないこと
- [ ] `.last7Days` スコープ：同上

### Phase 3 完了後
- [ ] 今日編集したメモ → 時刻表示（例: `15:42`）
- [ ] 昨日〜7日前に編集したメモ → 曜日表示（例: `月曜日`）
- [ ] 今年・8日以上前に編集したメモ → 月日表示（例: `4月3日`）
- [ ] 昨年以前に編集したメモ → 年月日表示（例: `2024/4/3`）
- [ ] 日付フォーマットがロケールに応じて正しく表示されること

---

---

## Section 12 セルフチェックリスト

提出前確認：

- [ ] 問題に ID が振られており、実装方針と対応が追える
- [ ] 全フェーズに Gate 条件が定義されており、次フェーズ進行前に確認できる
- [ ] 高リスク変更（SQLite スキーマ）が独立フェーズとして分離されている
- [ ] 上位 migration 文書との整合確認結果が記録されている
- [ ] 変更しないことが明示されており、スコープ外の変更を防げる
- [ ] 回帰・副作用チェック観点が網羅されている
- [ ] 実機確認項目が各フェーズ単位で定義されている
- [ ] 技術的リスク（列番号ハードコード・migration 冪等性）が評価済みである
- [ ] フォーマット実装方針が具体的な API レベルで記載されており、実装者が迷わない
- [ ] domain-model.md 更新が Phase 1 の Gate 条件に組み込まれている
- [ ] 変更履歴が最新状態に更新されている
